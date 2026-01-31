`resetall
`timescale 1ns / 1ps

module uart_brg #(
    parameter PRE_W = 16
)
(
    input  wire logic              Clk,
    input  wire logic              Rst,
    input  wire logic              En,

    /*
     * Baud rate pulse out
     */
    output wire logic              baud_clk,

    /*
     * Configuration
     */
    input  wire logic [PRE_W-1:0]  Prescale
);

localparam FRAC_W = 4;
localparam INT_W = PRE_W - FRAC_W;

logic [INT_W-1:0] prescale_int_reg = 0;
logic [FRAC_W-1:0] prescale_frac_reg = 0;
logic frac_ovf_reg = 1'b0;
logic baud_clk_reg = 1'b0;

assign baud_clk = baud_clk_reg;

always_ff @(posedge Clk) begin
    frac_ovf_reg <= 1'b0;
    baud_clk_reg <= 1'b0;

    if (frac_ovf_reg) begin
        frac_ovf_reg <= 1'b0;
    end else if (En && prescale_int_reg != 0) begin
        prescale_int_reg <= prescale_int_reg - 1;
    end else if (En) begin
        prescale_int_reg <= Prescale[FRAC_W +: INT_W] - 1;
        {frac_ovf_reg, prescale_frac_reg} <= prescale_frac_reg + Prescale[FRAC_W-1:0];
        baud_clk_reg <= 1'b1;
    end

    if (Rst || !En) begin
        prescale_int_reg <= 0;
        prescale_frac_reg <= 0;
        baud_clk_reg <= 0;
    end
end

endmodule

`resetall
