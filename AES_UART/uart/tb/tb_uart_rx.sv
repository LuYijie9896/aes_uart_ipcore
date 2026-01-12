`timescale 1ns / 1ps

module tb_uart_rx();

    // 参数定义
    parameter CLK_PERIOD = 10; // 100MHz
    // 假设波特率为 115200，baud_clk 应为波特率的 8 倍（根据源码中的计数逻辑 [cite: 21, 24]）
    parameter BAUD_8X_PERIOD = 1085; 

    // 信号声明
    logic clk = 0;
    logic rst = 0;
    logic rxd = 1;
    logic baud_clk = 0;

    logic [1:0] data_bits = 0;
    logic [1:0] stop_bits = 0;
    logic parity_en = 0;
    logic parity_type = 0;

    logic busy, overrun_error, frame_error, parity_error;

    // 实例化 AXI4-Stream 接口 [cite: 1-7]
    taxi_axis_if #(
        .DATA_W(8)
    ) m_axis_rx_if ();

    // 实例化 DUT (uart_rx) [cite: 8-10]
    uart_rx dut (
        .clk(clk),
        .rst(rst),
        .m_axis_rx(m_axis_rx_if.src),
        .rxd(rxd),
        .busy(busy),
        .overrun_error(overrun_error),
        .frame_error(frame_error),
        .parity_error(parity_error),
        .data_bits(data_bits),
        .stop_bits(stop_bits),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .baud_clk(baud_clk)
    );

    // 时钟生成
    always #(CLK_PERIOD/2) clk = ~clk;

    // Baud Clock 脉冲生成 (8倍波特率)
    initial begin
        forever begin
            #(BAUD_8X_PERIOD) baud_clk = 1;
            #(CLK_PERIOD)     baud_clk = 0;
        end
    end

    // AXI Stream 接收端模拟：始终准备好接收数据
    assign m_axis_rx_if.tready = 1'b1;

    // 发送一个 UART 字符的任务
    task automatic send_uart_frame(
        input [7:0] data,
        input bit force_parity_error = 0,
        input bit force_frame_error = 0
    );
        int bits_to_send;
        bit p_bit;

        // 根据配置确定数据位数 [cite: 9]
        case (data_bits)
            2'b00: bits_to_send = 8;
            2'b01: bits_to_send = 7;
            2'b10: bits_to_send = 6;
            2'b11: bits_to_send = 5;
        endcase

        // 计算校验位 [cite: 26, 27]
        p_bit = parity_type; // 1 为奇校验，0 为偶校验
        for (int i=0; i < bits_to_send; i++) p_bit ^= data[i];

        $display("[TX] Sending: 0x%h (DataBits: %0d, Parity: %b)", data, bits_to_send, parity_en);

        // 起始位 [cite: 20, 21]
        rxd = 0;
        repeat(8) @(posedge baud_clk);

        // 数据位 [cite: 26]
        for (int i=0; i < bits_to_send; i++) begin
            rxd = data[i];
            repeat(8) @(posedge baud_clk);
        end

        // 校验位 
        if (parity_en) begin
            rxd = force_parity_error ? ~p_bit : p_bit;
            repeat(8) @(posedge baud_clk);
        end

        // 停止位 [cite: 32, 38-40]
        rxd = force_frame_error ? 0 : 1; 
        case (stop_bits)
            2'b00: repeat(8)  @(posedge baud_clk); // 1 bit
            2'b01: repeat(12) @(posedge baud_clk); // 1.5 bits
            2'b10: repeat(16) @(posedge baud_clk); // 2 bits
            default: repeat(8) @(posedge baud_clk);
        endcase
        
        rxd = 1; // 恢复空闲
        repeat(8) @(posedge baud_clk);
    endtask

    // 测试流程
    initial begin
        // 初始化
        rst = 1;
        rxd = 1;
        data_bits = 0;
        stop_bits = 0;
        parity_en = 0;
        parity_type = 0;
        repeat(10) @(posedge clk);
        rst = 0;
        repeat(10) @(posedge clk);

        // ---------------------------------------
        // 测试案例 1: 标准 8N1 (8位, 无校验, 1停止位)
        // ---------------------------------------
        $display("\n--- Test 1: 8N1 Standard ---");
        data_bits = 2'b00; parity_en = 0; stop_bits = 2'b00;
        send_uart_frame(8'hA5);
        wait(m_axis_rx_if.tvalid);
        if (m_axis_rx_if.tdata == 8'hA5) $display("SUCCESS: Received 0x%h", m_axis_rx_if.tdata);
        else $error("FAILURE: Received 0x%h", m_axis_rx_if.tdata);

        // ---------------------------------------
        // 测试案例 2: 7E1 (7位, 偶校验, 1停止位)
        // ---------------------------------------
        $display("\n--- Test 2: 7E1 (7-bit, Even Parity) ---");
        data_bits = 2'b01; parity_en = 1; parity_type = 0;
        send_uart_frame(8'h5A); // 发送 0x5A (二进制 1011010)

        // ---------------------------------------
        // 测试案例 3: 校验错误报告 
        // ---------------------------------------
        $display("\n--- Test 3: Parity Error Injection ---");
        send_uart_frame(8'hFF, 1, 0); // 故意制造校验位错误
        @(posedge clk);
        if (parity_error) $display("SUCCESS: Parity Error Detected!");
        else $error("FAILURE: Parity Error NOT Detected!");

        // ---------------------------------------
        // 测试案例 4: 帧错误报告 
        // ---------------------------------------
        $display("\n--- Test 4: Frame Error Injection ---");
        send_uart_frame(8'hEE, 0, 1); // 停止位期间拉低 rxd
        @(posedge clk);
        if (frame_error) $display("SUCCESS: Frame Error Detected!");
        else $error("FAILURE: Frame Error NOT Detected!");

        // ---------------------------------------
        // 测试案例 5: 溢出错误报告 
        // ---------------------------------------
        $display("\n--- Test 5: Overrun Error ---");
        force m_axis_rx_if.tready = 0; // 阻止 AXI 消费数据
        send_uart_frame(8'h11); 
        send_uart_frame(8'h22); // 在前一个数据未读走时发送第二个
        @(posedge clk);
        if (overrun_error) $display("SUCCESS: Overrun Error Detected!");
        release m_axis_rx_if.tready;

        // ---------------------------------------
        // 测试案例 6: 停止位配置验证 (2 bits) [cite: 40]
        // ---------------------------------------
        $display("\n--- Test 6: 2 Stop Bits ---");
        stop_bits = 2'b10;
        send_uart_frame(8'h33);

        repeat(100) @(posedge clk);
        $display("\n--- All Tests Completed ---");
        $finish;
    end

endmodule