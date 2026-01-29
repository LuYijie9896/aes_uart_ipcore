`timescale 1ns / 1ps

/**
 * Simple Testbench for AES_UART
 * Performs sequential AXI-Lite register writes
 */

module tb_AES_UART_simple();

    // --- Clock and Reset ---
    logic Clk;
    logic Rst;

    // 50MHz Clock
    always #10 Clk = ~Clk;

    // --- Interface Instantiation ---
    taxi_axil_if #(.ADDR_W(32), .DATA_W(32)) axil_if();
    logic Rx;
    logic Tx;

    // --- Device Under Test (DUT) ---
    AES_UART dut (
        .Clk        (Clk),
        .Rst        (Rst),
        .wr_axil    (axil_if.wr_slv),
        .rd_axil    (axil_if.rd_slv),
        .Rx         (Rx),
        .Tx         (Tx)
    );

    // --- AXI-Lite Write Task ---
    task automatic axil_write(input [31:0] addr, input [31:0] data);
        @(posedge Clk);
        // Address channel
        axil_if.awaddr  = addr;
        axil_if.awprot  = 3'b000;
        axil_if.awvalid = 1'b1;
        // Data channel
        axil_if.wdata   = data;
        axil_if.wstrb   = 4'hF;
        axil_if.wvalid  = 1'b1;
        // Response channel
        axil_if.bready  = 1'b1;

        // Wait for handshake
        wait(axil_if.awready && axil_if.wready);
        @(posedge Clk);
        axil_if.awvalid = 1'b0;
        axil_if.wvalid  = 1'b0;

        // Wait for response
        wait(axil_if.bvalid);
        @(posedge Clk);
        axil_if.bready  = 1'b0;

        $display("[%0t] AXIL Write: Addr=0x%08h, Data=0x%08h", $time, addr, data);
    endtask

    // --- Test Stimulus ---
    initial begin
        // Initialization
        Clk = 0;
        Rst = 1;
        Rx  = 1;

        // Initialize AXI-Lite signals
        axil_if.awaddr  = '0;
        axil_if.awprot  = '0;
        axil_if.awvalid = 1'b0;
        axil_if.wdata   = '0;
        axil_if.wstrb   = '0;
        axil_if.wvalid  = 1'b0;
        axil_if.bready  = 1'b0;
        axil_if.araddr  = '0;
        axil_if.arprot  = '0;
        axil_if.arvalid = 1'b0;
        axil_if.rready  = 1'b0;

        // Wait for reset
        #100;
        Rst = 0;
        #50;

        $display("\n========================================");
        $display("  AES_UART Simple Testbench Started");
        $display("========================================\n");

        // Step 1: Clear register 0x00000000
        $display("--- Step 1: Clear CR1 register (0x00000000) ---");
        axil_write(32'h00000000, 32'h00000000);
        #100;

        // Step 2: Write 0x00000364 to register 0x00000008
        $display("--- Step 2: Write BRR register (0x00000008) ---");
        axil_write(32'h00000008, 32'h00000364);
        #100;

        // Step 3: Write 0x00000055 to register 0x00000018
        $display("--- Step 3: Write TDR register (0x00000018) ---");
        axil_write(32'h00000018, 32'h00000055);
        #100;

        // Step 4: Write 0x00000007 to register 0x00000000
        $display("--- Step 4: Enable CR1 register (0x00000000) ---");
        axil_write(32'h00000000, 32'h00000007);
        #100;

        $display("\n========================================");
        $display("  All register writes completed!");
        $display("  Waiting for UART TX to complete...");
        $display("========================================\n");

        // Wait long enough for UART transmission to complete
        // BRR=0x364=868, bit period = 868 clks * 10ns = 8.68us
        // 1 byte = 10 bits (start + 8 data + stop) = ~87us
        // Wait ~100us to see full TX waveform
        #100000;

        $display("\n========================================");
        $display("  Simulation finished!");
        $display("========================================\n");
    end

    // --- Waveform dump (for simulation) ---
    initial begin
        $dumpfile("tb_AES_UART_simple.vcd");
        $dumpvars(0, tb_AES_UART_simple);
    end

endmodule
