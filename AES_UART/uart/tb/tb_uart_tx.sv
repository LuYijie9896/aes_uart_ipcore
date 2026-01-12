`timescale 1ns / 1ps

module tb_uart_tx();

    // Signal definitions
    logic clk = 0;
    logic rst = 1;
    logic [1:0] data_bits;
    logic [1:0] stop_bits;
    logic parity_en;
    logic parity_type;
    logic txd;
    logic busy;
    logic baud_clk = 0;

    // Instantiate AXI-Stream interface
    taxi_axis_if #( .DATA_W(8) ) axis_if ();

    // Instantiate Device Under Test (DUT)
    uart_tx dut (
        .clk(clk),
        .rst(rst),
        .s_axis_tx(axis_if.snk), 
        .data_bits(data_bits),
        .stop_bits(stop_bits),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .txd(txd),
        .busy(busy),             
        .baud_clk(baud_clk)     
    );

    // Clock generation (100MHz)
    always #5 clk = ~clk;

    // Baud rate pulse generation logic (Simulating 115200 baud rate)
    // 115200 * 8 = 921,600 Hz. Period approx 1085ns
    initial begin
        forever begin
            #1080;
            baud_clk = 1;
            #10; 
            baud_clk = 0;
        end
    end

    // Send data task
    task send_byte(input [7:0] data);
        begin
            @(posedge clk);
            axis_if.tdata = data;
            axis_if.tvalid = 1;
            // Wait for handshake success
            wait(axis_if.tready);
            @(posedge clk);
            axis_if.tvalid = 0;
            // Wait for current byte transmission to complete
            wait(!busy);
            #100; // Byte gap
        end
    endtask

    // Test process
    initial begin
        // Initialize signals
        axis_if.tvalid = 0;
        axis_if.tdata = 0;
        rst = 1;
        #100;
        rst = 0;
        #100;

        // --- Test Case 1: 8N1 Mode (0x55) ---
        $display("Testing 8N1 Mode...");
        data_bits   = 2'd0; // 8 bits
        stop_bits   = 2'd0; // 1 stop bit
        parity_en   = 1'b0; // No parity
        send_byte(8'h55);

        // --- Test Case 2: 7E1.5 Mode (0x3F) ---
        $display("Testing 7E1.5 Mode...");
        data_bits   = 2'd1; // 7 bits
        stop_bits   = 2'd1; // 1.5 stop bits
        parity_en   = 1'b1; // Enable parity
        parity_type = 1'b0; // Even parity
        send_byte(8'h3F);

        // --- Test Case 3: 8O2 Mode (0xAA) ---
        $display("Testing 8O2 Mode...");
        data_bits   = 2'd0; // 8 bits
        stop_bits   = 2'd2; // 2 stop bits
        parity_en   = 1'b1; // Enable parity
        parity_type = 1'b1; // Odd parity
        send_byte(8'hAA);

        #2000;
        $display("Simulation Finished.");
        $finish;
    end

    // Monitor: Print key waveform changes
    initial begin
        $monitor("Time=%0t | rst=%b | txd=%b | busy=%b", $time, rst, txd, busy);
    end

endmodule