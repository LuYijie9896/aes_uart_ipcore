// ShiftRows
module ShiftRows(
	input  logic [127:0] DataIn,
	output logic [127:0] DataOut
);
	// The first row of the state
	assign DataOut[127:120] = DataIn[127:120];
	assign DataOut[095:088] = DataIn[095:088];
	assign DataOut[063:056] = DataIn[063:056];
	assign DataOut[031:024] = DataIn[031:024];
	// The second row of the state
	assign DataOut[119:112] = DataIn[087:080];
	assign DataOut[087:080] = DataIn[055:048];
	assign DataOut[055:048] = DataIn[023:016];
	assign DataOut[023:016] = DataIn[119:112];
	// The third row of the state
	assign DataOut[111:104] = DataIn[047:040];
	assign DataOut[079:072] = DataIn[015:008];
	assign DataOut[047:040] = DataIn[111:104];
	assign DataOut[015:008] = DataIn[079:072];
	// The fourth row of the state
	assign DataOut[103:096] = DataIn[007:000];
	assign DataOut[071:064] = DataIn[103:096];
	assign DataOut[039:032] = DataIn[071:064];
	assign DataOut[007:000] = DataIn[039:032];

endmodule

// Testbench for ShiftRows
module TbShiftRows();

	logic [127:0] DataIn;
	logic [127:0] DataOut;
		
	initial begin
		DataIn = 128'h0;
		for(int j=0;j<256;j=j+1)begin
			#25
			DataIn = {{$random},{$random},{$random},{$random}};
		end
		$stop();
	end
	//ShiftRows
	ShiftRows U0(.DataIn(DataIn), .DataOut(DataOut));

endmodule
