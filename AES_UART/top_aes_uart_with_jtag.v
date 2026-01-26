module top_aes_uart_with_jtag (
    input  wire        clk_50m,     // 板载 50MHz 时钟
    input  wire        rst_n,       // 板载复位按键 (低电平有效)
    input  wire        rx,          // UART 接收引脚
    output wire        tx           // UART 发送引脚
);

    aes_uart_jtag_bridge u0 (
        .clk_clk       (clk_50m),       // clk.clk
        .reset_reset_n (rst_n),         // reset.reset_n
        .uart_pins_rx  (rx),            // uart_pins.rx
        .uart_pins_tx  (tx)             //          .tx
    );

endmodule