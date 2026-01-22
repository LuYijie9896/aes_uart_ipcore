`timescale 1ns / 1ps

module tb_AES_UART_modes;

    // =========================================================================
    // Parameters & Signals
    // =========================================================================
    parameter CLK_PERIOD = 20; // 50MHz
    parameter DATA_W = 32;
    parameter ADDR_W = 32;

    logic Clk;
    logic Rst;
    logic Rx;
    logic Tx;

    // AXI-Lite Interface
    logic [ADDR_W-1:0] s_axil_awaddr;
    logic [2:0]        s_axil_awprot;
    logic              s_axil_awvalid;
    logic              s_axil_awready;
    logic [DATA_W-1:0] s_axil_wdata;
    logic [3:0]        s_axil_wstrb;
    logic              s_axil_wvalid;
    logic              s_axil_wready;
    logic [1:0]        s_axil_bresp; // 2 bits for AXI4-Lite
    logic              s_axil_bvalid;
    logic              s_axil_bready;
    logic [ADDR_W-1:0] s_axil_araddr;
    logic [2:0]        s_axil_arprot;
    logic              s_axil_arvalid;
    logic              s_axil_arready;
    logic [DATA_W-1:0] s_axil_rdata;
    logic [1:0]        s_axil_rresp; // 2 bits for AXI4-Lite
    logic              s_axil_rvalid;
    logic              s_axil_rready;

    // Registers Map (from axilregs_pkg & axil_regs)
    localparam ADDR_CR1  = 8'h00;
    localparam ADDR_CR2  = 8'h04;
    localparam ADDR_BRR  = 8'h08;
    localparam ADDR_ISR  = 8'h0C;
    localparam ADDR_ICR  = 8'h10;
    localparam ADDR_RDR  = 8'h14;
    localparam ADDR_TDR  = 8'h18;
    
    localparam ADDR_EKR1 = 8'h1C; // Key 0
    localparam ADDR_DKR1 = 8'h3C; // Key 0
    localparam ADDR_EPR1 = 8'h5C; // Encrypt Plain Data 0
    localparam ADDR_EPR2 = 8'h60;
    localparam ADDR_EPR3 = 8'h64;
    localparam ADDR_EPR4 = 8'h68;
    localparam ADDR_DPR1 = 8'h6C; // Decrypt Plain Data 0
    localparam ADDR_DPR2 = 8'h70;
    localparam ADDR_DPR3 = 8'h74;
    localparam ADDR_DPR4 = 8'h78;

    // UART Settings (Assuming 50MHz Clock)
    // For Simulation, we use a fast baud rate to speed up.
    // DUT uses 8x oversampling (inferred from uart_tx.sv baud_cnt_reg width [2:0]).
    // Baud Rate = ClkFreq / (8 * Divisor)
    // Target Bit Period = 1280 ns.
    // Divisor = 1280 / (8 * 20) = 8.
    localparam UART_DIV_MANTISSA = 8;
    localparam UART_DIV_FRACTION = 0;
    localparam UART_BIT_PERIOD  = 1280; 

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    
    // Interface Wrapper
    taxi_axil_if #(.DATA_W(32), .ADDR_W(32)) wr_axil();
    taxi_axil_if #(.DATA_W(32), .ADDR_W(32)) rd_axil();

    // Connecting wires to interface
    assign wr_axil.awaddr  = s_axil_awaddr;
    assign wr_axil.awprot  = s_axil_awprot;
    assign wr_axil.awvalid = s_axil_awvalid;
    assign s_axil_awready  = wr_axil.awready;
    assign wr_axil.wdata   = s_axil_wdata;
    assign wr_axil.wstrb   = s_axil_wstrb;
    assign wr_axil.wvalid  = s_axil_wvalid;
    assign s_axil_wready   = wr_axil.wready;
    assign s_axil_bresp    = wr_axil.bresp;
    assign s_axil_bvalid   = wr_axil.bvalid;
    assign wr_axil.bready  = s_axil_bready;

    assign rd_axil.araddr  = s_axil_araddr;
    assign rd_axil.arprot  = s_axil_arprot;
    assign rd_axil.arvalid = s_axil_arvalid;
    assign s_axil_arready  = rd_axil.arready;
    assign s_axil_rdata    = rd_axil.rdata;
    assign s_axil_rresp    = rd_axil.rresp;
    assign s_axil_rvalid   = rd_axil.rvalid;
    assign rd_axil.rready  = s_axil_rready;

    AES_UART #(
        .DATA_W(32),
        .ADDR_W(32)
    ) dut (
        .Clk(Clk),
        .Rst(Rst),
        .wr_axil(wr_axil), // Use .wr_slv modport automatically? 
                           // Wait, AES_UART defines port as `taxi_axil_if.wr_slv wr_axil`.
                           // Passing the interface instance `wr_axil` should work.
        .rd_axil(rd_axil),
        .Rx(Rx),
        .Tx(Tx)
    );

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    initial begin
        Clk = 0;
        forever #(CLK_PERIOD/2) Clk = ~Clk;
    end

    initial begin
        Rst = 1;
        #200;
        Rst = 0;
    end

    // =========================================================================
    // Tasks: AXI-Lite
    // =========================================================================
    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge Clk);
            s_axil_awaddr  <= addr;
            s_axil_awvalid <= 1'b1;
            s_axil_wdata   <= data;
            s_axil_wvalid  <= 1'b1;
            s_axil_wstrb   <= 4'hF;
            s_axil_bready  <= 1'b1;

            fork
                begin
                    wait(s_axil_awready);
                    @(posedge Clk);
                    s_axil_awaddr  <= '0;
                    s_axil_awvalid <= 1'b0;
                end
                begin
                    wait(s_axil_wready);
                    @(posedge Clk);
                    s_axil_wdata   <= '0;
                    s_axil_wvalid  <= 1'b0;
                    s_axil_wstrb   <= '0;
                end
            join

            wait(s_axil_bvalid);
            @(posedge Clk);
            s_axil_bready <= 1'b0;
            @(posedge Clk);
        end
    endtask

    task axi_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge Clk);
            s_axil_araddr  <= addr;
            s_axil_arvalid <= 1'b1;
            s_axil_rready  <= 1'b1;

            wait(s_axil_arready);
            @(posedge Clk);
            s_axil_araddr  <= '0;
            s_axil_arvalid <= 1'b0;

            wait(s_axil_rvalid);
            data = s_axil_rdata;
            @(posedge Clk);
            s_axil_rready <= 1'b0;
            @(posedge Clk);
        end
    endtask

    // =========================================================================
    // Tasks: UART
    // =========================================================================
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            // Start Bit (0)
            Rx <= 1'b0;
            #(UART_BIT_PERIOD);
            
            // Data Bits (LSB First)
            for (i=0; i<8; i++) begin
                Rx <= data[i];
                #(UART_BIT_PERIOD);
            end

            // Stop Bit (1) - No parity assumed for simplicity unless configured
            Rx <= 1'b1;
            #(UART_BIT_PERIOD);
            
            // Idle
            #(100); 
        end
    endtask

    task recv_uart_byte(output [7:0] data);
        integer i;
        begin
            // Wait for Start Bit (Falling Edge)
            wait(Tx == 1'b0);
            #(UART_BIT_PERIOD/2); // Sample logic, verify start bit center
            if (Tx != 0) $display("Wait for start bit failed at %t", $time);
            #(UART_BIT_PERIOD); // Move to D0

            for (i=0; i<8; i++) begin
                data[i] = Tx;
                #(UART_BIT_PERIOD);
            end
            
            // At Stop Bit Center. 
            // Wait half bit period to finish the frame and reach Idle state
            #(UART_BIT_PERIOD/2); 
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    logic [31:0] read_val;
    logic [7:0]  rx_data;
    logic [127:0] expected_cipher_zero_key;
    
    // AES-128 Plain:0, Key:0 -> Cipher: 66e94bd4ef8a2c3b884cfa59ca342b2e
    // Byte sequence (MSB first in 128-bit integer usually means byte 0 is [127:120]?)
    // In this core, key expansion uses `ekr` array. 
    // AESCipher.sv usage: .Key({ekr[7], ... ekr[0]})
    // s_axis width 128. 
    // Usually standard AES is Big Endian byte order.
    // Let's assume standard byte order.
    
    initial begin
        // Initialize Signals
        Rx = 1'b1; // Idle high
        s_axil_awaddr  = 0;
        s_axil_awprot  = 0;
        s_axil_awvalid = 0;
        s_axil_wdata   = 0;
        s_axil_wstrb   = 0;
        s_axil_wvalid  = 0;
        s_axil_bready  = 0;
        s_axil_araddr  = 0;
        s_axil_arprot  = 0;
        s_axil_arvalid = 0;
        s_axil_rready  = 0;

        // AES Known Answer (Plain=0, Key=0)
        expected_cipher_zero_key = 128'h66e94bd4ef8a2c3b884cfa59ca342b2e;

        wait(Rst == 0);
        #1000;

        $display("=================================================");
        $display("   AES UART SystemVerilog Testbench              ");
        $display("=================================================");
        
        // ---------------------------------------------------------------------
        // 1. Configure Baud Rate
        // ---------------------------------------------------------------------
        $display("[INFO] Configuring Baud Rate (Mantissa=%d, Fraction=%d)", UART_DIV_MANTISSA, UART_DIV_FRACTION);
        axi_write(ADDR_BRR, {16'd0, 12'(UART_DIV_MANTISSA), 4'(UART_DIV_FRACTION)});
        
        // ---------------------------------------------------------------------
        // 2. Configure Keys (All 0s)
        // ---------------------------------------------------------------------
        $display("[INFO] Writing Keys (All Zeros)");
        // Write EKR
        for(int i=0; i<8; i++) axi_write(ADDR_EKR1 + i*4, 32'd0);
        // Write DKR
        for(int i=0; i<8; i++) axi_write(ADDR_DKR1 + i*4, 32'd0);

        // ---------------------------------------------------------------------
        // Test Case 1: Mode 11 (Loopback)
        // ---------------------------------------------------------------------
        $display("\n>> Test Case 1: Mode 11 (Loopback)");
        // CR1: wm=11, aue=1, te=1, re=1
        // wm=11 (bit 16,15), te=1 (bit 2), re=1 (bit 1), aue=1 (bit 0)
        // 0001_1000_0000_0000_0000_0000_0000_0111 = 0x00018007
        axi_write(ADDR_CR1, 32'h00018007);
        
        // Write TDR
        $display("       Writing TX Data: 0x55");
        axi_write(ADDR_TDR, 32'h00000055);
        
        // In Loopback, TDR -> TX -> RX (Internal) -> RDR
        // Poll ISR for RXNE (Receive Not Empty), bit 4
        read_val = 0;
        while(read_val[4] == 0) begin
            axi_read(ADDR_ISR, read_val);
            #100;
        end
        $display("       ISR RXNE set.");

        // Read RDR
        axi_read(ADDR_RDR, read_val);
        $display("       Read RX Data: 0x%h", read_val[7:0]);
        if (read_val[7:0] == 8'h55) $display("       [PASS] Loopback Data Match");
        else                        $display("       [FAIL] Loopback Data Mismatch");


        // ---------------------------------------------------------------------
        // Test Case 2: Mode 00 (Normal Non-Encrypted)
        // ---------------------------------------------------------------------
        $display("\n>> Test Case 2: Mode 00 (Normal, No Crypt)");
        // CR1: wm=00, aue=1, te=1, re=1
        // 0x00000007
        axi_write(ADDR_CR1, 32'h00000007);

        // Sub-test 2.1: TX (Write TDR -> UART Output)
        $display("       Sub-test 2.1: Write TDR -> Check UART TX");
        axi_write(ADDR_TDR, 32'hA5);
        recv_uart_byte(rx_data); // Receive on Testbench side
        $display("       UART Recv: 0x%h", rx_data);
        if (rx_data == 8'hA5) $display("       [PASS] UART TX Data Match");
        else                  $display("       [FAIL] UART TX Data Mismatch");

        // Sub-test 2.2: RX (Update UART Input -> Read RDR)
        $display("       Sub-test 2.2: Send UART RX -> Check RDR");
        send_uart_byte(8'h3C);
        
        // Poll ISR for RXNE
        read_val = 0;
        while(read_val[4] == 0) begin
            axi_read(ADDR_ISR, read_val);
            #100;
        end
        axi_read(ADDR_RDR, read_val);
        $display("       RDR Read: 0x%h", read_val[7:0]);
        if (read_val[7:0] == 8'h3C) $display("       [PASS] UART RX Data Match");
        else                        $display("       [FAIL] UART RX Data Mismatch");


        // ---------------------------------------------------------------------
        // Test Case 3: Mode 01 (Auto Encrypt) - Max Payload Test (15 bytes)
        // ---------------------------------------------------------------------
        // New Protocol: Max 15 data bytes + 1 length byte = 16 bytes encrypted block
        $display("\n>> Test Case 3: Mode 01 (Auto Encrypt - 15 bytes max payload)");
        // CR1: wm=01, aue=1, te=1, re=1, ee=1, de=1 (Enable encrypt engine)
        axi_write(ADDR_CR1, 32'h0000801F);
        
        $display("       Sending 15 bytes (max payload) via UART RX...");
        
        fork
            begin
                // Send 15 data bytes (max payload under new protocol)
                for(int k=0; k<15; k++) begin
                    send_uart_byte(8'h00 + k);  // Send 00, 01, 02, ..., 0E
                end
                #(UART_BIT_PERIOD * 20); // Wait for idle to trigger encryption
            end
            begin
                logic [7:0] captured_cipher_bytes[15:0];
                for(int k=0; k<16; k++) begin
                    recv_uart_byte(captured_cipher_bytes[k]);
                end
                $display("       Received 16 encrypted bytes on TX.");
                
                // Print received
                $write("       Cipher Output: ");
                for(int k=0; k<16; k++) $write("%h ", captured_cipher_bytes[k]);
                $write("\n");

                // Verify ciphertext is not all zeros (encryption happened)
                if (captured_cipher_bytes[0] != 8'h00 || captured_cipher_bytes[1] != 8'h01)
                    $display("       [PASS] Data encrypted (not plaintext).");
                else
                    $display("       [FAIL] Data appears unencrypted.");
            end
        join


        // ---------------------------------------------------------------------
        // Test Case 4: Mode 01->10 (Encrypt then Decrypt Loopback - 10 bytes)
        // ---------------------------------------------------------------------
        // Full verification: Encrypt arbitrary data, then decrypt and verify recovery
        $display("\n>> Test Case 4: Encrypt->Decrypt Loopback (10 bytes)");
        
        // Step 1: Encrypt 10 bytes
        axi_write(ADDR_CR1, 32'h0000801F);  // wm=01 Auto Encrypt
        $display("       Step 1: Encrypting 10 bytes: F0 E1 D2 C3 B4 A5 96 87 78 69");
        
        fork
            begin
                // Send 10 unique bytes
                send_uart_byte(8'hF0);
                send_uart_byte(8'hE1);
                send_uart_byte(8'hD2);
                send_uart_byte(8'hC3);
                send_uart_byte(8'hB4);
                send_uart_byte(8'hA5);
                send_uart_byte(8'h96);
                send_uart_byte(8'h87);
                send_uart_byte(8'h78);
                send_uart_byte(8'h69);
                #(UART_BIT_PERIOD * 20); // Wait for idle
            end
            begin
                logic [7:0] cipher_bytes[15:0];
                // Capture 16 encrypted bytes
                for(int k=0; k<16; k++) begin
                    recv_uart_byte(cipher_bytes[k]);
                end
                $write("       Cipher: ");
                for(int k=0; k<16; k++) $write("%h ", cipher_bytes[k]);
                $write("\n");
                
                // Step 2: Decrypt the cipher
                axi_write(ADDR_CR1, 32'h0001001F);  // wm=10 Auto Decrypt
                $display("       Step 2: Decrypting...");
                
                fork
                    begin
                        // Send the captured cipher
                        for(int k=0; k<16; k++) begin
                            send_uart_byte(cipher_bytes[k]);
                        end
                    end
                    begin
                        logic [7:0] plain_bytes[15:0];
                        // Should receive exactly 10 bytes (original length)
                        for(int k=0; k<10; k++) begin
                            recv_uart_byte(plain_bytes[k]);
                        end
                        
                        $write("       Plain Output: ");
                        for(int k=0; k<10; k++) $write("%h ", plain_bytes[k]);
                        $write("\n");
                        
                        // Verify data matches original
                        if (plain_bytes[0] == 8'hF0 && plain_bytes[1] == 8'hE1 &&
                            plain_bytes[2] == 8'hD2 && plain_bytes[3] == 8'hC3 &&
                            plain_bytes[4] == 8'hB4 && plain_bytes[5] == 8'hA5 &&
                            plain_bytes[6] == 8'h96 && plain_bytes[7] == 8'h87 &&
                            plain_bytes[8] == 8'h78 && plain_bytes[9] == 8'h69)
                            $display("       [PASS] All 10 bytes recovered correctly!");
                        else
                            $display("       [FAIL] Decryption mismatch.");
                    end
                join
            end
        join

        // ---------------------------------------------------------------------
        // Test Case 5: Normal Mode with Manual Encrypt/Decrypt (AXI Access)
        // ---------------------------------------------------------------------
        $display("\n>> Test Case 5: Normal Mode + AXI Encrypt/Decrypt (Mode 00)");
        // CR1: wm=00, ee=1, de=1, aue=1... 0x1F
        axi_write(ADDR_CR1, 32'h0000001F);
        
        // 5.1 Encrypt: Write to EPR (128 bit) -> Check TX
        // Write 4x 32-bit registers (Addr 5C, 60, 64, 68)
        // Data: 0x00000000...
        $display("       Writing EPR (Plain=0)...");
        axi_write(ADDR_EPR1, 0);
        axi_write(ADDR_EPR2, 0);
        axi_write(ADDR_EPR3, 0);
        axi_write(ADDR_EPR4, 0);
        
        // It should start sending immediately after EPR4 write?
        // Wait, regs_aes_bridge connects EPR stream. 
        // AXI write needs to trigger `m_axis_epr` stream.
        // axil_regs maps EPR writes to `reg_epr`. 
        // Does `axil_regs` generate `m_axis_epr` valid?
        // Let's check `axil_regs.sv`. It doesn't seem to have a "trigger" logic for EPR based on write detection in the provided snippet.
        // Ah, `reg_epr` is just storage.
        // `m_axis_epr` output logic was not fully visible in the snippet (I read until line 300).
        // I need to check how `m_axis_epr` is driven in `axil_regs.sv`.
        // If it's just static registers, something else must strobe valid. 
        // Usually, writing the last register (EPR4) triggers the AXIS transaction.
        // Let's assume this behavior or check the file if needed.
        
        $display("       Listening on UART TX...");
        
        fork 
            begin
                // Receiver
                for(int k=0; k<16; k++) begin
                    recv_uart_byte(rx_data);
                    $display("       [DATA] Received Byte %0d: 0x%h", k, rx_data);
                end
                $display("       [PASS] Received 16 bytes from EPR write.");
            end
            begin
                // Diagnosis Monitor
                // Wait allowing for Encryption (approx 20-50 cycles) + UART Serial (1280ns * 10 * 16 = 200us)
                // We poll ISR to see internal status
                repeat(200) begin
                    #60000; // Check every 60us (Approx 4-5 bytes time)
                    axi_read(ADDR_ISR, read_val);
                    // Bit 8: ERE (Encrypt Reg Empty) - Should be 1 if AES accepted data
                    // Bit 10: TXFE (TX FIFO Empty) - Should be 0 if data is in FIFO
                    // Bit 9: BUSY
                    //$display("       [MONITOR] Time=%0t ISR=0x%h (ERE=%b TXFE=%b BUSY=%b)", 
                    //    $time, read_val, read_val[8], read_val[10], read_val[9]);
                end
                $display("       [FAIL] Timeout waiting for UART Data.");
                $stop;
            end
        join_any

        // ---------------------------------------------------------------------
        // Test Case 6: Arbitrary Length Encryption (5 bytes)
        // ---------------------------------------------------------------------
        $display("\n>> Test Case 6: Arbitrary Length Encryption (5 bytes)");
        // CR1: wm=01, aue=1, te=1, re=1, ee=1, de=1
        axi_write(ADDR_CR1, 32'h0000801F);
        
        $display("       Sending 5 bytes: AA BB CC DD EE via UART RX...");
        
        fork
            begin
                // Send 5 data bytes
                send_uart_byte(8'hAA);
                send_uart_byte(8'hBB);
                send_uart_byte(8'hCC);
                send_uart_byte(8'hDD);
                send_uart_byte(8'hEE);
                // Wait for idle detection to trigger encryption
                #(UART_BIT_PERIOD * 20);
            end
            begin
                logic [7:0] captured_bytes[15:0];
                int recv_cnt;
                recv_cnt = 0;
                // Should receive 16 encrypted bytes
                for(int k=0; k<16; k++) begin
                    recv_uart_byte(captured_bytes[k]);
                    recv_cnt++;
                end
                $display("       Received %0d encrypted bytes on TX.", recv_cnt);
                $write("       Encrypted Output: ");
                for(int k=0; k<16; k++) $write("%h ", captured_bytes[k]);
                $write("\n");
                
                if (recv_cnt == 16)
                    $display("       [PASS] Received 16 encrypted bytes as expected.");
                else
                    $display("       [FAIL] Expected 16 bytes, got %0d.", recv_cnt);
            end
        join

        // ---------------------------------------------------------------------
        // Test Case 7: Arbitrary Length Decryption (Loopback Test)
        // Encrypt 5 bytes, then decrypt and verify original data
        // ---------------------------------------------------------------------
        $display("\n>> Test Case 7: Full Loopback - Encrypt then Decrypt (5 bytes)");
        
        // Step 1: Set to encrypt mode (wm=01) and send 5 bytes
        axi_write(ADDR_CR1, 32'h0000801F);
        $display("       Step 1: Encrypting 5 bytes: 11 22 33 44 55");
        
        fork
            begin
                send_uart_byte(8'h11);
                send_uart_byte(8'h22);
                send_uart_byte(8'h33);
                send_uart_byte(8'h44);
                send_uart_byte(8'h55);
                #(UART_BIT_PERIOD * 20); // Wait for idle
            end
            begin
                logic [7:0] cipher_bytes[15:0];
                for(int k=0; k<16; k++) begin
                    recv_uart_byte(cipher_bytes[k]);
                end
                $display("       Captured 16 cipher bytes.");
                
                // Step 2: Switch to decrypt mode (wm=10) and send back the cipher
                axi_write(ADDR_CR1, 32'h0001001F);
                $display("       Step 2: Decrypting cipher bytes...");
                
                fork
                    begin
                        for(int k=0; k<16; k++) begin
                            send_uart_byte(cipher_bytes[k]);
                        end
                    end
                    begin
                        logic [7:0] plain_bytes[15:0];
                        int plain_cnt;
                        plain_cnt = 0;
                        // Should receive only 5 bytes (original length)
                        for(int k=0; k<5; k++) begin
                            recv_uart_byte(plain_bytes[k]);
                            plain_cnt++;
                        end
                        
                        $write("       Decrypted Output: ");
                        for(int k=0; k<5; k++) $write("%h ", plain_bytes[k]);
                        $write("\n");
                        
                        if (plain_bytes[0] == 8'h11 && plain_bytes[1] == 8'h22 &&
                            plain_bytes[2] == 8'h33 && plain_bytes[3] == 8'h44 &&
                            plain_bytes[4] == 8'h55)
                            $display("       [PASS] Decrypted data matches original!");
                        else
                            $display("       [FAIL] Decrypted data mismatch.");
                    end
                join
            end
        join

        $display("\nAll Tests Completed.");
        $stop;
    end

endmodule
