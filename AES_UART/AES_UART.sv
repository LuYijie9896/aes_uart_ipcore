module AES_UART #(
    parameter DATA_W = 32,
    parameter ADDR_W = 32
) (
    input  logic Clk,
    input  logic Rst,

    taxi_axil_if.wr_slv  wr_axil, 
    taxi_axil_if.rd_slv  rd_axil,
    
    input  logic Rx,
    output logic Tx
);

import axilregs_pkg::*;

cr1_reg_t cr1;
cr2_reg_t cr2;
brr_reg_t brr;
isr_reg_t isr;

logic [31:0] ekr[7:0];
logic [31:0] dkr[7:0];

logic ekey_update;
logic dkey_update;
logic ekey_len_update;
logic dkey_len_update;

logic [7:0]  fifo_tx_depth;
logic [7:0]  fifo_rx_depth;
logic        fifo_tx_overflow;
logic        fifo_rx_overflow;

logic        txd;
logic        rxd;

taxi_axis_if #(.DATA_W(8)) fifo_tx_axis_if();
taxi_axis_if #(.DATA_W(8)) fifo_rx_axis_if();

taxi_axis_if #(.DATA_W(8)) fifo_tx_data_sel_axis_if();
taxi_axis_if #(.DATA_W(8)) fifo_rx_data_sel_axis_if();

taxi_axis_if #(.DATA_W(8)) cipher_out_axis_if();
taxi_axis_if #(.DATA_W(8)) invcipher_in_axis_if();

taxi_axis_if #(.DATA_W(8)) tdr_axis_if();
taxi_axis_if #(.DATA_W(8)) rdr_axis_if();

taxi_axis_if #(.DATA_W(128)) epr_axis_if();
taxi_axis_if #(.DATA_W(128)) dpr_axis_if();

// ISR Mapping
assign isr.reserved = '0;
assign isr.txfe     = (fifo_tx_depth == 0);
assign isr.rxff     = (fifo_rx_depth == 16);
assign isr.txft     = (fifo_tx_depth <= {4'd0, cr2.txftcfg});
assign isr.rxft     = (fifo_rx_depth >= {4'd0, cr2.rxftcfg});
// ere, drne, txe, rxne are internal to axil_regs so these inputs are ignored by it for those fields
assign isr.ere      = 1'b0;
assign isr.drne     = 1'b0;
assign isr.txe      = 1'b0;
assign isr.rxne     = 1'b0;

// Looping mode
assign rxd = cr1.wm ? txd  : Rx; 
assign Tx  = cr1.wm ? 1'b1 : txd;  

axil_regs axil_regs_inst (
    .clk            (Clk),
    .rst            (Rst),

    .s_axil_wr      (wr_axil),      
    .s_axil_rd      (rd_axil),      

    .o_cr1          (cr1),          
    .o_cr2          (cr2),          
    .o_brr          (brr),          
    .i_isr          (isr),          

    .o_ekr          (ekr),     
    .o_dkr          (dkr),     

    .s_axis_rdr     (rdr_axis_if.snk),     
    .m_axis_tdr     (tdr_axis_if.src),     
    .m_axis_epr     (epr_axis_if.src),     
    .s_axis_dpr     (dpr_axis_if.snk),

    .o_ekey_update      (ekey_update),
    .o_dkey_update      (dkey_update),
    .o_ekey_len_update  (ekey_len_update),
    .o_dkey_len_update  (dkey_len_update)
);

AESCipher aes_cipher_inst(
	.Clk            (Clk),
    .Rst            (Rst),
    .En             (cr1.aue & cr1.ee),
    .KeyLen         (cr1.el),        
	.Key            ({ekr[7], ekr[6], ekr[5], ekr[4], ekr[3], ekr[2], ekr[1], ekr[0]}),           
    .KeyUpdate      (ekey_update),     
    .KeyLenUpdate   (ekey_len_update),  

    .s_axis         (epr_axis_if.snk),        
    .m_axis         (cipher_out_axis_if.src)
);

InvAESCipher inv_aes_cipher_inst(
	.Clk            (Clk),
    .Rst            (Rst),
    .En             (cr1.aue & cr1.de),
    .KeyLen         (cr1.dl),        
	.Key            ({dkr[7], dkr[6], dkr[5], dkr[4], dkr[3], dkr[2], dkr[1], dkr[0]}),           
    .KeyUpdate      (dkey_update),     
    .KeyLenUpdate   (dkey_len_update),  

    .s_axis         (invcipher_in_axis_if.snk),        
    .m_axis         (dpr_axis_if.src)
);

axis_mux_2to1 axis_mux_tx_inst(
    .sel        (cr1.ee),
    .s0_axis    (tdr_axis_if.snk),
    .s1_axis    (cipher_out_axis_if.snk),
    .m_axis     (fifo_tx_data_sel_axis_if.src)
);

axis_demux_1to2 axis_demux_rx_inst(
    .sel        (cr1.de),
    .s_axis     (fifo_rx_data_sel_axis_if.snk),
    .m0_axis    (rdr_axis_if.src),
    .m1_axis    (invcipher_in_axis_if.src)
);

fifo #(.DEPTH(16)) fifo_tx_inst(
    .Clk            (Clk),
    .Rst            (Rst),
    .s_axis         (fifo_tx_data_sel_axis_if.snk),
    .m_axis         (fifo_tx_axis_if.src),
    .StatusDepth    (fifo_tx_depth[4:0]),
    .StatusOverflow (fifo_tx_overflow)
);
assign fifo_tx_depth[7:5] = '0;

fifo #(.DEPTH(16)) fifo_rx_inst(
    .Clk            (Clk),
    .Rst            (Rst),
    .s_axis         (fifo_rx_axis_if.snk),
    .m_axis         (fifo_rx_data_sel_axis_if.src),
    .StatusDepth    (fifo_rx_depth[4:0]),
    .StatusOverflow (fifo_rx_overflow)
);
assign fifo_rx_depth[7:5] = '0;

uart uart_inst(
    .Clk            (Clk),
    .Rst            (Rst),
    .En             (cr1.aue),
    .TEn            (cr1.te),
    .REn            (cr1.re),
    .s_axis         (fifo_tx_axis_if.snk),
    .m_axis         (fifo_rx_axis_if.src),
    .rxd            (rxd),
    .txd            (txd),
    .busy           (isr.busy),
    .tc             (isr.tc),
    .idle           (isr.idle),
    .overrun_error  (isr.ore),
    .frame_error    (isr.fe),
    .parity_error   (isr.pe),
    .prescale       ({brr.mantissa, brr.fraction}),
    .data_bits      (cr1.wl),
    .stop_bits      (cr1.stop),
    .parity_en      (cr1.pce),
    .parity_type    (cr1.ps)
);




















    
endmodule 