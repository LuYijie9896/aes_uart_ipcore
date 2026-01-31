`resetall
`timescale 1ns / 1ps

module uart_tx
(
    /*
     * System signals
     */
    input  wire logic  Clk,
    input  wire logic  Rst,
    input  wire logic  En,

    /*
     * Baud rate pulse in 
     */
    input  wire logic  baud_clk,

    /*
     * AXI4-Stream input (slave)
     */
    my_axis_if.slave   s_axis, 

    /*
     * UART configuration
     */
    input  wire logic [1:0] data_bits,   // 0: 8 bits, 1: 7 bits, 2: 6 bits, 3: 5 bits
    input  wire logic [1:0] stop_bits,   // 0: 1 stop bit, 1: 1.5 stop bits, 2: 2 stop bits
    input  wire logic       parity_en,   // Modified: 1 - parity enabled, 0 - parity disabled
    input  wire logic       parity_type, // Modified: 1 - odd parity, 0 - even parity

    /*
     * Status
     */
    output wire logic  busy, 
    output wire logic  tc,

    /*
     * UART interface 
     */
    output wire logic  txd
);

logic s_axis_tready_reg = 1'b0;
logic txd_reg = 1'b1;
logic busy_reg = 1'b0;
logic tc_reg = 1'b0;

logic [10:0] data_reg = 0; 
logic [2:0]  baud_cnt_reg = 0; 
logic [3:0]  bit_cnt_reg = 0;
logic parity_bit = 1'b0;

assign s_axis.tready = s_axis_tready_reg; 
assign txd = txd_reg;
assign busy = busy_reg;
assign tc = tc_reg;

// Calculate parity bit based on data bits
always_comb begin
    logic [7:0] d;
    d = s_axis.tdata; 
    case(data_bits)
        2'd0: parity_bit = ^d[7:0]; 
        2'd1: parity_bit = ^d[6:0];
        2'd2: parity_bit = ^d[5:0];
        2'd3: parity_bit = ^d[4:0];
        default: parity_bit = ^d[7:0];
    endcase
    if (parity_type) parity_bit = ~parity_bit; 
end

// Main transmit logic
always_ff @(posedge Clk) begin
    s_axis_tready_reg <= 1'b0;
    tc_reg <= 1'b0;

    if (!baud_clk) begin
        // Wait for baud rate pulse
    end else if (baud_cnt_reg != 0) begin
        baud_cnt_reg <= baud_cnt_reg - 1;
    end else if (bit_cnt_reg == 0) begin
        busy_reg <= 1'b0; // Idle state
        if (busy_reg && !s_axis.tvalid) tc_reg <= 1'b1;
        if (s_axis.tvalid) begin // Check if AXIS input is valid
            s_axis_tready_reg <= 1'b1;
            busy_reg <= 1'b1;
            txd_reg  <= 1'b0; // Transmit start bit            
            baud_cnt_reg <= 3'd7; 
            case(data_bits)
                2'd1: begin // 7 data bits
                    data_reg <= parity_en ? {3'b111, parity_bit, s_axis.tdata[6:0]} : {4'b1111, s_axis.tdata[6:0]};
                end
                2'd2: begin // 6 data bits
                    data_reg <= parity_en ? {4'b1111, parity_bit, s_axis.tdata[5:0]} : {5'b11111, s_axis.tdata[5:0]};
                end
                2'd3: begin // 5 data bits
                    data_reg <= parity_en ? {5'b11111, parity_bit, s_axis.tdata[4:0]} : {6'b111111, s_axis.tdata[4:0]};
                end
                default: begin // 8 data bits
                    data_reg <= parity_en ? {2'b11, parity_bit, s_axis.tdata[7:0]} : {3'b111, s_axis.tdata[7:0]};
                end
            endcase

            bit_cnt_reg <= (stop_bits == 2'd0 ? 1'd1 : 2'd2) + parity_en + 4'd8 - data_bits; 

        end
    end else begin
        if (bit_cnt_reg == 1 && stop_bits == 2'd1) begin
            // 1.5 stop bits special handling: shorten baud rate count to 4 cycles (4'd3) in the last cycle
            baud_cnt_reg <= 3'd3;       
        end else begin // Normal stop bit handling
            baud_cnt_reg <= 3'd7;
        end
        // Shift and transmit
        {data_reg, txd_reg} <= {1'b1, data_reg};
        bit_cnt_reg <= bit_cnt_reg - 1;
    end
    
    if (Rst || !En) begin
        s_axis_tready_reg <= 1'b0;
        txd_reg <= 1'b1;
        baud_cnt_reg <= 0;
        bit_cnt_reg <= 0;
        busy_reg <= 1'b0;
        tc_reg <= 1'b0;
    end
end

endmodule