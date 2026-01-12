// Cipher: Round0(AddRoundKey)
module RoundFirst(
	input  logic [127:0] DataIn,
	input  logic [127:0] Key,
	output logic [127:0] DataOut
);
	// AddRoundKey
	AddRoundKey U0(.DataIn(DataIn),.Key(Key),.DataOut(DataOut));
endmodule


// Cipher: GeneralRound(SubBytes->ShiftRows->MixColumns->AddRoundKey)
module RoundGeneral(
	input  logic [127:0] DataIn,
	input  logic [127:0] Key,
	output logic [127:0] DataOut
);

	logic [127:0] S1, S2, S3;
	
	// SubBytes
	SubBytes U0(.DataIn(DataIn),.DataOut(S1));
	// ShiftRows
	ShiftRows U1(.DataIn(S1),.DataOut(S2));
	// MixColumns
	MixColumns U2(.DataIn(S2),.DataOut(S3));
	// AddRoundKey	
	AddRoundKey U3(.DataIn(S3),.Key(Key),.DataOut(DataOut));
	
endmodule


// Cipher: The last Round
module RoundEnd(
	input  logic [127:0] DataIn,
	input  logic [127:0] Key,
	output logic [127:0] DataOut
);
	logic [127:0] S1, S2;
	 
	// SubBytes
	SubBytes U0(.DataIn(DataIn),.DataOut(S1));
	// ShiftRows
	ShiftRows U1(.DataIn(S1),.DataOut(S2));	
	// AddRoundKey	
	AddRoundKey U3(.DataIn(S2),.Key(Key),.DataOut(DataOut));	

endmodule


// Testbench for RoundFirst 
module TbRound();
	logic [127:0] DataIn;
	logic [127:0] Key;
	logic [127:0] DataOut;
		
	initial begin
		Key    = 128'h2b_7e_15_16_28_ae_d2_a6_ab_f7_15_88_09_cf_4f_3c; //Appendix B
		DataIn = 128'h32_43_f6_a8_88_5a_30_8d_31_31_98_a2_e0_37_07_34;
		#50
		$stop();
	end

	RoundFirst U0(.DataIn(DataIn),.Key(Key),.DataOut(DataOut));		

endmodule
