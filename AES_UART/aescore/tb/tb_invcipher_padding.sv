`timescale 1ns / 1ps

/*******************************************************************************
 * Testbench for InvAESCipher Zero-Padding Functionality
 * 
 * PURPOSE: Verify automatic zero-padding when IDLE signal is asserted
 * 
 * EXPECTED BEHAVIOR:
 * - When IDLE is asserted with 1-15 bytes received: Pad with zeros and decrypt
 * - When IDLE is asserted with 0 bytes: Ignore, no operation
 * - When 16 bytes received: Normal decryption without padding
 * 
 * TEST CASES:
 * 1. 5-byte data  → Should pad 11 zeros
 * 2. 1-byte data  → Should pad 15 zeros
 * 3. 15-byte data → Should pad 1 zero
 * 4. 16-byte data → No padding (normal operation)
 * 5. 0-byte + IDLE → Should ignore IDLE signal
 * 
 * HOW TO VERIFY:
 * - All tests should print "PASS"
 * - Check that DataInBuf is correctly padded with zeros
 * - Verify state transitions: INPUT → S0 after padding
 * 
 *******************************************************************************/

module tb_invcipher_padding();

    // ========================================================================
    // Clock and Reset
    // ========================================================================
    logic Clk;
    logic Rst;
    
    initial Clk = 0;
    always #5 Clk = ~Clk;  // 100 MHz clock
    
    // ========================================================================
    // DUT Signals
    // ========================================================================
    logic       En;
    logic       Idle;
    logic [1:0] KeyLen;
    logic [255:0] Key;
    logic       KeyUpdate;
    logic       KeyLenUpdate;
    
    // AXI-Stream interfaces
    logic [7:0]   s_axis_tdata;
    logic         s_axis_tvalid;
    logic         s_axis_tready;
    
    logic [127:0] m_axis_tdata;
    logic         m_axis_tvalid;
    logic         m_axis_tready;
    
    // Wrap AXI-Stream signals in interfaces
    taxi_axis_if #(.DATA_W(8)) s_axis_if();
    taxi_axis_if #(.DATA_W(128)) m_axis_if();
    
    assign s_axis_if.tdata = s_axis_tdata;
    assign s_axis_if.tvalid = s_axis_tvalid;
    assign s_axis_tready = s_axis_if.tready;
    
    assign m_axis_tdata = m_axis_if.tdata;
    assign m_axis_tvalid = m_axis_if.tvalid;
    assign m_axis_if.tready = m_axis_tready;
    
    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    InvAESCipher dut (
        .Clk(Clk),
        .Rst(Rst),
        .En(En),
        .Idle(Idle),
        .KeyLen(KeyLen),
        .Key(Key),
        .KeyUpdate(KeyUpdate),
        .KeyLenUpdate(KeyLenUpdate),
        .s_axis(s_axis_if.snk),
        .m_axis(m_axis_if.src)
    );
    
    // ========================================================================
    // Test Variables
    // ========================================================================
    integer test_num;
    integer pass_count;
    integer fail_count;
    
    // ========================================================================
    // Helper Task: Send N bytes via AXIS
    // ========================================================================
    task automatic send_bytes(input integer num_bytes, input logic [127:0] data);
        integer i;
        begin
            $display("  [INFO] Sending %0d bytes...", num_bytes);
            for (i = 0; i < num_bytes; i++) begin
                @(posedge Clk);
                s_axis_tdata = data[127 - (i*8) -: 8];
                s_axis_tvalid = 1'b1;
                wait(s_axis_tready);
                @(posedge Clk);
                s_axis_tvalid = 1'b0;
            end
        end
    endtask
    
    // ========================================================================
    // Helper Task: Wait for state to reach S0 or timeout
    // ========================================================================
    task automatic wait_for_decrypt();
        integer timeout;
        begin
            timeout = 0;
            while (dut.StateReg != 3'd3 && timeout < 100) begin  // S0 = 3'd3
                @(posedge Clk);
                timeout++;
            end
            if (timeout >= 100) begin
                $display("  [ERROR] Timeout waiting for decryption state!");
            end
        end
    endtask
    
    // ========================================================================
    // Helper Task: Check DataInBuf padding
    // ========================================================================
    task automatic check_padding(
        input integer valid_bytes,
        input logic [127:0] expected_data,
        input string test_name
    );
        logic [127:0] actual_data;
        logic test_pass;
        begin
            // Wait a bit for padding to complete
            repeat(5) @(posedge Clk);
            
            actual_data = dut.DataInBufReg;
            test_pass = (actual_data == expected_data);
            
            if (test_pass) begin
                $display("  [PASS] %s", test_name);
                $display("         Expected: 0x%032h", expected_data);
                $display("         Got:      0x%032h", actual_data);
                pass_count++;
            end else begin
                $display("  [FAIL] %s", test_name);
                $display("         Expected: 0x%032h", expected_data);
                $display("         Got:      0x%032h", actual_data);
                fail_count++;
            end
        end
    endtask
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    initial begin
        $display("\n");
        $display("========================================================================");
        $display("  InvAESCipher Zero-Padding Testbench");
        $display("========================================================================");
        $display("");
        
        // Initialize
        pass_count = 0;
        fail_count = 0;
        test_num = 0;
        
        Rst = 1;
        En = 0;
        Idle = 0;
        KeyLen = 2'b00;  // AES-128
        Key = 256'h000102030405060708090a0b0c0d0e0f_00000000000000000000000000000000;
        KeyUpdate = 0;
        KeyLenUpdate = 0;
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        m_axis_tready = 1;
        
        // Reset sequence
        repeat(10) @(posedge Clk);
        Rst = 0;
        repeat(5) @(posedge Clk);
        En = 1;
        repeat(5) @(posedge Clk);
        
        $display("[INFO] Initialization complete. Starting tests...\n");
        
        // ====================================================================
        // TEST 1: 5-byte data with padding
        // ====================================================================
        test_num = 1;
        $display("------------------------------------------------------------------------");
        $display("TEST %0d: Send 5 bytes, trigger IDLE, expect 11-byte zero padding", test_num);
        $display("------------------------------------------------------------------------");
        
        send_bytes(5, 128'h11223344_55000000_00000000_00000000);
        
        // Assert IDLE signal
        repeat(2) @(posedge Clk);
        Idle = 1;
        repeat(1) @(posedge Clk);
        Idle = 0;
        
        // Check padding
        check_padding(5, 128'h11223344_55000000_00000000_00000000, "5-byte padding test");
        
        // Wait for decryption to start
        wait_for_decrypt();
        
        // Reset module for next test
        Rst = 1;
        repeat(5) @(posedge Clk);
        Rst = 0;
        repeat(5) @(posedge Clk);
        
        // ====================================================================
        // TEST 2: 1-byte data with padding
        // ====================================================================
        test_num = 2;
        $display("\n------------------------------------------------------------------------");
        $display("TEST %0d: Send 1 byte, trigger IDLE, expect 15-byte zero padding", test_num);
        $display("------------------------------------------------------------------------");
        
        send_bytes(1, 128'hAA000000_00000000_00000000_00000000);
        
        repeat(2) @(posedge Clk);
        Idle = 1;
        repeat(1) @(posedge Clk);
        Idle = 0;
        
        check_padding(1, 128'hAA000000_00000000_00000000_00000000, "1-byte padding test");
        
        wait_for_decrypt();
        
        // Reset module for next test
        Rst = 1;
        repeat(5) @(posedge Clk);
        Rst = 0;
        repeat(5) @(posedge Clk);
        
        // ====================================================================
        // TEST 3: 15-byte data with padding
        // ====================================================================
        test_num = 3;
        $display("\n------------------------------------------------------------------------");
        $display("TEST %0d: Send 15 bytes, trigger IDLE, expect 1-byte zero padding", test_num);
        $display("------------------------------------------------------------------------");
        
        send_bytes(15, 128'h00112233_44556677_8899AABB_CCDDEEFF);
        
        repeat(2) @(posedge Clk);
        Idle = 1;
        repeat(1) @(posedge Clk);
        Idle = 0;
        
        check_padding(15, 128'h00112233_44556677_8899AABB_CCDDEE00, "15-byte padding test");
        
        wait_for_decrypt();
        
        // Reset module for next test
        Rst = 1;
        repeat(5) @(posedge Clk);
        Rst = 0;
        repeat(5) @(posedge Clk);
        
        // ====================================================================
        // TEST 4: 16-byte data without padding (normal operation)
        // ====================================================================
        test_num = 4;
        $display("\n------------------------------------------------------------------------");
        $display("TEST %0d: Send 16 bytes, no IDLE needed, normal operation", test_num);
        $display("------------------------------------------------------------------------");
        
        send_bytes(16, 128'hFEDCBA98_76543210_FEDCBA98_76543210);
        
        // No IDLE trigger - should proceed normally
        repeat(5) @(posedge Clk);
        
        if (dut.StateReg == 3'd3) begin  // Should be in S0 (decryption)
            $display("  [PASS] 16-byte normal operation - entered decryption state");
            pass_count++;
        end else begin
            $display("  [FAIL] 16-byte normal operation - did not enter decryption state");
            $display("         Current state: %0d", dut.StateReg);
            fail_count++;
        end
        
        // Reset module for next test
        Rst = 1;
        repeat(5) @(posedge Clk);
        Rst = 0;
        repeat(5) @(posedge Clk);
        
        // ====================================================================
        // TEST 5: IDLE with 0 bytes (should be ignored)
        // ====================================================================
        test_num = 5;
        $display("\n------------------------------------------------------------------------");
        $display("TEST %0d: Assert IDLE with 0 bytes received, should be ignored", test_num);
        $display("------------------------------------------------------------------------");
        
        // Don't send any data, just assert IDLE
        repeat(5) @(posedge Clk);
        Idle = 1;
        repeat(3) @(posedge Clk);
        Idle = 0;
        repeat(5) @(posedge Clk);
        
        // State should still be IDLE or INPUT, not S0
        if (dut.StateReg != 3'd3) begin  // Should NOT be in S0
            $display("  [PASS] IDLE with 0 bytes - correctly ignored");
            $display("         State remained: %0d (IDLE or INPUT)", dut.StateReg);
            pass_count++;
        end else begin
            $display("  [FAIL] IDLE with 0 bytes - spuriously triggered decryption!");
            fail_count++;
        end
        
        // ====================================================================
        // TEST SUMMARY
        // ====================================================================
        repeat(10) @(posedge Clk);
        
        $display("\n");
        $display("========================================================================");
        $display("  TEST SUMMARY");
        $display("========================================================================");
        $display("  Total Tests: %0d", test_num);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        $display("");
        
        if (fail_count == 0) begin
            $display("  ********************************************");
            $display("  *   ALL TESTS PASSED! ✓                    *");
            $display("  *   Zero-padding is working correctly!     *");
            $display("  ********************************************");
        end else begin
            $display("  ********************************************");
            $display("  *   SOME TESTS FAILED! ✗                   *");
            $display("  *   Please review the failures above.      *");
            $display("  ********************************************");
        end
        
        $display("");
        $display("========================================================================\n");
        
        $finish;
    end
    
    // ========================================================================
    // Timeout Watchdog
    // ========================================================================
    initial begin
        #100000;  // 100us timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
