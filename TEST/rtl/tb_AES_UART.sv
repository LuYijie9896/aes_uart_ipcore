`timescale 1ns / 1ps

/**
 * Testbench for AES_UART Top Level
 * Step 1: Basic functionality (Non-AES mode)
 */

module tb_AES_UART();

    // --- Clock and Reset ---
    logic Clk;
    logic Rst;

    always #5 Clk = ~Clk; // 100MHz

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

    // --- Register Address Definitions ---
    typedef enum logic [7:0] {
        ADDR_CR1  = 8'h00,
        ADDR_CR2  = 8'h04,
        ADDR_BRR  = 8'h08,
        ADDR_ISR  = 8'h0C,
        ADDR_ICR  = 8'h10,
        ADDR_RDR  = 8'h14,
        ADDR_TDR  = 8'h18,
        ADDR_EKR1 = 8'h1C, ADDR_EKR2 = 8'h20, ADDR_EKR3 = 8'h24, ADDR_EKR4 = 8'h28,
        ADDR_EKR5 = 8'h2C, ADDR_EKR6 = 8'h30, ADDR_EKR7 = 8'h34, ADDR_EKR8 = 8'h38,
        ADDR_DKR1 = 8'h3C, ADDR_DKR2 = 8'h40, ADDR_DKR3 = 8'h44, ADDR_DKR4 = 8'h48,
        ADDR_DKR5 = 8'h4C, ADDR_DKR6 = 8'h50, ADDR_DKR7 = 8'h54, ADDR_DKR8 = 8'h58,
        ADDR_EPR1 = 8'h5C, ADDR_EPR2 = 8'h60, ADDR_EPR3 = 8'h64, ADDR_EPR4 = 8'h68,
        ADDR_DPR1 = 8'h6C, ADDR_DPR2 = 8'h70, ADDR_DPR3 = 8'h74, ADDR_DPR4 = 8'h78
    } reg_addr_t;

    // --- AXI-Lite Driver Tasks ---
    task automatic axil_write(input [31:0] addr, input [31:0] data);
        @(posedge Clk);
        axil_if.awaddr  = addr;
        axil_if.awvalid = 1'b1;
        axil_if.wdata   = data;
        axil_if.wstrb   = 4'hf;
        axil_if.wvalid  = 1'b1;
        axil_if.bready  = 1'b1;

        wait(axil_if.awready && axil_if.wready);
        @(posedge Clk);
        axil_if.awvalid = 1'b0;
        axil_if.wvalid  = 1'b0;
        wait(axil_if.bvalid);
        @(posedge Clk);
        axil_if.bready  = 1'b0;
        $display("[AXIL Write] Addr: 0x%h, Data: 0x%h", addr, data);
    endtask

    task automatic axil_read(input [31:0] addr, output [31:0] data);
        @(posedge Clk);
        axil_if.araddr  = addr;
        axil_if.arvalid = 1'b1;
        axil_if.rready  = 1'b1;

        wait(axil_if.arready);
        @(posedge Clk);
        axil_if.arvalid = 1'b0;
        wait(axil_if.rvalid);
        data = axil_if.rdata;
        @(posedge Clk);
        axil_if.rready  = 1'b0;
        $display("[AXIL Read] Addr: 0x%h, Data: 0x%h", addr, data);
    endtask

    // --- UART Helper Task ---
    task automatic uart_send_byte(input [7:0] data, input [15:0] prescale);
        int bit_clks;
        bit_clks = prescale; 
        // Start bit
        Rx = 1'b0;
        repeat(bit_clks) @(posedge Clk);
        // Data bits
        for (int i=0; i<8; i++) begin
            Rx = data[i];
            repeat(bit_clks) @(posedge Clk);
        end
        // Stop bit
        Rx = 1'b1;
        repeat(bit_clks) @(posedge Clk);
        $display("[UART Inject] Byte: 0x%h", data);
    endtask

    // --- Test Stimulus ---
    initial begin
        logic [31:0] isr_val;
        logic [31:0] rdr_val;

        // Initialization
        Clk = 0;
        Rst = 1;
        Rx  = 1;
        axil_if.awvalid = 0;
        axil_if.wvalid  = 0;
        axil_if.arvalid = 0;
        axil_if.rready  = 0;
        axil_if.bready  = 0;

        #100 Rst = 0;
        #50;

        $display("\n--- Step 1: Base Config and Enable ---");
        // BRR: 115200 baud @ 100MHz (8x oversampling)
        // Prescale = 100MHz / (115200 * 8) = 108.5069...
        // Integer part: 108 (0x06C), Fractional: 0.5069 * 16 = 8.11 (0x8)
        // BRR = {12'h06C, 4'h8} = 0x06C8
        axil_write(ADDR_BRR, 32'h0000_06C8); 
        
        // CR1: aue=1, re=1, te=1
        axil_write(ADDR_CR1, 32'h0000_0007); 

        // Check ISR for TXE flag (bit 6)
        axil_read(ADDR_ISR, isr_val);
        if (isr_val[6]) $display("PASS: TXE flag set correctly");
        else            $display("FAIL: TXE flag NOT set");

        $display("\n--- Step 2: UART Transmission (Bypass Mode) ---");
        // Write 0xA5 to TDR
        axil_write(ADDR_TDR, 32'hA5);
        
        // Wait for serial shift out (10 bits * 868 clks = 8680 clks)
        repeat(9000) @(posedge Clk); 

        $display("\n--- Step 3: UART Reception (Bypass Mode) ---");
        // Send 0x5A to Rx pin
        // Bit period = 868 clks
        uart_send_byte(8'h5A, 868);
        
        // Wait for processing
        repeat(100) @(posedge Clk);

        // Check ISR for RXNE flag (bit 4)
        axil_read(ADDR_ISR, isr_val);
        if (isr_val[4]) $display("PASS: RXNE flag set correctly");
        
        // Read from RDR
        axil_read(ADDR_RDR, rdr_val);
        if (rdr_val[7:0] == 8'h5A) $display("PASS: RDR Data correct: 0x5A");
        else                       $display("FAIL: RDR Data mismatch: 0x%h", rdr_val[7:0]);

        #500;
        $display("\nPhase 1 verification complete.");

        $display("\n--- Step 4: AES Encryption (EPR -> UART TX) ---");
        // 1. Set AES Key (128-bit: 00010203 04050607 08090a0b 0c0d0e0f)
        // Note: ADDR_EKR1 is LSB group (bits 31:0), EKR4 is MSB group (bits 127:96)
        axil_write(ADDR_EKR1, 32'h0c0d0e0f);
        axil_write(ADDR_EKR2, 32'h08090a0b);
        axil_write(ADDR_EKR3, 32'h04050607);
        axil_write(ADDR_EKR4, 32'h00010203);

        // 2. Enable AES Encryption (EE=1, TE=1, AUE=1)
        axil_write(ADDR_CR1, 32'h0000_0017); 

        // 3. Write Plaintext to EPR (Wait for TXE between blocks if needed, but EPR is 128-bit)
        // Plaintext: 00112233 44556677 8899aabb ccddeeff
        axil_write(ADDR_EPR1, 32'hccddeeff);
        axil_write(ADDR_EPR2, 32'h8899aabb);
        axil_write(ADDR_EPR3, 32'h44556677);
        axil_write(ADDR_EPR4, 32'h00112233);

        // 4. Wait for UART TX to finish (16 bytes * 10 bits * 868 clks = ~138,000 clks)
        $display("Wait for encrypted transmission...");
        repeat(150000) @(posedge Clk);

        $display("\n--- Step 5: Loopback Mode (TX -> RX) ---");
        // Enable Loopback (WM=1), EE=0 (Bypass AES), TE=1, RE=1, AUE=1
        axil_write(ADDR_CR1, 32'h0000_8007); 
        
        // Write 0x33 to TDR
        axil_write(ADDR_TDR, 32'h33);
        
        // Wait for loopback bit cycles (10 bits * 868 = 8680 clks)
        repeat(10000) @(posedge Clk);

        // Check ISR for RXNE
        axil_read(ADDR_ISR, isr_val);
        if (isr_val[4]) $display("PASS: Loopback RXNE flag set");
        
        axil_read(ADDR_RDR, rdr_val);
        if (rdr_val[7:0] == 8'h33) $display("PASS: Loopback Data correct: 0x33");
        else                       $display("FAIL: Loopback Data mismatch: 0x%h", rdr_val[7:0]);

        #2000;
        $display("\n--- Step 6: Full AES Path (Encrypt -> UART Loop -> Decrypt) ---");
        // Goal: EPR -> AES -> UART -> (Loop) -> UART -> InvAES -> DPR
        // 1. Set Encryption Key and Decryption Key (Both same for AES)
        // Key: 00010203 04050607 08090a0b 0c0d0e0f
        axil_write(ADDR_EKR1, 32'h0c0d0e0f);
        axil_write(ADDR_EKR2, 32'h08090a0b);
        axil_write(ADDR_EKR3, 32'h04050607);
        axil_write(ADDR_EKR4, 32'h00010203);

        axil_write(ADDR_DKR1, 32'h0c0d0e0f);
        axil_write(ADDR_DKR2, 32'h08090a0b);
        axil_write(ADDR_DKR3, 32'h04050607);
        axil_write(ADDR_DKR4, 32'h00010203);

        // 2. Configure CR1: WM=1, EE=1, DE=1, TE=1, RE=1, AUE=1
        // CR1 = 32'h0000_801F
        axil_write(ADDR_CR1, 32'h0000_801F); 

        // 3. Write Plaintext to EPR
        $display("[AES-Full] Writing Plaintext to EPR: 0x00112233445566778899aabbccddeeff");
        axil_write(ADDR_EPR1, 32'hccddeeff);
        axil_write(ADDR_EPR2, 32'h8899aabb);
        axil_write(ADDR_EPR3, 32'h44556677);
        axil_write(ADDR_EPR4, 32'h00112233);

        // 4. Wait for decryption completion (DRNE flag in ISR bit 7)
        // Time = 16 bytes * UART transmission time + InvAES processing
        $display("[AES-Full] Waiting for DRNE (Decryption Ready)...");
        isr_val = 0;
        while (!isr_val[7]) begin // ISR[7] is DRNE
            axil_read(ADDR_ISR, isr_val);
            repeat(1000) @(posedge Clk);
        end
        $display("[AES-Full] DRNE flag set! Reading decrypted data from DPR...");

        // 5. Read from DPR and verify
        axil_read(ADDR_DPR1, rdr_val);
        $display("[AES-Full] DPR1: 0x%h (Expected: 0xccddeeff)", rdr_val);
        axil_read(ADDR_DPR2, rdr_val);
        $display("[AES-Full] DPR2: 0x%h (Expected: 0x8899aabb)", rdr_val);
        axil_read(ADDR_DPR3, rdr_val);
        $display("[AES-Full] DPR3: 0x%h (Expected: 0x44556677)", rdr_val);
        axil_read(ADDR_DPR4, rdr_val);
        $display("[AES-Full] DPR4: 0x%h (Expected: 0x00112233)", rdr_val);

        #2000;
        $display("\nAll Phases verification complete.");
        $finish;
    end

endmodule
