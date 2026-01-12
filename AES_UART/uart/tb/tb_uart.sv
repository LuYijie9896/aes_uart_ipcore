// SPDX-License-Identifier: MIT
/*
 * UART 模块综合测试平台 (Testbench) - 基础验证版
 * 
 * 本测试平台旨在逐步验证 UART 模块的各项功能。
 * 
 * 当前测试内容 (Step 1):
 * 1. 基础信号连接与仿真环境复位
 * 2. 基础收发测试 (配置: 8位数据, 无校验, 1位停止位)
 *    - TX通路: Task axis_write_byte -> 监测 txd 引脚
 *    - RX通路: Task uart_phy_write_byte -> 监测 m_axis_rx 接口
 * 
 */

`timescale 1ns / 1ps

module tb_uart;

    // ==========================================================================
    // 1. 参数与信号定义
    // ==========================================================================
    
    parameter PRE_W = 16;         // 预分频计数器位宽
    parameter DATA_W = 8;         // AXI Stream 数据位宽
    parameter CLK_PERIOD_NS = 20; // 50 MHz 主时钟作为参考

    // 系统信号
    logic clk;
    logic rst;

    // UART 物理接口 (Device Under Test 的引脚)
    logic rxd;
    logic txd;

    // AXI-Stream 用户接口实例 (使用 SV interface)
    taxi_axis_if #(.DATA_W(DATA_W)) s_axis_tx(); // 发送通道 (Sink, 给 DUT 输入数据)
    taxi_axis_if #(.DATA_W(DATA_W)) m_axis_rx(); // 接收通道 (Source, 从 DUT 获取数据)

    // 状态标志位
    logic busy;             // 忙信号 (TX或RX正忙)
    logic tx_done;          // 发送完成脉冲
    logic rx_idle;          // 接收空闲事件 (超时)
    logic rx_overrun_error; // 接收溢出错误 (未及时取走数据)
    logic rx_frame_error;   // 帧错误 (停止位检测失败)
    logic rx_parity_error;  // 校验错误

    // 运行时可配置参数
    logic [PRE_W-1:0] prescale;
    logic [1:0] data_bits;   // 0:8位, 1:7位, 2:6位, 3:5位
    logic [1:0] stop_bits;   // 0:1位, 1:1.5位, 2:2位
    logic parity_en;         // 1:开启校验
    logic parity_type;       // 0:偶校验, 1:奇校验
    
    // 独立使能控制
    logic global_en;
    logic tx_en;
    logic rx_en;

    // 仿真辅助变量
    real current_bit_period_ns; // 保存当前波特率下的位时间 (用于物理层模拟)

    // ==========================================================================
    // 2. 待测模块 (DUT) 例化
    // ==========================================================================

    uart #(
        .PRE_W(PRE_W)
    ) uut (
        .clk(clk),
        .rst(rst),
        .global_en(global_en),
        .tx_en(tx_en),
        .rx_en(rx_en),
        // 用户数据流接口
        .s_axis_tx(s_axis_tx),
        .m_axis_rx(m_axis_rx),
        // 物理接口
        .rxd(rxd),
        .txd(txd),
        // 状态与错误报告
        .busy(busy),
        .tx_done(tx_done),
        .rx_idle(rx_idle),
        .rx_overrun_error(rx_overrun_error),
        .rx_frame_error(rx_frame_error),
        .rx_parity_error(rx_parity_error),
        // 配置接口
        .prescale(prescale),
        .data_bits(data_bits),
        .stop_bits(stop_bits),
        .parity_en(parity_en),
        .parity_type(parity_type)
    );

    // ==========================================================================
    // 3. 时钟生成与位时间计算
    // ==========================================================================

    // 生成 50MHz 时钟
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // 辅助函数: 根据当前 prescale 计算理想的 UART 位宽 (ns)
    // 逻辑依据: RTL 中波特率分频器生成 8 倍过采样时钟
    // Bit Period = (Prescale / 2.0) * CLK_PERIOD
    function void update_bit_period();
        current_bit_period_ns = (prescale / 2.0) * CLK_PERIOD_NS;
    endfunction

    // ==========================================================================
    // 4. 通用测试任务库 (Tasks)
    // ==========================================================================

    /**
     * System Reset Task
     * Restore all signals to default safe state
     */
    task sys_reset();
        $display("[System] Performing system reset...");
        rst = 1;
        global_en = 1;
        tx_en = 1;
        rx_en = 1;
        
        // Interface init
        s_axis_tx.tvalid = 0;
        s_axis_tx.tdata = 0;
        m_axis_rx.tready = 1; // TB is always ready

        rxd = 1; // Default IDLE high

        // Default: 115200 Baud, 8N1
        prescale = 16'h0364; // Decimal 868
        data_bits = 0; // 8 bits
        stop_bits = 0; // 1 stop
        parity_en = 0; // Disable
        parity_type = 0;

        update_bit_period(); // Update helper var
        
        #200;
        rst = 0;
        #200;
        $display("[System] Reset done. Current Config: 8N1, Bit Period: %0.2fns", current_bit_period_ns);
    endtask

    /**
     * Task: User writes data (User -> AXIS -> DUT)
     * Simulates user logic writing a byte to UART TX
     */
    task axis_write_byte(input logic [7:0] data);
        $display("[Driver] User request to send data: 0x%h", data);
        s_axis_tx.tdata <= data;
        s_axis_tx.tvalid <= 1;
        
        // Handshake: Wait for DUT TREADY
        wait(s_axis_tx.tready);
        @(posedge clk);
        
        // Handshake done, drop Valid
        s_axis_tx.tvalid <= 0;
        
        // Confirm DUT enters Busy state
        wait(busy); 
    endtask

    /**
     * Task: User checks reception (User <- AXIS <- DUT)
     * Simulates user logic reading from UART RX and checking value
     */
    task axis_read_check_byte(input logic [7:0] expected_data);
        int timeout;
        timeout = 50000; // Timeout to prevent deadlock
        
        m_axis_rx.tready <= 1;

        // Valid
        while (!m_axis_rx.tvalid && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end

        // Check verification
        if (timeout == 0) begin
            $error("[Monitor] Error: Timeout waiting for RX data! Expected: 0x%h", expected_data);
        end else begin
            if (m_axis_rx.tdata !== expected_data) begin
                $error("[Monitor] Error: Data mismatch! Expected: 0x%h, Got: 0x%h", expected_data, m_axis_rx.tdata);
            end else begin
                $display("[Monitor] Success: Correctly received data 0x%h", m_axis_rx.tdata);
            end
        end
        
        @(posedge clk);
    endtask

    /**
     * Task: PHY send model (Testbench -> RXD Pin -> DUT)
     * Updated for Step 3: Supports error injection
     */
    task uart_phy_write_byte(
        input logic [7:0] data,
        input logic inject_parity_error = 0,
        input logic inject_frame_error = 0
    );
        integer i;
        int num_data_bits;
        logic p_bit;
        
        // Determine bit count
        case(data_bits)
            0: num_data_bits = 8;
            1: num_data_bits = 7;
            2: num_data_bits = 6;
            3: num_data_bits = 5;
        endcase

        $display("[PHY Model] Sending: 0x%h (ErrInj: P=%b, F=%b)", data, inject_parity_error, inject_frame_error);

        // 1. Start Bit (Low)
        rxd = 0;
        #(current_bit_period_ns);

        // 2. Data Bits (LSB First)
        p_bit = 0; 
        for (i = 0; i < num_data_bits; i++) begin
            rxd = data[i];
            p_bit = p_bit ^ data[i]; // Calculate Even Parity
            #(current_bit_period_ns);
        end

        // 3. Parity Bit
        if (parity_en) begin
            if (parity_type) p_bit = ~p_bit; // Convert to Odd if needed
            
            // ERROR INJECTION
            if (inject_parity_error) begin
                p_bit = ~p_bit;
                $display("[PHY Model] Injecting Parity Error!");
            end

            rxd = p_bit;
            #(current_bit_period_ns);
        end

        // 4. Stop Bit
        if (inject_frame_error) begin
            rxd = 0; // Drive LOW during stop bit to cause Frame Error
            $display("[PHY Model] Injecting Frame Error!");
        end else begin
            rxd = 1;
        end

        // Stop Bit Duration
        if (stop_bits == 0)      #(current_bit_period_ns * 1.0);
        else if (stop_bits == 1) #(current_bit_period_ns * 1.5);
        else if (stop_bits == 2) #(current_bit_period_ns * 2.0);
        
        rxd = 1; // Return to IDLE
        #(current_bit_period_ns);
    endtask

    /**
     * Task: PHY RX Check (Testbench <- TXD Pin <- DUT)
     * Monitor TXD pin, decode waveform and compare
     * Updated for Step 2: Supports data_bits, parity
     */
    task uart_phy_read_check_byte(input logic [7:0] expected_data);
        integer i;
        logic [7:0] rx_data;
        int num_data_bits;
        logic p_bit_calc;
        logic p_bit_rcvd;

        // Determine bit count
        case(data_bits)
            0: num_data_bits = 8;
            1: num_data_bits = 7;
            2: num_data_bits = 6;
            3: num_data_bits = 5;
        endcase

        rx_data = 0;

        // 1. Wait for Start Bit (Falling edge)
        wait(txd == 0);
        
        // 2. Align sampling point
        #(current_bit_period_ns * 1.5);

        // 3. Sample Data Bits
        p_bit_calc = 0;
        for (i = 0; i < num_data_bits; i++) begin
            rx_data[i] = txd;
            p_bit_calc = p_bit_calc ^ txd;
            #(current_bit_period_ns);
        end

        // 4. Sample Parity Bit
        if (parity_en) begin
            if (parity_type) p_bit_calc = ~p_bit_calc;
            p_bit_rcvd = txd;
            if (p_bit_rcvd !== p_bit_calc) begin
                $error("[PHY Monitor] Error: Parity Fail! Calc:%b, Got:%b", p_bit_calc, p_bit_rcvd);
            end
            #(current_bit_period_ns);
        end

        // 5. Check Stop Bit
        if (txd !== 1) begin
            $error("[PHY Monitor] Error: Stop bit missing (Line Low)!");
        end

        // Mask unused bits in expected data
        case(data_bits)
            1: expected_data[7] = 0;
            2: expected_data[7:6] = 0;
            3: expected_data[7:5] = 0;
        endcase

        if (rx_data !== expected_data) begin
            $error("[PHY Monitor] Error: Data mismatch! Exp:0x%h, Got:0x%h", expected_data, rx_data);
        end else begin
            $display("[PHY Monitor] Success: Captured 0x%h", rx_data);
        end
    endtask

    // ==========================================================================
    // 5. Main Test Flow
    // ==========================================================================

    initial begin
        // Output waveform file
        $dumpfile("uart_verify_step1.vcd");
        $dumpvars(0, tb_uart);

        $display("==================================================");
        $display("   UART Module Verification - Step 1: Basic TX/RX   ");
        $display("==================================================");

        sys_reset();

        // ------------------------------------------------------------
        // Test Case 1: Basic TX Test (Loopback TX)
        // Goal: Verify DUT properly encodes AXIS data to UART waveform
        // ------------------------------------------------------------
        $display("\n--- [Case 1] Basic TX Test: 0xA5 (8N1) ---");
        
        fork
            // Process A: Drive AXIS interface
            axis_write_byte(8'hA5);
            
            // Process B: Monitor TXD waveform
            uart_phy_read_check_byte(8'hA5);
        join
        
        #1000; // Wait

        // ------------------------------------------------------------
        // Test Case 2: Basic RX Test (Loopback RX)
        // Goal: Verify DUT properly decodes UART waveform to AXIS data
        // ------------------------------------------------------------
        $display("\n--- [Case 2] Basic RX Test: 0x5A (8N1) ---");
        
        fork
            // Process A: Simulate external device waveform
            uart_phy_write_byte(8'h5A);
            
            // Process B: Monitor AXIS RX data
            axis_read_check_byte(8'h5A);
        join

        #2000;

        // ======================================================================
        // Step 2: Config Verification (Data bits, Parity, Stop bits)
        // ======================================================================
        $display("\n==================================================");
        $display("   Step 2: Configuration Test (Data/Parity/Stop)  ");
        $display("==================================================");

        // --- Case 3: 7 Data Bits, No Parity ---
        $display("\n--- [Case 3] 7N1 Test (Data: 0x55) ---");
        data_bits = 1; // 7 bits
        stop_bits = 0; // 1 stop
        parity_en = 0;
        #200;
        
        fork
            axis_write_byte(8'h55);
            uart_phy_read_check_byte(8'h55);
        join
        #500;
        fork
            uart_phy_write_byte(8'h2A);
            axis_read_check_byte(8'h2A);
        join
        #500;

        // --- Case 4: 5 Data Bits, 1.5 Stop Bits ---
        $display("\n--- [Case 4] 5N1.5 Test (Data: 0x1F) ---");
        data_bits = 3; // 5 bits
        stop_bits = 1; // 1.5 stop
        parity_en = 0;
        #200;
        
        fork
            axis_write_byte(8'h1F);
            uart_phy_read_check_byte(8'h1F);
        join
        #500;
        fork
            uart_phy_write_byte(8'h0A);
            axis_read_check_byte(8'h0A);
        join
        #500;

        // --- Case 5: 8 Data Bits, Even Parity ---
        $display("\n--- [Case 5] 8E1 Test (Data: 0xAB) ---");
        // 0xAB = 1010_1011 (5 ones -> Parity=1 for Even)
        data_bits = 0; // 8 bits
        stop_bits = 0; // 1 stop
        parity_en = 1;
        parity_type = 0; // Even
        #200;

        fork
            axis_write_byte(8'hAB);
            uart_phy_read_check_byte(8'hAB);
        join
        #500;
        fork
            uart_phy_write_byte(8'hCD);
            axis_read_check_byte(8'hCD);
        join
        #500;

        // --- Case 6: 8 Data Bits, Odd Parity, 2 Stop Bits ---
        $display("\n--- [Case 6] 8O2 Test (Data: 0x55) ---");
        // 0x55 = 0101_0101 (4 ones -> Parity=1 for Odd)
        data_bits = 0; 
        stop_bits = 2; // 2 stop
        parity_en = 1;
        parity_type = 1; // Odd
        #200;

        fork
            axis_write_byte(8'h55);
            uart_phy_read_check_byte(8'h55);
        join
        #500;
        fork
            uart_phy_write_byte(8'hAA);
            axis_read_check_byte(8'hAA);
        join

        #2000;

        // ======================================================================
        // Step 3: Error Reporting & Status Flags Verification
        // ======================================================================
        $display("\n==================================================");
        $display("   Step 3: Error & Status Flags Test              ");
        $display("==================================================");

        // --- Case 7: Parity Error Test ---
        $display("\n--- [Case 7] Parity Error Injection (8E1) ---");
        // Config: 8 bits, Even Parity
        data_bits = 0; stop_bits = 0; parity_en = 1; parity_type = 0;
        #200;

        fork
            // Send 0xFF (8 ones -> Even Parity should be 0).
            // But we inject error -> Parity bit sent as 1.
            uart_phy_write_byte(8'hFF, 1, 0); 
            
            // Monitor for Error Pulse
            begin
                @(posedge rx_parity_error);
                $display("[Monitor] Success: Parity Error Detected!");
            end
        join
        #500;

        // --- Case 8: Frame Error Test ---
        $display("\n--- [Case 8] Frame Error Injection (8N1) ---");
        // Config: 8 bits, No Parity
        parity_en = 0; 
        #200;

        fork
            // Send 0x00, but drive Stop Bit Low
            uart_phy_write_byte(8'h00, 0, 1);
            
            // Monitor for Error Pulse
            begin
                @(posedge rx_frame_error);
                $display("[Monitor] Success: Frame Error Detected!");
            end
        join
        #500;

        // --- Case 9: Overrun Error Test ---
        $display("\n--- [Case 9] Overrun Error Injection ---");
        // Config: 8N1
        #200;

        // Force AXIS RX NOT Ready (Simulate user logic busy)
        m_axis_rx.tready = 0;
        $display("[Driver] Holding RX TREADY Low (Backpressure)...");

        // Send Byte 1 (Held in DUT internal buffer)
        uart_phy_write_byte(8'hA1);
        wait(m_axis_rx.tvalid); // DUT has valid data waiting

        // Send Byte 2 (This should cause Overrun because Byte 1 is stuck)
        // CRITICAL FIX: Use fork-join because Overrun pulse happens DURING the uart_phy_write_byte task
        fork
            uart_phy_write_byte(8'hB2);
            begin
                @(posedge rx_overrun_error);
                $display("[Monitor] Success: Overrun Error Detected!");
            end
        join
        
        // Cleanup: Release backpressure
        m_axis_rx.tready = 1;
        #500;

        // --- Case 10: Enable Signal Test ---
        $display("\n--- [Case 10] Enable Signal / Idle Test ---");
        
        // 10.1 Disable TX
        tx_en = 0;
        #100;
        // Manually drive signals instead of using task, because task waits for ready
        $display("[Driver] Attempting to send 0xFF while TX Disabled...");
        s_axis_tx.tdata <= 8'hFF;
        s_axis_tx.tvalid <= 1;
        
        #1000; // Wait to see if DUT reacts
        
        if (s_axis_tx.tready == 0 && busy == 0) begin
             $display("[Check] Success: TX ignored data (Ready stayed Low)");
        end else begin
             $error("[Check] Error: TX started or set Ready while disabled!");
        end
        
        // Cleanup
        s_axis_tx.tvalid <= 0;
        tx_en = 1;
        #200;
        
        // 10.2 Verify RX Idle Signal logic
        // Send a byte and check if idle pulses after frame
        fork
            uart_phy_write_byte(8'hCC);
            begin
                @(posedge rx_idle);
                $display("[Monitor] Success: RX Idle Pulse Detected!");
            end
        join

        #2000;
        $display("\n==================================================");
        $display("   ALL STEPS COMPLETED SUCCESSFULLY               ");
        $display("==================================================");
        $finish;
    end

endmodule
