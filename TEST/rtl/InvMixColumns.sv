// Inverse MixColumns
module InvMixColumns(
	input  logic [127:0] DataIn,
	output logic [127:0] DataOut
);	
	InvMixColumn U0(.St(DataIn[127:096]),.MixCol(DataOut[127:096]));
	InvMixColumn U1(.St(DataIn[095:064]),.MixCol(DataOut[095:064]));
	InvMixColumn U2(.St(DataIn[063:032]),.MixCol(DataOut[063:032]));
	InvMixColumn U3(.St(DataIn[031:000]),.MixCol(DataOut[031:000]));
	
endmodule


// InvMixColumn
module InvMixColumn(
	input  logic [31:0] St,
	output logic [31:0] MixCol
);
    // Inverse MixColumns Matrix
    // 0e 0b 0d 09
    // 09 0e 0b 0d
    // 0d 09 0e 0b
    // 0b 0d 09 0e

    logic [7:0] s0, s1, s2, s3;
    assign s0 = St[31:24];
    assign s1 = St[23:16];
    assign s2 = St[15:8];
    assign s3 = St[7:0];

    // Helper functions for multiplication
    function automatic logic [7:0] xTimes(input logic [7:0] b);
        xTimes = {b[6:0],1'b0} ^ (8'h1b & {8{b[7]}});
    endfunction
    
    // x4 = xTimes(xTimes(b))
    function automatic logic [7:0] x4(input logic [7:0] b);
        x4 = xTimes(xTimes(b));
    endfunction
    
    // x8 = xTimes(xTimes(xTimes(b)))
    function automatic logic [7:0] x8(input logic [7:0] b);
        x8 = xTimes(xTimes(xTimes(b)));
    endfunction
    
    // Mul09 = x8 ^ 1
    function automatic logic [7:0] mul09(input logic [7:0] b);
        mul09 = x8(b) ^ b;
    endfunction

    // Mul0b = x8 ^ x2 ^ 1
    function automatic logic [7:0] mul0b(input logic [7:0] b);
        mul0b = x8(b) ^ xTimes(b) ^ b;
    endfunction
    
    // Mul0d = x8 ^ x4 ^ 1
    function automatic logic [7:0] mul0d(input logic [7:0] b);
        mul0d = x8(b) ^ x4(b) ^ b;
    endfunction
    
    // Mul0e = x8 ^ x4 ^ x2
    function automatic logic [7:0] mul0e(input logic [7:0] b);
        mul0e = x8(b) ^ x4(b) ^ xTimes(b);
    endfunction

	assign MixCol[31:24] = mul0e(s0) ^ mul0b(s1) ^ mul0d(s2) ^ mul09(s3);
	assign MixCol[23:16] = mul09(s0) ^ mul0e(s1) ^ mul0b(s2) ^ mul0d(s3);
	assign MixCol[15:08] = mul0d(s0) ^ mul09(s1) ^ mul0e(s2) ^ mul0b(s3);
	assign MixCol[07:00] = mul0b(s0) ^ mul0d(s1) ^ mul09(s2) ^ mul0e(s3);

endmodule
