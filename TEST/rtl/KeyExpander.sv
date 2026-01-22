// AES Key Expansion Module supporting 128, 192, 256 bit keys
// Generates words sequentially to be stored by the Cipher module.

module KeyExpander(
    input  logic        Clk,
    input  logic        Rst,
    input  logic        En,
    input  logic        Start,
    input  logic [1:0]  KeyLen, // 00:128, 01:192, 10:256
    input  logic [255:0] KeyIn,
    output logic [31:0] WordOut,
    output logic [5:0]  WordIndex,
    output logic        Valid,
    output logic        Done
);
    logic [31:0] W [0:7]; // Sliding window. W[0] is oldest (i-Nk), W[Nk-1] is newest (i-1)
    logic [5:0] i;
    logic [5:0] Nk;
    logic [5:0] TotalWords;
    
    typedef enum logic {IDLE = 1'b0, RUN = 1'b1} state_t;
    state_t State;
    
    logic [31:0] raw_word;
    logic [31:0] temp;
    
    logic [31:0] PrevWord;
    assign PrevWord = W[Nk-1];
    logic [31:0] OldestWord;
    assign OldestWord = W[0];
    
    logic [31:0] RotOut, SubOut, RconOut;
    logic [31:0] SubOut2;
    
    // Helper modules are defined in AES128KeyExpansion.v or elsewhere in the project
    RotWord ROT(.W(PrevWord), .Ws(RotOut));
    SubWord SUB(.W(RotOut), .Wo(SubOut));
    SubWord SUB2(.W(PrevWord), .Wo(SubOut2));
    
    // Rcon index: i/Nk. My Rcon module takes index-1.
    logic [3:0] RconIdx;
    logic [31:0] RconVal;
    Rcon RC(.Index(RconIdx), .Rconj(RconVal));
    
    always_ff @(posedge Clk) begin
        if(Rst || !En) begin
            State <= IDLE;
            Valid <= 0;
            Done <= 0;
            i <= 0;
            RconIdx <= 0;
            WordOut <= 0;
            WordIndex <= 0;
            // Initialize W to avoid latches if necessary, though logic handles it
            for(int k=0; k<8; k=k+1) W[k] <= '0;
        end else begin
            case(State)
                IDLE: begin
                    Done <= 0;
                    Valid <= 0;
                    if(Start) begin
                        State <= RUN;
                        i <= 0;
                        RconIdx <= 0;
                        case(KeyLen)
                            0: begin Nk <= 4; TotalWords <= 44; end
                            1: begin Nk <= 6; TotalWords <= 52; end
                            2: begin Nk <= 8; TotalWords <= 60; end
                            default: begin Nk <= 4; TotalWords <= 44; end
                        endcase
                    end
                end
                RUN: begin
                    if(i < TotalWords) begin
                        Valid <= 1;
                        WordIndex <= i;
                        
                        // Calculate Next Word
                        if(i < Nk) begin
                            // Load initial key
                            case(i)
                                0: raw_word = KeyIn[255:224];
                                1: raw_word = KeyIn[223:192];
                                2: raw_word = KeyIn[191:160];
                                3: raw_word = KeyIn[159:128];
                                4: raw_word = KeyIn[127:96];
                                5: raw_word = KeyIn[95:64];
                                6: raw_word = KeyIn[63:32];
                                7: raw_word = KeyIn[31:0];
                                default: raw_word = 0;
                            endcase
                            WordOut <= raw_word;
                            
                            // Fill buffer directly, NO SHIFT needed yet
                            W[i] <= raw_word; 
                        end else begin
                            // Generate
                            temp = PrevWord; // W[Nk-1]
                            
                            if (i % Nk == 0) begin
                                temp = SubOut ^ RconVal;
                                // Increment RconIdx for next time
                                RconIdx <= RconIdx + 1;
                            end else if (Nk == 8 && i % Nk == 4) begin
                                temp = SubOut2;
                            end
                            
                            WordOut <= OldestWord ^ temp;
                            
                            // Shift Window
                            for(int k=0; k<7; k=k+1) begin
                                if(k < Nk-1)
                                    W[k] <= W[k+1];
                            end
                            W[Nk-1] <= OldestWord ^ temp;
                        end
                        
                        i <= i + 1;
                    end else begin
                        Valid <= 0;
                        Done <= 1;
                        State <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule


// SubWord
module SubWord(
	input  logic [31:0] W,
	output logic [31:0] Wo
);		
	
	SBox UU0(.a(W[31:24]),.d(Wo[31:24]));
	SBox UU1(.a(W[23:16]),.d(Wo[23:16]));
	SBox UU2(.a(W[15:8]), .d(Wo[15:8]));
	SBox UU3(.a(W[7:0]),  .d(Wo[7:0]));

endmodule	


// Cyclic shift	
module RotWord(
	input  logic [31:0] W,
	output logic [31:0] Ws	
	);
	
	assign Ws[31:24] = W[23:16];
	assign Ws[23:16] = W[15:8];
	assign Ws[15:8]  = W[7:0];
	assign Ws[7:0]   = W[31:24];

endmodule


// Rconj
module Rcon(
	input  logic [3:0]  Index,
	output logic [31:0] Rconj
);
	always_comb begin
		case(Index)
			4'h0: Rconj = 32'h01_00_00_00;			
			4'h1: Rconj = 32'h02_00_00_00;
			4'h2: Rconj = 32'h04_00_00_00;
			4'h3: Rconj = 32'h08_00_00_00;
			4'h4: Rconj = 32'h10_00_00_00;
			4'h5: Rconj = 32'h20_00_00_00;
			4'h6: Rconj = 32'h40_00_00_00;
			4'h7: Rconj = 32'h80_00_00_00;
			4'h8: Rconj = 32'h1b_00_00_00;
			4'h9: Rconj = 32'h36_00_00_00;
			default: Rconj = 32'h00_00_00_00;		
		endcase
	end
endmodule
