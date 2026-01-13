`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
    AES InvCipher
    Supports AES-128, AES-192, and AES-256
    The wheel key is updated only when necessary
*/
module InvAESCipher(
	input  wire logic         Clk,
    input  wire logic         Rst,
    input  wire logic         En,
    input  wire logic         Idle,          // UART idle signal for zero-padding
    input  wire logic [1:0]   KeyLen,        // 00:128, 01:192, 10:256
	input  wire logic [255:0] Key,           // Top alignment
    input  wire logic         KeyUpdate,     // Update pulse
    input  wire logic         KeyLenUpdate,  // Update pulse

    taxi_axis_if.snk     s_axis,        // Ciphertext 8-bit input
    taxi_axis_if.src     m_axis         // Plaintext 128-bit output
);
	typedef enum logic [2:0] {
        IDLE    = 3'd0,
        INPUT   = 3'd1, 
        KEY_GEN = 3'd2,
        S0      = 3'd3, 
        S1      = 3'd4, 
        S2      = 3'd5, 
        OUTPUT  = 3'd6  
    } state_t;
		
	logic [127:0] DataInBufReg, DataInBufNext;
    logic [3:0]   InByteCnt, InByteCntNext;
	logic [255:0] KeyReg, KeyNext;
    logic [1:0]   KeyLenReg, KeyLenNext;

    state_t       StateReg, StateNext;
	logic [3:0]   NReg, NNext;    
	logic [127:0] DReg, DNext;
    logic [127:0] DNext1, DNext2, DNext3;
    
    logic [31:0]  ExpWord;
    logic [5:0]   ExpIndex;
    logic         ExpValid;
    logic         ExpDone;
    logic         ExpStart;
    logic         NeedExpansion;
    
    // Round Keys Storage (Max 15 rounds for AES-256)
    logic [127:0] RoundKeys [0:14];   
    logic [127:0] CurrentRoundKey;
    assign CurrentRoundKey = RoundKeys[NReg];

    // Key Expander Instance
    KeyExpander U_KeyExp(
        .Clk(Clk),
        .Rst(Rst),
        .En(En),
        .Start(ExpStart),
        .KeyLen(KeyLenNext), 
        .KeyIn(KeyNext),     
        .WordOut(ExpWord),
        .WordIndex(ExpIndex),
        .Valid(ExpValid),
        .Done(ExpDone)
    );
    
    // Store Round Keys
    always_ff @(posedge Clk) begin
        if(Rst || !En) begin
            for(int k=0; k<15; k=k+1) RoundKeys[k] <= '0;
        end else if(ExpValid) begin
            case(ExpIndex[1:0])
                2'b00: RoundKeys[ExpIndex[5:2]][127:96] <= ExpWord;
                2'b01: RoundKeys[ExpIndex[5:2]][95:64]  <= ExpWord;
                2'b10: RoundKeys[ExpIndex[5:2]][63:32]  <= ExpWord;
                2'b11: RoundKeys[ExpIndex[5:2]][31:0]   <= ExpWord;
            endcase
        end
    end
    
    // Determine Max Rounds
    logic [3:0] MaxRounds;
    always_comb begin
        case(KeyLenReg)
            2'b00: MaxRounds = 10;
            2'b01: MaxRounds = 12;
            2'b10: MaxRounds = 14;
            default: MaxRounds = 10;
        endcase
    end
    
    // NeedExpansion Logic
    always_ff @(posedge Clk) begin
        if(Rst || !En) begin
            NeedExpansion <= 1'b1;
        end else if(KeyUpdate || KeyLenUpdate) begin
            NeedExpansion <= 1'b1;
        end else if(ExpDone) begin
            NeedExpansion <= 1'b0;
        end
    end
    	
	always_ff @(posedge Clk) begin
		if(Rst || !En) begin
			DataInBufReg  <= '0;
            InByteCnt  <= '0;
            DReg       <= '0;
			KeyReg     <= '0;
            KeyLenReg  <= '0;
			NReg       <= '0;
			StateReg   <= IDLE;
		end
		else begin
			DataInBufReg  <= DataInBufNext;
            InByteCnt  <= InByteCntNext;
            DReg       <= DNext;
			KeyReg     <= KeyNext;
            KeyLenReg  <= KeyLenNext;
			NReg       <= NNext;
			StateReg   <= StateNext;
		end
	end
	
	always_comb begin
		StateNext   = StateReg;
		DataInBufNext = DataInBufReg;
        InByteCntNext = InByteCnt;
        DNext       = DReg;
		KeyNext     = KeyReg;
        KeyLenNext  = KeyLenReg;
		NNext       = NReg;
        ExpStart    = 1'b0;
        
        // Axis defaults
        s_axis.tready = 1'b0;
        m_axis.tvalid = 1'b0;
        m_axis.tdata  = '0;
        m_axis.tkeep  = '1;
        m_axis.tstrb  = '1;
        m_axis.tlast  = 1'b0;
        m_axis.tid    = '0;
        m_axis.tdest  = '0;
        m_axis.tuser  = '0;
        
		case(StateReg)
            IDLE: begin
                InByteCntNext = 4'd0;
                DataInBufNext = '0;  // Clear buffer for new transaction
                s_axis.tready = En;
                if (s_axis.tvalid && En) begin
                    DataInBufNext[127 - (InByteCnt * 8) -: 8] = s_axis.tdata;
                    InByteCntNext = 4'd1;                    
                    if (NeedExpansion) begin
                        KeyNext    = Key;
                        KeyLenNext = KeyLen;
                        ExpStart   = 1;
                        StateNext  = KEY_GEN;
                    end else begin
                        StateNext  = INPUT;
                    end
                end
			end
            // Collect the complete plaintext block
            INPUT: begin
                s_axis.tready = 1'b1;
                
                // Check for IDLE signal to trigger zero-padding
                if (Idle && InByteCnt > 4'd0 && InByteCnt < 4'd16) begin
                    // Pad remaining bytes with zeros using case statement for synthesis
                    DNext = DataInBufNext;  // Start with current data
                    
                    // Use case to explicitly set padding for each possible byte count
                    case (InByteCnt)
                        4'd1:  DNext[119:0]   = 120'h0;  // Pad bytes 1-15
                        4'd2:  DNext[111:0]   = 112'h0;  // Pad bytes 2-15
                        4'd3:  DNext[103:0]   = 104'h0;  // Pad bytes 3-15
                        4'd4:  DNext[95:0]    = 96'h0;   // Pad bytes 4-15
                        4'd5:  DNext[87:0]    = 88'h0;   // Pad bytes 5-15
                        4'd6:  DNext[79:0]    = 80'h0;   // Pad bytes 6-15
                        4'd7:  DNext[71:0]    = 72'h0;   // Pad bytes 7-15
                        4'd8:  DNext[63:0]    = 64'h0;   // Pad bytes 8-15
                        4'd9:  DNext[55:0]    = 56'h0;   // Pad bytes 9-15
                        4'd10: DNext[47:0]    = 48'h0;   // Pad bytes 10-15
                        4'd11: DNext[39:0]    = 40'h0;   // Pad bytes 11-15
                        4'd12: DNext[31:0]    = 32'h0;   // Pad bytes 12-15
                        4'd13: DNext[23:0]    = 24'h0;   // Pad bytes 13-15
                        4'd14: DNext[15:0]    = 16'h0;   // Pad bytes 14-15
                        4'd15: DNext[7:0]     = 8'h0;    // Pad byte 15
                        default: DNext = DataInBufNext;  // Shouldn't happen
                    endcase
                    
                    StateNext = S0;  // Start decryption with padded data
                end
                // Normal byte reception
                else if (s_axis.tvalid) begin
                    DataInBufNext[127 - (InByteCnt * 8) -: 8] = s_axis.tdata;
                    // Collection completed
                    if (InByteCnt == 4'd15) begin
                        DNext = DataInBufNext; 
                        StateNext = S0;
                    end else begin
                        InByteCntNext = InByteCnt + 1;
                    end
                end
            end            
            // Wait for Key Expansion to complete
            KEY_GEN: begin           
                if(ExpDone) begin
                    StateNext = INPUT;
                end
            end           
            // Round 0 (Last Round Key)
			S0: begin
					DNext = DNext1; 
					NNext = MaxRounds - 1; 
					StateNext = S1;
			end            
            // Rounds 1 to Nr-1
			S1: begin               
				DNext = DNext2; 
                if (NReg == 1) begin
                    StateNext = S2;
                end else begin
				    NNext = NReg - 1;
                end
			end    
            // Round Nr (Key 0)
			S2: begin
                DNext = DNext3;
                StateNext  = OUTPUT;
			end            
            // Output of ciphertext block
            OUTPUT: begin
                m_axis.tvalid = 1'b1;
                m_axis.tdata  = DReg;
                m_axis.tlast  = 1'b1;                
                if (m_axis.tready) begin
                    StateNext = IDLE;
                end
            end
            default: begin
                StateNext = IDLE;
            end
		endcase
	end
	
    // Round Instances
    InvRoundFirst   UR0(.DataIn(DReg), .Key(RoundKeys[MaxRounds]), .DataOut(DNext1));		
    InvRoundGeneral UR1(.DataIn(DReg), .Key(CurrentRoundKey),      .DataOut(DNext2));	
    InvRoundEnd     UR2(.DataIn(DReg), .Key(RoundKeys[0]),         .DataOut(DNext3)); 

endmodule
