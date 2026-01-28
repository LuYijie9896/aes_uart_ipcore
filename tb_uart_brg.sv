`timescale 1ns / 1ps
`default_nettype none

// Testbench for uart_brg
// - verifies 115200 & 9600 baud (baud_clk is 8x)
// - checks that fractional prescale changes interval pattern

module tb_uart_brg;

    localparam PRE_W = 16;
    localparam FRAC_W = 4;
    localparam integer CLK_FREQ = 50_000_000; // 50 MHz clock

    // DUT signals
    logic Clk = 0;
    logic Rst = 1;
    logic En = 0;
    logic [PRE_W-1:0] Prescale = 0;
    logic baud_clk;

    // cycle counter (clock cycles)
    integer cycle_cnt = 0;
    always @(posedge Clk) cycle_cnt = cycle_cnt + 1;

    // instantiate DUT
    uart_brg #(.PRE_W(PRE_W)) uut (
        .Clk(Clk),
        .Rst(Rst),
        .En(En),
        .baud_clk(baud_clk),
        .Prescale(Prescale)
    );

    // 50MHz clock
    initial begin
        Clk = 0;
        forever #10 Clk = ~Clk; // 20 ns period
    end

    // Test sequence
    initial begin
        $display("TB: uart_brg tests start");

        // reset
        Rst = 1; En = 0; Prescale = 0;
        repeat (10) @(posedge Clk);
        Rst = 0;

        // run tests
        run_prescale_for_baud(115200, 200, "115200 (auto prescale)");
        run_int_vs_frac(115200, 200);
        run_prescale_for_baud(9600, 200, "9600 (auto prescale)");

        $display("TB: all tests finished");
        $finish;
    end

    // run with computed prescale for a baud and sample 'samples' pulses
    task automatic run_prescale_for_baud(input int baud, input int samples, input string name);
        integer prescale_fix;
        real prescale_real;
        begin
            prescale_real = CLK_FREQ / (baud * 8.0);
            prescale_fix = $rtoi(prescale_real * (1<<FRAC_W) + 0.5);
            run_with_prescale(prescale_fix, baud, samples, name);
        end
    endtask

    // compare integer-only prescale vs fractional prescale for same integer part
    task automatic run_int_vs_frac(input int baud, input int samples);
        integer prescale_fix;
        integer int_only_prescale;
        real prescale_real;
        integer int_part;
        begin
            $display("\n--- compare integer-only vs fractional prescale for baud %0d ---", baud);
            prescale_real = CLK_FREQ / (baud * 8.0);
            prescale_fix = $rtoi(prescale_real * (1<<FRAC_W) + 0.5);
            int_part = prescale_fix >> FRAC_W;
            int_only_prescale = (int_part << FRAC_W);

            // fractional version
            run_with_prescale(prescale_fix, baud, samples, {"frac prescale (", $sformatf("%0d", prescale_fix), ")"});
            // integer-only version
            run_with_prescale(int_only_prescale, baud, samples, {"int-only prescale (", $sformatf("%0d", int_only_prescale), ")"});
        end
    endtask

    // core capture routine
    task automatic run_with_prescale(input int prescale_fix, input int baud, input int samples, input string name);
        integer i;
        integer timestamps[0:1999]; // enough for typical sample values
        integer total_cycles;
        real measured_baud8, errpct;
        integer min_int, max_int, d;
        integer int_part, frac_part;
        begin
            int_part = prescale_fix >> FRAC_W;
            frac_part = prescale_fix & ((1<<FRAC_W)-1);
            $display("\nTest: %s -> prescale=%0d (int=%0d frac=%0d)", name, prescale_fix, int_part, frac_part);

            // apply prescale and enable
            @(posedge Clk);
            Prescale = prescale_fix;
            En = 1;

            // wait for first pulse to start measurement
            @(posedge baud_clk);
            timestamps[0] = cycle_cnt;
            for (i=1; i<samples; i=i+1) begin
                @(posedge baud_clk);
                timestamps[i] = cycle_cnt;
            end

            // disable
            @(posedge Clk);
            En = 0;

            total_cycles = timestamps[samples-1] - timestamps[0];
            measured_baud8 = $itor((samples-1)) * CLK_FREQ / $itor(total_cycles);

            // compute min/max interval
            min_int = 32'h7fffffff; max_int = 0;
            for (i=1; i<samples; i=i+1) begin
                d = timestamps[i] - timestamps[i-1];
                if (d < min_int) min_int = d;
                if (d > max_int) max_int = d;
            end

            $display("Result: measured baud8 = %0f Hz, expected = %0f Hz, error = %0f%%",
                     measured_baud8, baud*8.0, 100.0*(measured_baud8 - baud*8.0)/(baud*8.0));
            $display("Intervals (clock cycles): min=%0d max=%0d avg=%0f", min_int, max_int, $itor(total_cycles)/(samples-1));

            // checks
            if (frac_part != 0) begin
                if (min_int == max_int) $error("Expected varying intervals for fractional prescale but intervals were uniform");
                else $display("Fractional behaviour observed (intervals vary) ✅");
            end else begin
                if (min_int != max_int) $error("Expected uniform intervals for integer-only prescale but got variations");
                else $display("Integer-only prescale gives uniform intervals ✅");
            end

            // simple frequency tolerance check (0.5%)
            errpct = 100.0*(measured_baud8 - baud*8.0)/(baud*8.0);
            if (errpct > 0.5 || errpct < -0.5) $error("Measured frequency deviates more than 0.5%%: %0f%%", errpct);

        end
    endtask

endmodule

`resetall
`default_nettype wire
