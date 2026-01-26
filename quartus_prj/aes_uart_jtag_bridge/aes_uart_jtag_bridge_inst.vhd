	component aes_uart_jtag_bridge is
		port (
			clk_clk                        : in  std_logic := 'X'; -- clk
			uart_pins_beginbursttransfer   : in  std_logic := 'X'; -- beginbursttransfer
			uart_pins_writeresponsevalid_n : out std_logic;        -- writeresponsevalid_n
			reset_reset_n                  : in  std_logic := 'X'  -- reset_n
		);
	end component aes_uart_jtag_bridge;

	u0 : component aes_uart_jtag_bridge
		port map (
			clk_clk                        => CONNECTED_TO_clk_clk,                        --       clk.clk
			uart_pins_beginbursttransfer   => CONNECTED_TO_uart_pins_beginbursttransfer,   -- uart_pins.beginbursttransfer
			uart_pins_writeresponsevalid_n => CONNECTED_TO_uart_pins_writeresponsevalid_n, --          .writeresponsevalid_n
			reset_reset_n                  => CONNECTED_TO_reset_reset_n                   --     reset.reset_n
		);

