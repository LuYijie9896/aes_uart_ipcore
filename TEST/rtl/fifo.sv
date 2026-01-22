`resetall
`timescale 1ns / 1ps
`default_nettype none

module fifo #
(
    parameter DEPTH = 16,
    parameter DATA_W = 8,
    parameter KEEP_W = ((DATA_W+7)/8),
    parameter KEEP_EN = 1'b1,
    parameter STRB_EN = 1'b0,
    parameter LAST_EN = 1'b1,
    parameter ID_EN = 1'b0,
    parameter ID_W = 8,
    parameter DEST_EN = 1'b0,
    parameter DEST_W = 8,
    parameter USER_EN = 1'b0,
    parameter USER_W = 1
)
(
    input  wire logic                    Clk,
    input  wire logic                    Rst,

    /*
     * AXI4-Stream input (sink)
     */
    taxi_axis_if.snk                     s_axis,

    /*
     * AXI4-Stream output (source)
     */
    taxi_axis_if.src                     m_axis,

    /*
     * Status
     */
    output wire logic [$clog2(DEPTH):0]  StatusDepth,
    output wire logic                    StatusOverflow
);

localparam FIFO_AW = $clog2(DEPTH);

// Signal packing offsets
localparam KEEP_OFFSET = DATA_W;
localparam STRB_OFFSET = KEEP_OFFSET + (KEEP_EN ? KEEP_W : 0);
localparam LAST_OFFSET = STRB_OFFSET + (STRB_EN ? KEEP_W : 0);
localparam ID_OFFSET   = LAST_OFFSET + (LAST_EN ? 1      : 0);
localparam DEST_OFFSET = ID_OFFSET   + (ID_EN   ? ID_W   : 0);
localparam USER_OFFSET = DEST_OFFSET + (DEST_EN ? DEST_W : 0);
localparam WIDTH       = USER_OFFSET + (USER_EN ? USER_W : 0);

logic [FIFO_AW:0] wr_ptr_reg = '0;
logic [FIFO_AW:0] rd_ptr_reg = '0;

// Memory instantiation
// For small DEPTH, Quartus will likely use MLAB or Logic Cells (ALMs)
(* ramstyle = "no_rw_check, mlab" *)
logic [WIDTH-1:0] mem[2**FIFO_AW];

// Full / Empty logic
wire full = wr_ptr_reg == (rd_ptr_reg ^ {1'b1, {FIFO_AW{1'b0}}});
wire empty = wr_ptr_reg == rd_ptr_reg;

assign s_axis.tready = !full;

// Packing AXI signals into memory word
wire [WIDTH-1:0] mem_wr_data;
assign mem_wr_data[DATA_W-1:0] = s_axis.tdata;

generate
    if (KEEP_EN) assign mem_wr_data[KEEP_OFFSET +: KEEP_W] = s_axis.tkeep;
    if (STRB_EN) assign mem_wr_data[STRB_OFFSET +: KEEP_W] = s_axis.tstrb;
    if (LAST_EN) assign mem_wr_data[LAST_OFFSET]           = s_axis.tlast;
    if (ID_EN)   assign mem_wr_data[ID_OFFSET   +: ID_W]   = s_axis.tid;
    if (DEST_EN) assign mem_wr_data[DEST_OFFSET +: DEST_W] = s_axis.tdest;
    if (USER_EN) assign mem_wr_data[USER_OFFSET +: USER_W] = s_axis.tuser;
endgenerate

// Write control logic
logic overflow_reg = 1'b0;
always_ff @(posedge Clk) begin
    overflow_reg <= 1'b0;
    if (s_axis.tready && s_axis.tvalid) begin
        mem[wr_ptr_reg[FIFO_AW-1:0]] <= mem_wr_data;
        wr_ptr_reg <= wr_ptr_reg + 1;
    end else if (s_axis.tvalid && full) begin
        overflow_reg <= 1'b1;
    end

    if (Rst) begin
        wr_ptr_reg <= '0;
        overflow_reg <= 1'b0;
    end
end

assign StatusDepth = wr_ptr_reg - rd_ptr_reg;
assign StatusOverflow = overflow_reg;

// Read path - Direct combinatorial read (FWFT style)
wire [WIDTH-1:0] mem_rd_data = mem[rd_ptr_reg[FIFO_AW-1:0]];

assign m_axis.tvalid = !empty;

always_ff @(posedge Clk) begin
    if (m_axis.tready && m_axis.tvalid) begin
        rd_ptr_reg <= rd_ptr_reg + 1;
    end

    if (Rst) begin
        rd_ptr_reg <= '0;
    end
end

// Unpacking signals to output axis interface
assign m_axis.tdata  = mem_rd_data[DATA_W-1:0];
assign m_axis.tkeep  = KEEP_EN ? mem_rd_data[KEEP_OFFSET +: KEEP_W] : '1;
assign m_axis.tstrb  = STRB_EN ? mem_rd_data[STRB_OFFSET +: KEEP_W] : m_axis.tkeep;
assign m_axis.tlast  = LAST_EN ? mem_rd_data[LAST_OFFSET]           : 1'b1;
assign m_axis.tid    = ID_EN   ? mem_rd_data[ID_OFFSET   +: ID_W]   : '0;
assign m_axis.tdest  = DEST_EN ? mem_rd_data[DEST_OFFSET +: DEST_W] : '0;
assign m_axis.tuser  = USER_EN ? mem_rd_data[USER_OFFSET +: USER_W] : '0;

endmodule

`resetall
