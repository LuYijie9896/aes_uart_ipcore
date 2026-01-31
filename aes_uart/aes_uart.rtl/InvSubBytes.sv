// InvSubBytes
module InvSubBytes(
	input  logic [127:0] DataIn,
	output logic [127:0] DataOut
);
	InvSBox U00(.a(DataIn[127:120]),.d(DataOut[127:120]));
	InvSBox U10(.a(DataIn[119:112]),.d(DataOut[119:112]));
	InvSBox U20(.a(DataIn[111:104]),.d(DataOut[111:104]));
	InvSBox U30(.a(DataIn[103:096]),.d(DataOut[103:096]));
	
	InvSBox U01(.a(DataIn[095:088]),.d(DataOut[095:088]));
	InvSBox U11(.a(DataIn[087:080]),.d(DataOut[087:080]));
	InvSBox U21(.a(DataIn[079:072]),.d(DataOut[079:072]));
	InvSBox U31(.a(DataIn[071:064]),.d(DataOut[071:064]));
	
	InvSBox U02(.a(DataIn[063:056]),.d(DataOut[063:056]));
	InvSBox U12(.a(DataIn[055:048]),.d(DataOut[055:048]));
	InvSBox U22(.a(DataIn[047:040]),.d(DataOut[047:040]));
	InvSBox U32(.a(DataIn[039:032]),.d(DataOut[039:032]));
	
	InvSBox U03(.a(DataIn[031:024]),.d(DataOut[031:024]));
	InvSBox U13(.a(DataIn[023:016]),.d(DataOut[023:016]));
	InvSBox U23(.a(DataIn[015:008]),.d(DataOut[015:008]));
	InvSBox U33(.a(DataIn[007:000]),.d(DataOut[007:000]));

endmodule
