// SubBytes
module SubBytes(
	input  logic [127:0] DataIn,
	output logic [127:0] DataOut
);
	SBox U00(.a(DataIn[127:120]),.d(DataOut[127:120]));
	SBox U10(.a(DataIn[119:112]),.d(DataOut[119:112]));
	SBox U20(.a(DataIn[111:104]),.d(DataOut[111:104]));
	SBox U30(.a(DataIn[103:096]),.d(DataOut[103:096]));
	
	SBox U01(.a(DataIn[095:088]),.d(DataOut[095:088]));
	SBox U11(.a(DataIn[087:080]),.d(DataOut[087:080]));
	SBox U21(.a(DataIn[079:072]),.d(DataOut[079:072]));
	SBox U31(.a(DataIn[071:064]),.d(DataOut[071:064]));
	
	SBox U02(.a(DataIn[063:056]),.d(DataOut[063:056]));
	SBox U12(.a(DataIn[055:048]),.d(DataOut[055:048]));
	SBox U22(.a(DataIn[047:040]),.d(DataOut[047:040]));
	SBox U32(.a(DataIn[039:032]),.d(DataOut[039:032]));
	
	SBox U03(.a(DataIn[031:024]),.d(DataOut[031:024]));
	SBox U13(.a(DataIn[023:016]),.d(DataOut[023:016]));
	SBox U23(.a(DataIn[015:008]),.d(DataOut[015:008]));
	SBox U33(.a(DataIn[007:000]),.d(DataOut[007:000]));

endmodule
