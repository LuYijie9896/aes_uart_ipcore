// InvAESRound

// InvRoundFirst: AddRoundKey -> InvShiftRows -> InvSubBytes
module InvRoundFirst(
	input  logic [127:0] DataIn,
	input  logic [127:0] Key,
	output logic [127:0] DataOut
);
    logic [127:0] S1, S2;

	// AddRoundKey
	AddRoundKey U0(.DataIn(DataIn),.Key(Key),.DataOut(S1));
    // InvShiftRows
    InvShiftRows U1(.DataIn(S1), .DataOut(S2));
    // InvSubBytes (Last step of reverse RoundEnd)
    InvSubBytes U2(.DataIn(S2), .DataOut(DataOut));
    
endmodule


// InvRoundGeneral: AddRoundKey -> InvMixColumns -> InvShiftRows -> InvSubBytes
module InvRoundGeneral(
	input  logic [127:0] DataIn,
	input  logic [127:0] Key,
	output logic [127:0] DataOut
);

	logic [127:0] S1, S2, S3;
	
	// AddRoundKey	
	AddRoundKey U0(.DataIn(DataIn),.Key(Key),.DataOut(S1));
    // InvMixColumns
    InvMixColumns U1(.DataIn(S1), .DataOut(S2));
	// InvShiftRows
	InvShiftRows U2(.DataIn(S2),.DataOut(S3));
    // InvSubBytes
    InvSubBytes U3(.DataIn(S3), .DataOut(DataOut));
	
endmodule


// InvRoundEnd: AddRoundKey 
module InvRoundEnd(
	input  logic [127:0] DataIn,
	input  logic [127:0] Key,
	output logic [127:0] DataOut
);
	// AddRoundKey	
	AddRoundKey U0(.DataIn(DataIn),.Key(Key),.DataOut(DataOut));	
endmodule
