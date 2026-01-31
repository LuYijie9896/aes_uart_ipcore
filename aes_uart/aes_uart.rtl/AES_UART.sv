module AES_UART #(
    parameter DATA_W = 32,
    parameter ADDR_W = 32
) (
    input  logic Clk,
    input  logic Rst_n,

    // Write address channel
    input  logic [ADDR_W-1:0]    awaddr,
    input  logic [2:0]           awprot,
    input  logic                 awvalid,
    output logic                 awready,
    // Write data channel
    input  logic [DATA_W-1:0]    wdata,
    input  logic [(DATA_W/8)-1:0] wstrb,
    input  logic                 wvalid,
    output logic                 wready,
    // Write response channel
    output logic [1:0]           bresp,
    output logic                 bvalid,
    input  logic                 bready,
    // Read address channel
    input  logic [ADDR_W-1:0]    araddr,
    input  logic [2:0]           arprot,
    input  logic                 arvalid,
    output logic                 arready,
    // Read data channel
    output logic [DATA_W-1:0]    rdata,
    output logic [1:0]           rresp,
    output logic                 rvalid,
    input  logic                 rready,
    
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

my_axis_if #(.DATA_W(8)) fifo_tx_axis_if();
my_axis_if #(.DATA_W(8)) fifo_rx_axis_if();

my_axis_if #(.DATA_W(8)) fifo_tx_data_sel_m_axis_if();    // From data_stream_sel_aes_tf
my_axis_if #(.DATA_W(8)) fifo_rx_data_sel_m_axis_if();    // From data_stream_sel_aes_rf

my_axis_if #(.DATA_W(8)) cipher_out_axis_if();
my_axis_if #(.DATA_W(8)) invcipher_in_axis_if();

my_axis_if #(.DATA_W(128)) cipher_in_axis_if();
my_axis_if #(.DATA_W(128)) invcipher_out_axis_if();

my_axis_if #(.DATA_W(8)) tdr_axis_if();
my_axis_if #(.DATA_W(8)) rdr_axis_if();

my_axis_if #(.DATA_W(128)) epr_axis_if();
my_axis_if #(.DATA_W(128)) dpr_axis_if();

my_axis_if #(.DATA_W(8)) rfsle_axis_if();
my_axis_if #(.DATA_W(8)) tfsle_axis_if();

// Internal AXI-Lite interface instance
my_axil_if #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) axil_if();

// Connect external AXI-Lite ports to internal interface
assign axil_if.awaddr  = awaddr;
assign axil_if.awprot  = awprot;
assign axil_if.awvalid = awvalid;
assign awready         = axil_if.awready;
assign axil_if.wdata   = wdata;
assign axil_if.wstrb   = wstrb;
assign axil_if.wvalid  = wvalid;
assign wready          = axil_if.wready;
assign bresp           = axil_if.bresp;
assign bvalid          = axil_if.bvalid;
assign axil_if.bready  = bready;
assign axil_if.araddr  = araddr;
assign axil_if.arprot  = arprot;
assign axil_if.arvalid = arvalid;
assign arready         = axil_if.arready;
assign rdata           = axil_if.rdata;
assign rresp           = axil_if.rresp;
assign rvalid          = axil_if.rvalid;
assign axil_if.rready  = rready;

// ISR Mapping
logic [7:0] txft_th;
logic [7:0] rxft_th;

always_comb begin
    // TX FIFO 阈值换算（深度=16）
    case (cr2.txftcfg)
        3'b000: txft_th = 8'd2;   // 1/8
        3'b001: txft_th = 8'd4;   // 1/4
        3'b010: txft_th = 8'd8;   // 1/2
        3'b011: txft_th = 8'd12;  // 3/4
        3'b100: txft_th = 8'd14;  // 7/8
        3'b101: txft_th = 8'd0;   // Empty -> 深度<=0
        default: txft_th = 8'd2;
    endcase

    // RX FIFO 阈值换算（深度=16）
    case (cr2.rxftcfg)
        3'b000: rxft_th = 8'd2;   // 1/8
        3'b001: rxft_th = 8'd4;   // 1/4
        3'b010: rxft_th = 8'd8;   // 1/2
        3'b011: rxft_th = 8'd12;  // 3/4
        3'b100: rxft_th = 8'd14;  // 7/8
        3'b101: rxft_th = 8'd16;  // Full -> 深度>=16
        default: rxft_th = 8'd2;
    endcase
end

assign isr.reserved = '0;
assign isr.txfe     = (fifo_tx_depth == 0);
assign isr.rxff     = (fifo_rx_depth == 16);
assign isr.txft     = (fifo_tx_depth <= txft_th);
assign isr.rxft     = (fifo_rx_depth >= rxft_th);
// ere, drne, txe, rxne are internal to axil_regs so these inputs are ignored by it for those fields
assign isr.ere      = 1'b0;
assign isr.drne     = 1'b0;
assign isr.txe      = 1'b0;
assign isr.rxne     = 1'b0;

// Looping mode
assign rxd = (cr1.wm == 2'b11) ? txd  : Rx; 
assign Tx  = (cr1.wm == 2'b11) ? 1'b1 : txd;  

axil_regs axil_regs_inst (
    .clk            (Clk),
    .rst            (!Rst_n),

    // AXI4-Lite Control Interface
    .s_axil         (axil_if.slave),

    .o_cr1          (cr1),          
    .o_cr2          (cr2),          
    .o_brr          (brr),          
    .i_isr          (isr),          

    .o_ekr          (ekr),     
    .o_dkr          (dkr),     

    .s_axis_rdr     (rdr_axis_if.slave),     
    .m_axis_tdr     (tdr_axis_if.master),     
    .m_axis_epr     (epr_axis_if.master),     
    .s_axis_dpr     (dpr_axis_if.slave),

    .o_ekey_update      (ekey_update),
    .o_dkey_update      (dkey_update),
    .o_ekey_len_update  (ekey_len_update),
    .o_dkey_len_update  (dkey_len_update)
);

regs_aes_bridge regs_aes_bridge_inst(
    .clk            (Clk),    
    .rst            (!Rst_n),  

    .wm             (cr1.wm),
    .ee             (cr1.ee),
    .de             (cr1.de),
    .idle           (isr.idle),

    .s_axis_r_8     (tdr_axis_if.slave),            // from tdr
    .s_axis_r_128   (epr_axis_if.slave),            // from epr
    .m_axis_8       (tfsle_axis_if.master),        // to sel
    .m_axis_128     (cipher_in_axis_if.master),    // to cipher

    .m_axis_r_8     (rdr_axis_if.master),          // to rdr
    .m_axis_r_128   (dpr_axis_if.master),          // to dpr
    .s_axis_8       (rfsle_axis_if.slave),          // from sel
    .s_axis_128     (invcipher_out_axis_if.slave)   // from invcipher
);

AESCipher aes_cipher_inst(
	.Clk            (Clk),
    .Rst            (!Rst_n),
    .En             (cr1.aue & cr1.ee),
    .KeyLen         (cr1.el),        
	.Key            ({ekr[7], ekr[6], ekr[5], ekr[4], ekr[3], ekr[2], ekr[1], ekr[0]}),           
    .KeyUpdate      (ekey_update),     
    .KeyLenUpdate   (ekey_len_update),  

    .s_axis         (cipher_in_axis_if.slave),        
    .m_axis         (cipher_out_axis_if.master)
);

InvAESCipher inv_aes_cipher_inst(
	.Clk            (Clk),
    .Rst            (!Rst_n),
    .En             (cr1.aue & cr1.de),
    .KeyLen         (cr1.dl),        
	.Key            ({dkr[7], dkr[6], dkr[5], dkr[4], dkr[3], dkr[2], dkr[1], dkr[0]}),           
    .KeyUpdate      (dkey_update),     
    .KeyLenUpdate   (dkey_len_update),  

    .s_axis         (invcipher_in_axis_if.slave),        
    .m_axis         (invcipher_out_axis_if.master)
);

data_stream_sel_aes_tf data_stream_sel_aes_tf_inst(
    .en             (cr1.ee),
    .wm             (cr1.wm),
    .s0_axis        (cipher_out_axis_if.slave),         
    .s1_axis        (tfsle_axis_if.slave),
    .m_axis         (fifo_tx_data_sel_m_axis_if.master)
);

data_stream_sel_aes_rf data_stream_sel_aes_rf_inst(
    .en             (cr1.de),
    .wm             (cr1.wm),
    .s_axis         (fifo_rx_data_sel_m_axis_if.slave),
    .m0_axis        (invcipher_in_axis_if.master),
    .m1_axis        (rfsle_axis_if.master)
);

fifo #(.DEPTH(16)) fifo_tx_inst(
    .Clk            (Clk),
    .Rst            (!Rst_n),
    .s_axis         (fifo_tx_data_sel_m_axis_if.slave),
    .m_axis         (fifo_tx_axis_if.master),
    .StatusDepth    (fifo_tx_depth[4:0]),
    .StatusOverflow (fifo_tx_overflow)
);
assign fifo_tx_depth[7:5] = '0;

fifo #(.DEPTH(16)) fifo_rx_inst(
    .Clk            (Clk),
    .Rst            (!Rst_n),
    .s_axis         (fifo_rx_axis_if.slave),
    .m_axis         (fifo_rx_data_sel_m_axis_if.master),
    .StatusDepth    (fifo_rx_depth[4:0]),
    .StatusOverflow (fifo_rx_overflow)
);
assign fifo_rx_depth[7:5] = '0;

uart uart_inst(
    .Clk            (Clk),
    .Rst            (!Rst_n),
    .En             (cr1.aue),
    .TEn            (cr1.te),
    .REn            (cr1.re),
    .s_axis         (fifo_tx_axis_if.slave),
    .m_axis         (fifo_rx_axis_if.master),
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