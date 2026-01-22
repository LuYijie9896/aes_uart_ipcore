module AddRoundKey(
	input  logic [127:0] DataIn,
	input  logic [127:0] Key,
	output logic [127:0] DataOut	
);
	assign DataOut = DataIn ^ Key;

endmodule
