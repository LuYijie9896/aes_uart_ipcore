`resetall
`timescale 1ns / 1ps
`default_nettype none

module uart_rx
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
     * AXI4-Stream output (source)
     */
    taxi_axis_if.src   m_axis,

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
    output wire logic  idle,
    output wire logic  overrun_error,
    output wire logic  frame_error,
    output wire logic  parity_error,

    /*
     * UART interface
     */
    input  wire logic  rxd
);

typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_START,
    STATE_DATA,
    STATE_PARITY,
    STATE_STOP,
    STATE_WAIT_STOP
} state_t;
state_t state_reg = STATE_IDLE;

logic [7:0] m_axis_tdata_reg = 0;
logic m_axis_tvalid_reg = 1'b0;

logic rxd_reg = 1'b1;

logic overrun_error_reg = 1'b0;
logic frame_error_reg = 1'b0;
logic parity_error_reg = 1'b0;

logic [7:0] data_reg = 0;
logic [3:0] baud_cnt_reg = 0;
logic [2:0] bit_cnt_reg = 0;
logic parity_check_reg = 0;

logic [7:0] idle_cnt = 0;
logic idle_reg = 0;
logic [7:0] frame_len_ticks;
logic rx_activity_latched = 0;

assign m_axis.tdata = m_axis_tdata_reg;
assign m_axis.tkeep = 1'b1;
assign m_axis.tstrb = m_axis.tkeep;
assign m_axis.tvalid = m_axis_tvalid_reg;
assign m_axis.tlast = 1'b1;
assign m_axis.tid = '0;
assign m_axis.tdest = '0;
assign m_axis.tuser = '0;

assign busy = (state_reg != STATE_IDLE);
assign idle = idle_reg;
assign overrun_error = overrun_error_reg;
assign frame_error = frame_error_reg;
assign parity_error = parity_error_reg;

always_comb begin
    logic [3:0] total_bits;
    logic [1:0] stop_len;
    
    case (stop_bits)
        2'b00: stop_len = 1;
        2'b01: stop_len = 2; // 1.5 -> 2
        2'b10: stop_len = 2;
        default: stop_len = 1;
    endcase
    
    // 1 start + data + parity + stop
    total_bits = 1 + (4'd8 - data_bits) + parity_en + stop_len;
    frame_len_ticks = {total_bits, 3'b000}; // * 8
end

always_ff @(posedge Clk) begin
    rxd_reg <= rxd;
    overrun_error_reg <= 1'b0;
    frame_error_reg <= 1'b0;
    parity_error_reg <= 1'b0;
    idle_reg <= 1'b0;

    if (m_axis.tvalid && m_axis.tready) begin
        m_axis_tvalid_reg <= 1'b0;
    end

    if (baud_clk) begin
        // IDLE detection logic
        if (state_reg == STATE_IDLE && rxd_reg) begin
            if (idle_cnt < 8'hFF) begin
                idle_cnt <= idle_cnt + 1;
            end
            
            if (idle_cnt == frame_len_ticks) begin
                if (rx_activity_latched) begin
                    idle_reg <= 1'b1;
                    rx_activity_latched <= 1'b0;
                end
            end
        end else begin
            idle_cnt <= 0;
        end

        if (baud_cnt_reg != 0) begin
            baud_cnt_reg <= baud_cnt_reg - 1;
        end else begin
            case (state_reg)
                STATE_IDLE: begin
                    if (!rxd_reg) begin
                        // Start bit detected
                        baud_cnt_reg <= 3; // Wait 4 ticks to middle of start bit
                        state_reg <= STATE_START;
                        rx_activity_latched <= 1'b0;
                    end
                end
                STATE_START: begin
                    if (rxd_reg) begin
                        // False start
                        frame_error_reg <= 1'b1;
                        state_reg <= STATE_IDLE;
                    end else begin
                        baud_cnt_reg <= 7; // Wait 8 ticks to middle of first data bit
                        bit_cnt_reg <= 0;
                        parity_check_reg <= parity_type;
                        state_reg <= STATE_DATA;
                    end
                end
                STATE_DATA: begin
                    data_reg[bit_cnt_reg] <= rxd_reg;
                    parity_check_reg <= parity_check_reg ^ rxd_reg;
                    baud_cnt_reg <= 7;
                    if (bit_cnt_reg == (7 - data_bits)) begin
                        if (parity_en) begin
                            state_reg <= STATE_PARITY;
                        end else begin
                            state_reg <= STATE_STOP;
                        end
                    end else begin
                        bit_cnt_reg <= bit_cnt_reg + 1;
                    end
                end
                STATE_PARITY: begin
                    if (rxd_reg != parity_check_reg) begin
                        parity_error_reg <= 1'b1;
                    end
                    baud_cnt_reg <= 7;
                    state_reg <= STATE_STOP;
                end
                STATE_STOP: begin
                    if (!rxd_reg) begin
                        frame_error_reg <= 1'b1;
                    end else begin
                        // Valid frame (at least first stop bit is OK)
                        // Transfer data
                        case (data_bits)
                            2'b01: m_axis_tdata_reg <= {1'b0, data_reg[6:0]};
                            2'b10: m_axis_tdata_reg <= {2'b0, data_reg[5:0]};
                            2'b11: m_axis_tdata_reg <= {3'b0, data_reg[4:0]};
                            default: m_axis_tdata_reg <= data_reg;
                        endcase
                        m_axis_tvalid_reg <= 1'b1;
                        rx_activity_latched <= 1'b1;
                        overrun_error_reg <= m_axis_tvalid_reg;
                    end
                    
                    // Wait for remaining stop bits
                    case (stop_bits)
                        2'b00: baud_cnt_reg <= 0; // 1 stop bit (already waited 8 ticks)
                        2'b01: baud_cnt_reg <= 3; // 1.5 stop bits (wait 4 more ticks)
                        2'b10: baud_cnt_reg <= 7; // 2 stop bits (wait 8 more ticks)
                        default: baud_cnt_reg <= 0;
                    endcase
                    state_reg <= STATE_WAIT_STOP;
                end
                STATE_WAIT_STOP: begin
                    state_reg <= STATE_IDLE;
                end
                default: state_reg <= STATE_IDLE;
            endcase
        end
    end

    if (Rst || !En) begin
        state_reg <= STATE_IDLE;
        baud_cnt_reg <= 0;
        m_axis_tvalid_reg <= 1'b0;
        rxd_reg <= 1'b1;
        overrun_error_reg <= 1'b0;
        frame_error_reg <= 1'b0;
        parity_error_reg <= 1'b0;
        idle_cnt <= 0;
        idle_reg <= 1'b0;
        rx_activity_latched <= 1'b0;
    end
end

endmodule

`resetall
