// MixColunms
module MixColumns(
	input  logic [127:0] DataIn,
	output logic [127:0] DataOut
	
);	
	MixColumn U0(.St(DataIn[127:096]),.MixCol(DataOut[127:096]));
	MixColumn U1(.St(DataIn[095:064]),.MixCol(DataOut[095:064]));
	MixColumn U2(.St(DataIn[063:032]),.MixCol(DataOut[063:032]));
	MixColumn U3(.St(DataIn[031:000]),.MixCol(DataOut[031:000]));
	
endmodule


// MixColumn
module MixColumn(
	input  logic [31:0] St,
	output logic [31:0] MixCol
);
	assign MixCol[31:24] = XTimes(St[31:24])^XTimes(St[23:16])^St[23:16]^St[15:8]^St[7:0];    // [02 03 01 01][S0C]
	assign MixCol[23:16] = St[31:24]^XTimes(St[23:16])^XTimes(St[15:8])^St[15:8]^St[7:0];     // |01 02 03 01||S1C| 
	assign MixCol[15:08] = St[31:24]^St[23:16]^XTimes(St[15:08])^XTimes(St[7:0])^St[7:0];     // |01 01 02 03||S2C|
	assign MixCol[07:00] = XTimes(St[31:24])^St[31:24]^St[23:16]^St[15:08]^XTimes(St[7:0]);   // [03 01 01 02][S3C]

	// byte b multiplied by {02}
	function automatic logic [7:0] XTimes(
		input logic [7:0] b
	);
	
		XTimes = {b[6:0],1'b0} ^ (8'h1b & {8{b[7]}});
		
	endfunction
endmodule


// Testbench for MixColumn
module TbMixColumn();
	
	logic [31:0] St;
	logic [31:0] MixCol;

	initial begin
		St = 32'hC97A63B0;  // 0xD428BE22  AES_Core128.pdf
		#25
		St = 32'hE5F29CA7;  // 0xE702C60F
		#25
		St = 32'hFD782682;  // 0xCDE5545D 
		#25
		St = 32'h2B6E67E5;  // 0x66BBBFA5
		#25
		for(int j=0;j<256;j=j+1) begin
			#25
			St = {$random};			
		end
		#25
		$stop();	
	end

	MixColumn U1(.St(St),.MixCol(MixCol));

endmodule
