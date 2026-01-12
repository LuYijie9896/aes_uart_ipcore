`timescale 1ns/1ns

// Testbench for InvAESCipher (Decryption)
// Verifies AES-128, AES-192, and AES-256 decryption functionality
// Measures latency for both fresh key updates and cached key operations
// Reference structure from tb_AESCipher.sv

module tb_InvAESCipher();

    //--------------------------------------------------------------------------
    // Signal Declarations
    //--------------------------------------------------------------------------
    logic          Clk;
    logic          Rst;
    logic          En;
    logic  [1:0]   KeyLen;    // 00:128, 01:192, 10:256
    logic  [255:0] Key;
    logic          KeyUpdate;
    logic          KeyLenUpdate;
    
    // Interface Setup
    // Decryption Input:  8-bit stream (Ciphertext bytes)
    // Decryption Output: 128-bit block (Plaintext result)
    taxi_axis_if #(.DATA_W(8))   axis_in ();  
    taxi_axis_if #(.DATA_W(128)) axis_out (); 

    //--------------------------------------------------------------------------
    // DUT Instantiation
    //--------------------------------------------------------------------------
    InvAESCipher UUT(
        .Clk(Clk),
        .Rst(Rst),
        .En(En),
        .KeyLen(KeyLen),
        .Key(Key),
        .KeyUpdate(KeyUpdate),
        .KeyLenUpdate(KeyLenUpdate),
        .s_axis(axis_in.snk),
        .m_axis(axis_out.src)
    );

    //--------------------------------------------------------------------------
    // Clock Generation (100MHz)
    //--------------------------------------------------------------------------
    always #5 Clk = ~Clk;

    //--------------------------------------------------------------------------
    // Test Procedure
    //--------------------------------------------------------------------------
    initial begin
        // Initialize Signals
        Clk    = 0;
        Rst    = 1;
        En     = 1;
        KeyLen = 0;
        Key    = 0;
        KeyUpdate = 0;
        KeyLenUpdate = 0;
        
        // Initialize Interface
        axis_in.tvalid = 0;
        axis_in.tdata  = 0;
        axis_in.tlast  = 0;
        axis_in.tkeep  = 0;
        axis_in.tstrb  = 0;
        axis_in.tid    = 0;
        axis_in.tdest  = 0;
        axis_in.tuser  = 0;
        
        axis_out.tready = 0;

        // Reset Pulse
        #20 Rst = 0;
        #20;

        //----------------------------------------------------------------------
        // Test Case 1: AES-128 Decryption
        // Key:        000102030405060708090a0b0c0d0e0f
        // Ciphertext: 69c4e0d86a7b0430d8cdb78070b4c55a
        // Plaintext:  00112233445566778899aabbccddeeff
        //----------------------------------------------------------------------
        $display("\n=== Starting AES-128 Decryption Test ===");
        KeyLen = 2'b00;
        Key    = {128'h000102030405060708090a0b0c0d0e0f, 128'h0};
        
        // 1.1 New Key (Expect High Latency)
        #10 KeyUpdate = 1; KeyLenUpdate = 1;
        #10 KeyUpdate = 0; KeyLenUpdate = 0;
        #10;
        
        run_test(
            128'h69c4e0d86a7b0430d8cdb78070b4c55a, 
            128'h00112233445566778899aabbccddeeff, 
            "AES-128 [New Key]"
        );
        
        // 1.2 Same Key (Expect Low Latency - Key Expansion Cached)
        #20;
        run_test(
            128'h69c4e0d86a7b0430d8cdb78070b4c55a, 
            128'h00112233445566778899aabbccddeeff, 
            "AES-128 [Cached Key]"
        );
            
        #50;
        
        //----------------------------------------------------------------------
        // Test Case 2: AES-192 Decryption
        // Key:        000102030405060708090a0b0c0d0e0f1011121314151617
        // Ciphertext: dda97ca4864cdfe06eaf70a0ec0d7191
        // Plaintext:  00112233445566778899aabbccddeeff
        //----------------------------------------------------------------------
        $display("\n=== Starting AES-192 Decryption Test ===");
        KeyLen = 2'b01;
        Key    = {192'h000102030405060708090a0b0c0d0e0f1011121314151617, 64'h0};
        
        // 2.1 New Key
        #10 KeyUpdate = 1; KeyLenUpdate = 1;
        #10 KeyUpdate = 0; KeyLenUpdate = 0;
        #10;
        
        run_test(
            128'hdda97ca4864cdfe06eaf70a0ec0d7191, 
            128'h00112233445566778899aabbccddeeff, 
            "AES-192 [New Key]"
        );

        // 2.2 Same Key
        #20;
        run_test(
            128'hdda97ca4864cdfe06eaf70a0ec0d7191, 
            128'h00112233445566778899aabbccddeeff, 
            "AES-192 [Cached Key]"
        );

        #50;

        //----------------------------------------------------------------------
        // Test Case 3: AES-256 Decryption
        // Key:        000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
        // Ciphertext: 8ea2b7ca516745bfeafc49904b496089
        // Plaintext:  00112233445566778899aabbccddeeff
        //----------------------------------------------------------------------
        $display("\n=== Starting AES-256 Decryption Test ===");
        KeyLen = 2'b10;
        Key    = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
        
        // 3.1 New Key
        #10 KeyUpdate = 1; KeyLenUpdate = 1;
        #10 KeyUpdate = 0; KeyLenUpdate = 0;
        #10;
        
        run_test(
            128'h8ea2b7ca516745bfeafc49904b496089, 
            128'h00112233445566778899aabbccddeeff, 
            "AES-256 [New Key]"
        );

        // 3.2 Same Key
        #20;
        run_test(
            128'h8ea2b7ca516745bfeafc49904b496089, 
            128'h00112233445566778899aabbccddeeff, 
            "AES-256 [Cached Key]"
        );
            
        #100;
        $display("\nAll tests completed.");
        $stop;
    end

    //--------------------------------------------------------------------------
    // Task: Run Test
    // Drives input stream and checks output against expected value
    //--------------------------------------------------------------------------
    task run_test(input logic [127:0] ciphertext, input logic [127:0] expected_plain, input string test_name);
        time start_time;
        time end_time;
        int latency;
        logic [127:0] received_data;
        int k;
        
        begin
            // EnsureSink is ready
            axis_out.tready = 1; 
            
            wait(axis_in.tready);
            @(posedge Clk);
            
            start_time = $time;
            
            // Send Ciphertext (16 bytes, MSB first)
            for(k=0; k<16; k++) begin
                axis_in.tvalid = 1;
                // [127-0 ... 127-7] first
                axis_in.tdata  = ciphertext[127 - (k*8) -: 8]; 
                
                // Wait for DUT to accept
                do begin
                    @(posedge Clk);
                end while(!axis_in.tready);
                
                // Clear VALID after the LAST byte is accepted
                if (k == 15) begin
                    axis_in.tvalid = 0;
                    axis_in.tdata  = 0;
                end
            end
            
            // Wait for Result
            // DUT will assert TVALID when data is ready
            do begin
                @(posedge Clk);
            end while(!axis_out.tvalid);
            
            received_data = axis_out.tdata;
            end_time = $time;
            
            // Calculate latency in cycles
            latency = (end_time - start_time) / 10;
            
            if (received_data === expected_plain)
                $display("%-25s PASS: Output matches. Latency: %0d cycles", test_name, latency);
            else
                $display("%-25s FAIL: Expected %h, Got %h", test_name, expected_plain, received_data);
                
            // Clear result interface implicitly by waiting next clock
            @(posedge Clk);
        end
    endtask

endmodule
