`timescale 1ns / 1ps

module tb_fifo;

    // Parameters
    parameter DEPTH = 16;
    parameter DATA_W = 8;
    
    // Clock and Reset
    logic clk = 0;
    logic rst = 0;
    always #5 clk = ~clk; // 100MHz

    // Interface instantiation
    taxi_axis_if #(
        .DATA_W(DATA_W)
    ) s_axis_if ();
    
    taxi_axis_if #(
        .DATA_W(DATA_W)
    ) m_axis_if ();

    // Status signals
    logic [$clog2(DEPTH):0] status_depth;
    logic status_overflow;

    // DUT Instantiation
    fifo #(
        .DEPTH(DEPTH),
        .DATA_W(DATA_W)
    ) dut (
        .Clk(clk),
        .Rst(rst),
        .s_axis(s_axis_if),
        .m_axis(m_axis_if),
        .StatusDepth(status_depth),
        .StatusOverflow(status_overflow)
    );

    // Test sequence
    initial begin
        // Reset
        rst = 1;
        s_axis_if.tvalid = 0;
        s_axis_if.tdata = 0;
        s_axis_if.tlast = 0;
        m_axis_if.tready = 0;
        #20;
        rst = 0;
        #20;

        $display("--- Start Test: Continuous Write ---");
        // 1. Write until full
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            s_axis_if.tvalid <= 1;
            s_axis_if.tdata  <= i + 8'hA0;
            s_axis_if.tlast  <= (i == DEPTH-1);
            
            // Wait for handshake
            wait(s_axis_if.tready);
        end
        @(posedge clk);
        s_axis_if.tvalid <= 0;
        
        #20;
        if (status_depth == DEPTH) 
            $display("[PASS] FIFO is FULL, Depth: %d", status_depth);
        else
            $display("[FAIL] FIFO Depth mismatch: %d", status_depth);

        $display("--- Start Test: Continuous Read ---");
        // 2. Read until empty
        @(posedge clk);
        m_axis_if.tready <= 1;
        
        for (int i = 0; i < DEPTH; i++) begin
            wait(m_axis_if.tvalid);
            if (m_axis_if.tdata !== (i + 8'hA0))
                $display("[FAIL] Data mismatch at index %d: Expected %h, Got %h", i, i+8'hA0, m_axis_if.tdata);
            @(posedge clk);
        end
        
        m_axis_if.tready <= 0;
        #20;
        
        if (status_depth == 0)
            $display("[PASS] FIFO is EMPTY, Depth: %d", status_depth);
        else
            $display("[FAIL] FIFO not empty, Depth: %d", status_depth);

        $display("--- Test: Simultaneous Read/Write ---");
        // 3. Simple Read/Write at the same time
        @(posedge clk);
        s_axis_if.tvalid <= 1;
        s_axis_if.tdata <= 8'hFF;
        m_axis_if.tready <= 1;
        
        @(posedge clk);
        s_axis_if.tvalid <= 0;
        m_axis_if.tready <= 0;
        
        #50;
        $display("--- Test Completed ---");
        $finish;
    end

endmodule
