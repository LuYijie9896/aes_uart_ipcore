`timescale 1ns / 1ps
`default_nettype none

// tb_uart_tx.sv - focused parity verification
module tb_uart_tx;

    // parameters
    localparam CLK_PERIOD = 20; // ns (50 MHz)
    localparam BAUD8_PERIOD = 8; // number of Clk cycles per baud8 pulse period

    // DUT signals
    logic Clk = 0;
    logic Rst = 1;
    logic En = 0;
    logic baud_clk = 0;

    // AXI Stream interface
    taxi_axis_if #(8) s_if();

    // UART cfg
    logic [1:0] data_bits = 2'd0; // 0 -> 8 bits
    logic [1:0] stop_bits = 2'd0; // 0 -> 1 stop bit
    logic parity_en = 1'b0;
    logic parity_type = 1'b0; // 0 - odd (as implemented), 1 - even (inverted)

    // DUT outputs
    wire busy;
    wire tc;
    wire txd;

    // test variables (module scope)
    integer i;
    integer pt; // parity test index
    integer db; // loop index (avoid inline declarations in for loops)
    integer sb; // stop bits loop index

    logic [7:0] tx_byte;
    logic [7:0] rx_bits;
    logic parity_sample;
    logic parity_expected;
    logic stop_bit;

    // instantiate DUT
    uart_tx uut (
        .Clk(Clk),
        .Rst(Rst),
        .En(En),
        .baud_clk(baud_clk),
        .s_axis(s_if),
        .data_bits(data_bits),
        .stop_bits(stop_bits),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .busy(busy),
        .tc(tc),
        .txd(txd)
    );

    // clock
    initial begin
        Clk = 0;
        forever #(CLK_PERIOD/2) Clk = ~Clk;
    end

    // baud8 pulse generator: single-cycle pulse every BAUD8_PERIOD clocks
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

    // helper: send one byte over AXIS
    task automatic send_byte(input [7:0] data);
        begin
            @(posedge Clk);
            s_if.tdata <= data;
            s_if.tvalid <= 1'b1;
            wait (s_if.tready == 1'b1);
            @(posedge Clk);
            s_if.tvalid <= 1'b0;
        end
    endtask

    // main test
    initial begin
        $display("TB: uart_tx parity verification start");

        // reset & init
        Rst = 1; En = 0;
        s_if.tvalid = 0; s_if.tdata = 8'h00;
        repeat (5) @(posedge Clk);
        Rst = 0; En = 1;
        repeat (2) @(posedge Clk);

        // tests: 0 = none, 1 = odd, 2 = even
        for (pt = 0; pt < 3; pt = pt + 1) begin
            if (pt == 0) begin
                parity_en = 1'b0; parity_type = 1'b0;
                $display("\n--- Parity: NONE ---");
            end else if (pt == 1) begin
                parity_en = 1'b1; parity_type = 1'b0; // odd
                $display("\n--- Parity: ODD ---");
            end else begin
                parity_en = 1'b1; parity_type = 1'b1; // even (inverted)
                $display("\n--- Parity: EVEN ---");
            end

            // 8 data bits, 1 stop bit
            data_bits = 2'd0;
            stop_bits = 2'd0;

            // choose test byte with known parity (0x5A has even number of ones = 4)
            tx_byte = 8'h5A; // 01011010

            // send
            send_byte(tx_byte);

            // capture frame from serial line
            wait (txd == 1'b0); // start bit

            // wait half-bit (4 baud pulses) to sample middle of first data bit
            repeat (4) @(posedge baud_clk);

            // sample 8 data bits, LSB first
            rx_bits = '0;
            for (i = 0; i < 8; i = i + 1) begin
                rx_bits[i] = txd;
                // wait one full bit (8 baud pulses) before next sample
                repeat (8) @(posedge baud_clk);
            end

            // parity bit sampling (next bit)
            parity_sample = txd;
            // advance to stop bit sampling
            repeat (8) @(posedge baud_clk);
            stop_bit = txd;

            // compute expected parity according to DUT implementation
            parity_expected = ^tx_byte; // XOR of bits
            if (parity_type) parity_expected = ~parity_expected; // invert when parity_type==1

            // checks
            if (parity_en) begin
                if (parity_sample !== parity_expected) $error("Parity mismatch (pt=%0d): sent=0x%0h expected=%0b sample=%0b", pt, tx_byte, parity_expected, parity_sample);
                else $display("Parity OK (pt=%0d): expected=%0b sample=%0b ✅", pt, parity_expected, parity_sample);
            end else begin
                // when parity disabled, the position should be stop/idle (1)
                if (parity_sample !== 1'b1) $error("Parity disabled: expected idle(1) at parity position, got=%0b", parity_sample);
                else $display("No-parity behavior OK (idle at parity pos) ✅");
            end

            if (stop_bit !== 1'b1) $error("Stop bit not high for pt=%0d", pt); else $display("Stop bit OK ✅");

            // wait for transmit complete
            wait (tc == 1'b1);
            $display("Frame complete (pt=%0d) ✅", pt);

            // small delay between tests
            repeat (10) @(posedge Clk);
        end

        // Stop bits tests: 1, 1.5, 2 (8 data bits, no parity)
        begin
            parity_en = 1'b0;
            parity_type = 1'b0;
            data_bits = 2'd0;
            $display("\n--- Stop bits test: 1, 1.5, 2 ---");

            tx_byte = 8'hA5;
            for (sb = 0; sb < 3; sb = sb + 1) begin
                stop_bits = sb; // 0->1, 1->1.5, 2->2
                $display("\nTest stop_bits=%0d", sb);

                send_byte(tx_byte);

                // capture frame
                wait (txd == 1'b0); // start bit

                // wait half-bit to sample first data bit
                repeat (4) @(posedge baud_clk);

                // sample 8 data bits
                rx_bits = '0;
                for (i = 0; i < 8; i = i + 1) begin
                    rx_bits[i] = txd;
                    repeat (8) @(posedge baud_clk);
                end

                // now check stop bit behavior depending on stop_bits
                if (stop_bits == 0) begin
                    // 1 stop bit: sample mid-stop
                    repeat (8) @(posedge baud_clk);
                    stop_bit = txd;
                    if (stop_bit !== 1'b1) $error("Stop bit (1) failed for stop_bits=%0d", stop_bits);
                    else $display("Stop bit (1) OK ✅");
                end else if (stop_bits == 1) begin
                    // 1.5 stop bits: sample mid of first stop, then mid of half-bit
                    repeat (8) @(posedge baud_clk);
                    stop_bit = txd;
                    if (stop_bit !== 1'b1) $error("Stop bit (1.5) first half failed for stop_bits=%0d", stop_bits);
                    else $display("Stop bit (1.5) first half OK ✅");

                    // sample middle of the extra half bit (4 pulses)
                    repeat (4) @(posedge baud_clk);
                    stop_bit = txd;
                    if (stop_bit !== 1'b1) $error("Stop bit (1.5) half failed for stop_bits=%0d", stop_bits);
                    else $display("Stop bit (1.5) extra half OK ✅");
                end else begin
                    // 2 stop bits: sample mid of first stop and mid of second stop
                    repeat (8) @(posedge baud_clk);
                    stop_bit = txd;
                    if (stop_bit !== 1'b1) $error("Stop bit (2) first failed for stop_bits=%0d", stop_bits);
                    else $display("Stop bit (2) first OK ✅");

                    repeat (8) @(posedge baud_clk);
                    stop_bit = txd;
                    if (stop_bit !== 1'b1) $error("Stop bit (2) second failed for stop_bits=%0d", stop_bits);
                    else $display("Stop bit (2) second OK ✅");
                end

                // wait for frame complete
                wait (tc == 1'b1);
                repeat (5) @(posedge Clk);
            end
        end

        $display("TB: parity & stop-bit verification finished");
        #100 $finish;
    end

endmodule

`resetall
`default_nettype wire
