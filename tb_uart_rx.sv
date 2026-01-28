`timescale 1ns / 1ps
`default_nettype none

// Testbench for uart_rx - basic 8N1 receive verification
// - 8 data bits, no parity, 1 stop bit
// - drive serial rxd line and verify m_axis outputs

module tb_uart_rx;

    localparam CLK_PERIOD = 20; // ns -> 50 MHz
    localparam BAUD8_PERIOD = 8; // number of Clk cycles per baud8 pulse period

    // signals
    logic Clk = 0;
    logic Rst = 1;
    logic En = 0;
    logic baud_clk = 0;
    logic rxd = 1'b1; // idle high

    // AXIS interface (monitor)
    taxi_axis_if #(8) m_if();

    // DUT config
    logic [1:0] data_bits = 2'd0; // 8 bits
    logic [1:0] stop_bits = 2'd0; // 1 stop bit
    logic parity_en = 1'b0;
    logic parity_type = 1'b0;

    // DUT status
    wire busy;
    wire idle;
    wire overrun_error;
    wire frame_error;
    wire parity_error;

    // test variables
    logic [7:0] test_vecs[0:3];
    integer i;
    integer timeout;
    integer errors;

    // instantiate DUT
    uart_rx uut (
        .Clk(Clk),
        .Rst(Rst),
        .En(En),
        .baud_clk(baud_clk),
        .m_axis(m_if),
        .data_bits(data_bits),
        .stop_bits(stop_bits),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .busy(busy),
        .idle(idle),
        .overrun_error(overrun_error),
        .frame_error(frame_error),
        .parity_error(parity_error),
        .rxd(rxd)
    );

    // clock generator
    initial begin
        Clk = 0;
        forever #(CLK_PERIOD/2) Clk = ~Clk;
    end

    // generate simple baud8 pulse (one-cycle pulse every BAUD8_PERIOD clocks)
    integer baud_cnt = 0;
    always_ff @(posedge Clk) begin
        if (Rst || !En) begin
            baud_cnt <= 0;
            baud_clk <= 0;
        end else begin
            if (baud_cnt == BAUD8_PERIOD-1) begin
                baud_cnt <= 0;
                baud_clk <= 1;
            end else begin
                baud_cnt <= baud_cnt + 1;
                baud_clk <= 0;
            end
        end
    end

    // accept all incoming frames
    initial begin
        m_if.tready = 1'b1;
    end

    // helper: send one UART frame on rxd (8N1)
    task automatic send_frame(input [7:0] data);
        integer i;
        begin
            // ensure idle
            rxd <= 1'b1;
            @(posedge Clk);

            // start bit
            rxd <= 1'b0;
            // hold for 1 bit (8 baud ticks)
            repeat (8) @(posedge baud_clk);

            // data bits LSB first
            for (i = 0; i < 8; i = i + 1) begin
                rxd <= data[i];
                repeat (8) @(posedge baud_clk);
            end

            // stop bit (1 bit)
            rxd <= 1'b1;
            repeat (8) @(posedge baud_clk);

            // leave line idle a bit
            repeat (2) @(posedge baud_clk);
        end
    endtask

    // wait for m_axis.tvalid with timeout (in baud pulses)
    task automatic wait_for_valid(output int cnt, input int timeout_pulses);
        begin
            cnt = 0;
            while (!m_if.tvalid && cnt < timeout_pulses) begin
                @(posedge baud_clk);
                cnt = cnt + 1;
            end
        end
    endtask

    // main test
    initial begin
        $display("TB: uart_rx basic 8N1 test start");

        // reset
        Rst = 1; En = 0; m_if.tready = 1'b1; rxd = 1'b1;
        repeat (5) @(posedge Clk);
        Rst = 0; En = 1;
        repeat (2) @(posedge Clk);

        // ensure config: 8N1
        data_bits = 2'd0; stop_bits = 2'd0; parity_en = 1'b0; parity_type = 1'b0;

        // test vectors
        test_vecs[0] = 8'hA5;
        test_vecs[1] = 8'h5A;
        test_vecs[2] = 8'h00;
        test_vecs[3] = 8'hFF;

        errors = 0;

        for (i = 0; i < 4; i = i + 1) begin
            $display("\nSending frame %0d: 0x%0h", i, test_vecs[i]);
            send_frame(test_vecs[i]);

            // wait for valid
            wait_for_valid(timeout, 40); // 40 baud pulses max
            if (m_if.tvalid == 0) begin
                $error("Timeout waiting for m_axis.tvalid for frame %0d", i);
                errors = errors + 1;
                continue;
            end

            // capture
            if (m_if.tdata !== test_vecs[i]) begin
                $error("Data mismatch for frame %0d: expected=0x%0h got=0x%0h", i, test_vecs[i], m_if.tdata);
                errors = errors + 1;
            end else begin
                $display("Frame %0d received OK: 0x%0h ✅", i, m_if.tdata);
            end

            // ensure no errors
            if (frame_error) begin
                $error("Frame error asserted for frame %0d", i); errors = errors + 1; end
            if (parity_error) begin
                $error("Parity error asserted for frame %0d", i); errors = errors + 1; end
            if (overrun_error) begin
                $error("Overrun error asserted for frame %0d", i); errors = errors + 1; end

            // accept the data
            @(posedge Clk);
            // m_if.tready is 1 so acceptance happens next cycle
            @(posedge Clk);
            // small gap
            repeat (4) @(posedge baud_clk);
        end

        if (errors == 0) $display("TB: all frames received OK ✅"); else $display("TB: %0d errors detected ❌", errors);

        $display("TB: uart_rx basic 8N1 test finished");
        #100 $finish;
    end

endmodule

`resetall
`default_nettype wire
