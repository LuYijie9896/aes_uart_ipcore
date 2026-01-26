// byte multipled by a fixed numer 0x02
module xTimes(
    input  logic [7:0] x, 
    output logic [7:0] y
);
    assign y = {x[6:0],1'b0} ^ (8'h1b & {8{x[7]}});
endmodule

// Testbench for xTimes
module tb_xTimes();
	
	logic [7:0] x;
	logic [7:0] y;
	
	xTimes  U0(.x(x), .y(y));
	
	initial begin		
		x = 8'h00;
		for(int j=0;j<256;j=j+1) begin			
			#24		
			x = {$random} % 256;
		end
		$stop();
	end
endmodule

//
module PMul_4(
	input  logic [7:0] x,
	output logic [7:0] y
);
	logic [7:0] t;
	
	xTimes  U0(.x(x),.y(t));
	xTimes  U1(.x(t),.y(y));
endmodule
//
module PMul_8(
	input  logic [7:0] x,
	output logic [7:0] y
);
	logic [7:0] t;
	
	PMul_4  U0(.x(x),.y(t));
	xTimes  U1(.x(t),.y(y));
endmodule
//
module PMul_e(
	input  logic [7:0] x,
	output logic [7:0] y
);
	logic [7:0] t1,t2,t3;
	xTimes U0(.x(x),.y(t1));
	PMul_4 U1(.x(x),.y(t2));
	PMul_8 U2(.x(x),.y(t3));
	
	assign y = t1^t2^t3;

endmodule
//
module PMul_d(
	input  logic [7:0] x,
	output logic [7:0] y
);
	logic [7:0] t1,t2;
	
	PMul_4 U1(.x(x),.y(t1));
	PMul_8 U2(.x(x),.y(t2));
	
	assign y = t1^t2^x;

endmodule

//
module PMul_9(
	input  logic [7:0] x,
	output logic [7:0] y
);
	logic [7:0] t1;

	PMul_8 U2(.x(x),.y(t1));
	
	assign y = t1^x;

endmodule
//
module PMul_b(
	input  logic [7:0] x,
	output logic [7:0] y
);
	logic [7:0] t1,t2;
	
	xTimes U0(.x(x),.y(t1));
	PMul_8 U2(.x(x),.y(t2));
	
	assign y = t1^t2^x;

endmodule


//Testbench
module TbPMul4();
	
	logic [7:0] x;
	logic [7:0] e,e1,d,d1,y,y1,b,b1;
	
	initial begin
		x = 8'h00;
		#15
		x = 8'h01;
		#15
		x = 8'h10;
		for(int j=0;j<256;j=j+1) begin			
			#15
			x = {$random} % 256;
		end
		$stop();
	end
	
	PMul_e U0(.x(x),.y(e));
	PMul_d U1(.x(x),.y(d));
	PMul_9 U2(.x(x),.y(y));
	PMul_b U3(.x(x),.y(b));
	
	assign e1 = pmul_e(x);
	assign d1 = pmul_d(x);
	assign y1 = pmul_9(x);
	assign b1 = pmul_b(x);
	
	
	function automatic logic [7:0] pmul_e;
		input logic [7:0] b;
		logic [7:0] two,four,eight;
		begin
			two=xtime(b);four=xtime(two);eight=xtime(four);pmul_e=eight^four^two;
		end
	endfunction

	function automatic logic [7:0] pmul_9;
		input logic [7:0] b;
		logic [7:0] two,four,eight;
		begin
			two=xtime(b);four=xtime(two);eight=xtime(four);pmul_9=eight^b;
		end
	endfunction

	function automatic logic [7:0] pmul_d;
		input logic [7:0] b;
		logic [7:0] two,four,eight;
		begin
			two=xtime(b);four=xtime(two);eight=xtime(four);pmul_d=eight^four^b;
		end
	endfunction

	function automatic logic [7:0] pmul_b;
		input logic [7:0] b;
		logic [7:0] two,four,eight;
		begin
			two=xtime(b);four=xtime(two);eight=xtime(four);pmul_b=eight^two^b;
		end
	endfunction

	function automatic logic [7:0] xtime;
		input logic [7:0] b;
		xtime={b[6:0],1'b0}^(8'h1b&{8{b[7]}});
	endfunction
	
endmodule
