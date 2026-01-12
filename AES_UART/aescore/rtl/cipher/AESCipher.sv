`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
    AES Cipher
    Supports AES-128, AES-192, and AES-256
    The wheel key is updated only when necessary
*/
module AESCipher(
	input  wire logic         Clk,
    input  wire logic         Rst,
    input  wire logic         En,
    input  wire logic [1:0]   KeyLen,        // 00:128, 01:192, 10:256
	input  wire logic [255:0] Key,           // Top alignment
    input  wire logic         KeyUpdate,     // Update pulse
    input  wire logic         KeyLenUpdate,  // Update pulse

    taxi_axis_if.snk     s_axis,        // Plaintext 128-bit input
    taxi_axis_if.src     m_axis         // Ciphertext 8-bit output
);
	typedef enum logic [2:0] {
        IDLE    = 3'd0,
        KEY_GEN = 3'd1,
        S0      = 3'd2,
        S1      = 3'd3,
        S2      = 3'd4,
        OUTPUT  = 3'd5
    } state_t;
		
	logic [255:0] KeyReg, KeyNext;
    logic [1:0]   KeyLenReg, KeyLenNext;
    logic [3:0]   OutByteCnt, OutByteCntNext;
	logic [127:0] DataOutBufReg, DataOutBufNext;

	state_t       StateReg, StateNext;
	logic [3:0]   NReg, NNext;
	logic [127:0] DReg, DNext;	
	logic [127:0] DNext1, DNext2,DNext3;

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
        .KeyLen(KeyLenNext), // Use KeyLenNext to capture new length immediately
        .KeyIn(KeyNext),     // Use KeyNext to capture new key immediately
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
            DataOutBufReg  <= '0;
			KeyReg     <= '0;
            KeyLenReg  <= '0;
			NReg       <= '0;
			DReg       <= '0;
            OutByteCnt <= '0;
			StateReg   <= IDLE;
		end
		else begin
            DataOutBufReg  <= DataOutBufNext;
			KeyReg     <= KeyNext;
            KeyLenReg  <= KeyLenNext;
			NReg       <= NNext;
			DReg       <= DNext;
            OutByteCnt <= OutByteCntNext;
			StateReg   <= StateNext;
		end
	end
	
	always_comb begin
		StateNext   = StateReg;
        DataOutBufNext  = DataOutBufReg;
		KeyNext     = KeyReg;
        KeyLenNext  = KeyLenReg;
		NNext       = NReg;
		DNext       = DReg;
        OutByteCntNext = OutByteCnt;
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
                OutByteCntNext = 4'd0;
                s_axis.tready = En;
				if(s_axis.tvalid && En) begin
					DNext = s_axis.tdata;
					NNext = 4'b0000;                    
                    if(NeedExpansion) begin
                        KeyNext    = Key;
                        KeyLenNext = KeyLen;
                        ExpStart   = 1;
                        StateNext  = KEY_GEN;
                    end else begin
                        StateNext  = S0;
                    end
				end
			end
            // Wait for Key Expansion to complete
            KEY_GEN: begin           
                if(ExpDone) begin
                    StateNext = S0;
                end
            end
            // Round 0 (AddRoundKey)
			S0: begin                   
					DNext = DNext1; 
					NNext = 4'b0001;
					StateNext = S1;
			end
            // Rounds 1 to Nr-1
			S1: begin               
				DNext = DNext2; 
				NNext = NReg + 1;
                if (NReg == MaxRounds - 1) begin
                    StateNext = S2;
                end
			end
            // Round Nr (Final Round Calculation)
			S2: begin
                DataOutBufNext = DNext3; // Capture the DataOutBuf from RoundEnd
                StateNext  = OUTPUT;
			end
            // Output State (Serialize 128-bit DataOutBuf to 8-bit stream)
            OUTPUT: begin
                m_axis.tvalid = 1'b1;
                // Send 128-bit data as 16 bytes, MSB first (Big Endian / Network Order)
                m_axis.tdata  = DataOutBufReg[127 - (OutByteCnt * 8) -: 8];
                
                if (OutByteCnt == 4'd15)
                    m_axis.tlast = 1'b1;
                else
                    m_axis.tlast = 1'b0;
                
                if (m_axis.tready) begin
                    if (OutByteCnt == 4'd15) begin
                        StateNext   = IDLE;
                        OutByteCntNext = 4'd0;
                    end else begin
                        OutByteCntNext = OutByteCnt + 1;
                    end
                end
            end
            default: begin
                StateNext = IDLE;
            end
		endcase
	end
	
    // Round Instances
    RoundFirst   UR0(.DataIn(DReg),.Key(RoundKeys[0])   ,.DataOut(DNext1));		
    RoundGeneral UR1(.DataIn(DReg),.Key(CurrentRoundKey),.DataOut(DNext2));	
    RoundEnd     UR2(.DataIn(DReg),.Key(CurrentRoundKey),.DataOut(DNext3)); 

endmodule
