`resetall
`timescale 1ns / 1ps
`default_nettype none

module uart #(
    parameter PRE_W = 16
)
(
    input  wire logic              Clk,
    input  wire logic              Rst,
    input  wire logic              En,
    input  wire logic              TEn,
    input  wire logic              REn,

    /*
     * AXI4-Stream input (sink)
     */
    taxi_axis_if.snk               s_axis,

    /*
     * AXI4-Stream output (source)
     */
    taxi_axis_if.src               m_axis,

    /*
     * UART interface
     */
    input  wire logic              rxd,
    output wire logic              txd,

    /*
     * Status
     */
    output wire logic              busy,
    output wire logic              tc,
    output wire logic              idle,
    output wire logic              overrun_error,
    output wire logic              frame_error,
    output wire logic              parity_error,

    /*
     * Configuration
     */
    input  wire logic [PRE_W-1:0]  prescale,
    input  wire logic [1:0]        data_bits,
    input  wire logic [1:0]        stop_bits,
    input  wire logic              parity_en,
    input  wire logic              parity_type

);

wire baud_clk;
wire tx_busy;
wire rx_busy;

assign busy = tx_busy | rx_busy;

uart_brg #(
    .PRE_W(PRE_W)
) uart_brg_inst (
    .Clk(Clk),
    .Rst(Rst),
    .En(En),
    .baud_clk(baud_clk),
    .Prescale(prescale)
);

uart_tx uart_tx_inst (
    .Clk(Clk),
    .Rst(Rst),
    .En(En & TEn),

    /*
     * Baud rate pulse in
     */
    .baud_clk(baud_clk),

    /*
     * AXI4-Stream input (sink)
     */
    .s_axis(s_axis),

    /*
     * UART configuration
     */
    .data_bits(data_bits),
    .stop_bits(stop_bits),
    .parity_en(parity_en),
    .parity_type(parity_type),

    /*
     * Status
     */
    .busy(tx_busy),
    .tc(tc),

    /*
     * UART interface
     */
    .txd(txd)
);

uart_rx uart_rx_inst (
    .Clk(Clk),
    .Rst(Rst),
    .En(En & REn),

    /*
     * Baud rate pulse in
     */
    .baud_clk(baud_clk),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis(m_axis),

    /*
     * UART configuration
     */
    .data_bits(data_bits),
    .stop_bits(stop_bits),
    .parity_en(parity_en),
    .parity_type(parity_type),

    /*
     * Status
     */
    .busy(rx_busy),
    .idle(idle),
    .overrun_error(overrun_error),
    .frame_error(frame_error),
    .parity_error(parity_error),

    /*
     * UART interface
     */
    .rxd(rxd)
);

endmodule

`resetall
