	aes_uart_jtag_bridge u0 (
		.clk_clk                        (<connected-to-clk_clk>),                        //       clk.clk
		.uart_pins_beginbursttransfer   (<connected-to-uart_pins_beginbursttransfer>),   // uart_pins.beginbursttransfer
		.uart_pins_writeresponsevalid_n (<connected-to-uart_pins_writeresponsevalid_n>), //          .writeresponsevalid_n
		.reset_reset_n                  (<connected-to-reset_reset_n>)                   //     reset.reset_n
	);

