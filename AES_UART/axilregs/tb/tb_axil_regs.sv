`timescale 1ns / 1ps
`default_nettype none

import axilregs_pkg::*;

module tb_axil_regs;

    // =========================================================================
    // 1. 参数与信号定义
    // =========================================================================
    parameter ADDR_W = 32;
    parameter DATA_W = 32;
    parameter CLK_PERIOD = 10; // 100MHz

    logic clk;
    logic rst;

    // 内部信号连接
    cr1_reg_t    o_cr1;
    cr2_reg_t    o_cr2;
    brr_reg_t    o_brr;
    isr_reg_t    i_isr; // 模拟外部中断输入
    logic [31:0] o_ekr[7:0];
    logic [31:0] o_dkr[7:0];

    // =========================================================================
    // 2. 接口实例化
    // =========================================================================
    
    // AXI-Lite 接口
    taxi_axil_if #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) s_axil_wr ();
    taxi_axil_if #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) s_axil_rd ();

    // AXI-Stream 接口 (注意位宽配置，根据你的DUT逻辑调整)
    taxi_axis_if #(.DATA_W(8))  s_axis_rdr (); // 8-bit RX Data
    taxi_axis_if #(.DATA_W(8))  m_axis_tdr (); // 8-bit TX Data
    taxi_axis_if #(.DATA_W(128)) m_axis_epr (); // 假设 EPR 输出拼接后是宽总线，或者根据逻辑只看低8位，这里根据DUT逻辑暂定
    taxi_axis_if #(.DATA_W(128)) s_axis_dpr (); // 假设 DPR 输入是宽总线

    // =========================================================================
    // 3. DUT 实例化
    // =========================================================================
    axil_regs #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) dut (
        .clk(clk),
        .rst(rst),

        // AXI-Lite 接口
        .s_axil_wr(s_axil_wr.wr_slv),
        .s_axil_rd(s_axil_rd.rd_slv),

        // 寄存器输出
        .o_cr1(o_cr1),
        .o_cr2(o_cr2),
        .o_brr(o_brr),
        .i_isr(i_isr),
        .o_ekr(o_ekr),
        .o_dkr(o_dkr),

        // AXI-Stream 接口
        .s_axis_rdr(s_axis_rdr.snk),
        .m_axis_tdr(m_axis_tdr.src),
        .m_axis_epr(m_axis_epr.src),
        .s_axis_dpr(s_axis_dpr.snk)
    );

    // =========================================================================
    // 4. 时钟与复位生成
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst = 1;
        #100;
        @(posedge clk);
        rst = 0;
    end

    // =========================================================================
    // 5. BFM 任务定义 (模拟 AXI Master)
    // =========================================================================

    // 任务：AXI-Lite 写寄存器
    task axil_write(input [7:0] addr, input [31:0] data);
        begin
            // Setup Address and Data
            s_axil_wr.awaddr  <= {24'd0, addr}; // 扩展到32位地址
            s_axil_wr.awvalid <= 1'b1;
            s_axil_wr.wdata   <= data;
            s_axil_wr.wvalid  <= 1'b1;
            s_axil_wr.wstrb   <= 4'hF;

            // Wait for handshake
            fork
                begin
                    wait(s_axil_wr.awready);
                    @(posedge clk);
                    s_axil_wr.awvalid <= 1'b0;
                end
                begin
                    wait(s_axil_wr.wready);
                    @(posedge clk);
                    s_axil_wr.wvalid <= 1'b0;
                end
            join

            // Response Phase
            s_axil_wr.bready <= 1'b1;
            wait(s_axil_wr.bvalid);
            @(posedge clk);
            s_axil_wr.bready <= 1'b0;
            
            $display("[AXI-WR] Addr: 0x%02h, Data: 0x%08h", addr, data);
        end
    endtask

    // 任务：AXI-Lite 读寄存器并校验
    task axil_read(input [7:0] addr, input [31:0] expected_data, input bit check = 1);
        logic [31:0] read_data;
        begin
            // Address Phase
            s_axil_rd.araddr  <= {24'd0, addr};
            s_axil_rd.arvalid <= 1'b1;

            wait(s_axil_rd.arready);
            @(posedge clk);
            s_axil_rd.arvalid <= 1'b0;

            // Data Phase
            s_axil_rd.rready <= 1'b1;
            wait(s_axil_rd.rvalid);
            read_data = s_axil_rd.rdata;
            @(posedge clk);
            s_axil_rd.rready <= 1'b0;

            $display("[AXI-RD] Addr: 0x%02h, Data: 0x%08h, Expected: 0x%08h", addr, read_data, expected_data);
            
            if (check && (read_data !== expected_data)) begin
                $error("Error: Read mismatch! Addr: 0x%02h", addr);
            end
        end
    endtask

    // =========================================================================
    // 6. 主测试流程
    // =========================================================================
    
    // 初始化信号
    initial begin
        // AXI WR init
        s_axil_wr.awaddr = 0; s_axil_wr.awvalid = 0;
        s_axil_wr.wdata = 0; s_axil_wr.wvalid = 0; s_axil_wr.wstrb = 0;
        s_axil_wr.bready = 0;
        // AXI RD init
        s_axil_rd.araddr = 0; s_axil_rd.arvalid = 0;
        s_axil_rd.rready = 0;
        // AXIS init
        m_axis_tdr.tready = 1; // 默认下游总是准备好接收
        m_axis_epr.tready = 1;
        s_axis_rdr.tdata = 0; s_axis_rdr.tvalid = 0; s_axis_rdr.tlast = 0;
        s_axis_dpr.tdata = 0; s_axis_dpr.tvalid = 0; s_axis_dpr.tlast = 0;
        // ISR init
        i_isr = '0;
    end

    // 测试脚本
    initial begin
        // 等待复位释放
        wait(rst == 0);
        repeat(10) @(posedge clk);
        $display("=== Simulation Start ===");

        // ---------------------------------------------------------------------
        // Test 1: 普通寄存器读写 (CR1)
        // ---------------------------------------------------------------------
        $display("\n--- Test 1: Basic Register R/W (CR1) ---");
        // 写入 CR1 (假设写入 0x0000_000F: Global enable etc.)
        axil_write(8'h00, 32'h0000_000F);
        
        // 读回 CR1 验证
        axil_read(8'h00, 32'h0000_000F);
        
        // 验证输出端口
        #1;
        if (o_cr1.aue == 1'b1) $display("PASS: o_cr1 updated correctly.");
        else $error("FAIL: o_cr1 signal not updated.");

        // ---------------------------------------------------------------------
        // Test 2: AXI-Stream 发送测试 (TDR) - 修正版
        // ---------------------------------------------------------------------
        $display("\n--- Test 2: AXI-Stream TX (TDR) ---");
        
        // 【关键修改】先拉低 Ready，强迫 DUT 保持 Valid 信号，防止错过脉冲
        m_axis_tdr.tready = 0; 

        // 写入 TDR 寄存器 (Offset 0x18)
        axil_write(8'h18, 32'h0000_00AB);

        // 现在即使 axil_write 花了很久，DUT 的 tvalid 也会因为没有 tready 而一直保持为 1
        // 我们就可以放心地 wait 了
        wait(m_axis_tdr.tvalid);
        
        // 稍微等一下，确保数据稳定
        #1; 
        
        // 检查数据
        if (m_axis_tdr.tdata == 8'hAB) 
            $display("PASS: AXIS TDR Output Data Correct (0xAB)");
        else 
            $error("FAIL: AXIS TDR Data Mismatch (Got 0x%h)", m_axis_tdr.tdata);

        // 【关键修改】检查完数据后，手动给出 Ready 信号完成握手
        @(posedge clk);
        m_axis_tdr.tready = 1;

        // 等待握手结束 (Valid 应该变低)
        wait(m_axis_tdr.tvalid == 0);
        $display("PASS: AXIS TDR Handshake Completed");
        // ---------------------------------------------------------------------
        // Test 3: AXI-Stream 接收测试 (AXIS 输入 -> CPU 读 RDR)
        // ---------------------------------------------------------------------
        $display("\n--- Test 3: AXI-Stream RX (RDR) ---");
        
        // 模拟外部数据输入
        @(posedge clk);
        s_axis_rdr.tdata  <= 8'hCD;
        s_axis_rdr.tvalid <= 1'b1;
        
        // 等待 DUT 接收 (TREADY && TVALID)
        wait(s_axis_rdr.tready);
        @(posedge clk);
        // 数据被锁存，DUT 应该拉低 TREADY (Busy) 直到 CPU 读取
        s_axis_rdr.tvalid <= 1'b0; 
        
        #1;
        if (s_axis_rdr.tready == 0)
            $display("PASS: RDR flow control active (Ready went low)");
        else
            $error("FAIL: RDR Ready should be low after receiving data");

        // CPU 读取 RDR (Offset 0x14)
        axil_read(8'h14, 32'h0000_00CD);

        // 读取后，DUT 应该释放 Ready
        repeat(2) @(posedge clk); // 给一点时间更新逻辑
        if (s_axis_rdr.tready == 1)
            $display("PASS: RDR Ready restored after CPU read");
        else
            $error("FAIL: RDR Ready did not recover");

        // ---------------------------------------------------------------------
        // Test 4: 中断状态与清除 (ISR / ICR)
        // ---------------------------------------------------------------------
        $display("\n--- Test 4: ISR Set and Clear (ICR) ---");

        // 4.1 模拟外部硬件触发 PE (Parity Error) 中断
        @(posedge clk);
        i_isr.pe <= 1'b1; // 产生脉冲
        @(posedge clk);
        i_isr.pe <= 1'b0;

        // 4.2 读取 ISR (Offset 0x0C)，预期 bit 0 (pe) 为 1
        // 注意：ISR 复位值为 0，刚才置位了
        axil_read(8'h0C, 32'h0000_0001); 

        // 4.3 写入 ICR (Offset 0x10) 清除 PE
        // 这里的 ICR 位定义：bit 0 是 pecf (Parity Error Clear Flag)
        axil_write(8'h10, 32'h0000_0001);

        // 4.4 再次读取 ISR，预期 bit 0 变回 0
        axil_read(8'h0C, 32'h0000_0000);

        // ---------------------------------------------------------------------
        // Test 5: EKR 数组测试 (扩展测试)
        // ---------------------------------------------------------------------
        $display("\n--- Test 5: EKR Array Write ---");
        // 写入 EKR1 (0x1C)
        axil_write(8'h1C, 32'hDEAD_BEEF);
        #1;
        if (o_ekr[0] == 32'hDEAD_BEEF)
            $display("PASS: EKR[0] updated.");
        else
            $error("FAIL: EKR[0] mismatch.");

        // ---------------------------------------------------------------------
        // 结束仿真
        // ---------------------------------------------------------------------
        repeat(10) @(posedge clk);
        $display("\n=== All Tests Finished ===");
        $finish;
    end

endmodule