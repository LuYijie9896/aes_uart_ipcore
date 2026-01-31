`resetall
`timescale 1ns / 1ps

module fifo #
(
    parameter DEPTH = 16,
    parameter DATA_W = 8,
    parameter KEEP_W = ((DATA_W+7)/8)
)
(
    input  wire logic                    Clk,
    input  wire logic                    Rst,

    /*
     * AXI4-Stream input (sink)
     */
    my_axis_if.slave                     s_axis,

    /*
     * AXI4-Stream output (source)
     */
    my_axis_if.master                     m_axis,

    /*
     * Status
     */
    output wire logic [$clog2(DEPTH):0]  StatusDepth,
    output wire logic                    StatusOverflow
);

localparam FIFO_AW = $clog2(DEPTH);

// Signal packing offsets
localparam KEEP_OFFSET = DATA_W;
localparam LAST_OFFSET = KEEP_OFFSET + KEEP_W;
localparam WIDTH       = LAST_OFFSET + 1;

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
assign mem_wr_data[DATA_W-1:0]                    = s_axis.tdata;
assign mem_wr_data[KEEP_OFFSET +: KEEP_W]        = s_axis.tkeep;
assign mem_wr_data[LAST_OFFSET]                  = s_axis.tlast;

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
assign m_axis.tkeep  = mem_rd_data[KEEP_OFFSET +: KEEP_W];
assign m_axis.tlast  = mem_rd_data[LAST_OFFSET];

endmodule

`resetall
