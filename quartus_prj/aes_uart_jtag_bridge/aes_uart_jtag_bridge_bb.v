
module aes_uart_jtag_bridge (
	clk_clk,
	uart_pins_beginbursttransfer,
	uart_pins_writeresponsevalid_n,
	reset_reset_n);	

	input		clk_clk;
	input		uart_pins_beginbursttransfer;
	output		uart_pins_writeresponsevalid_n;
	input		reset_reset_n;
endmodule
