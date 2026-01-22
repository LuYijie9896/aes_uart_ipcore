`timescale 1ns / 1ps

module top_verification (
    input  logic        clk_50m,      // 板载 50MHz 时钟
    input  logic        rst_n_btn,    // 复位按键 (低电平有效)
    input  logic        uart_rx_pin,  // 物理 UART RX (FPGA 接收)
    output logic        uart_tx_pin   // 物理 UART TX (FPGA 发送)
);

    // -------------------------------------------------------------------------
    // 1. 内部信号与复位处理
    // -------------------------------------------------------------------------
    logic sys_clk;
    logic sys_rst_n;
    logic sys_rst;

    assign sys_clk   = clk_50m;
    assign sys_rst_n = rst_n_btn;
    assign sys_rst   = ~rst_n_btn; // AES_UART 使用高电平复位，所以取反

    // -------------------------------------------------------------------------
    // 2. 实例化 Interface (AXI4-Lite)
    // -------------------------------------------------------------------------
    // 这是你代码中定义的接口，负责连接 JTAG Bridge 和 AES_UART
    taxi_axil_if #(.DATA_W(32), .ADDR_W(32)) axil_if ();

 // -------------------------------------------------------------------------
    // 3. 实例化 JTAG 系统 (Platform Designer 生成)
    // -------------------------------------------------------------------------
    jtag_axi_sys u_jtag_sys (
        // --- 时钟与复位 ---
        .clk_clk                (sys_clk),
        .reset_reset_n          (sys_rst_n),

        // --- 写地址通道 ---
        .axil_master_awaddr     (axil_if.awaddr),
        .axil_master_awprot     (axil_if.awprot),
        .axil_master_awvalid    (axil_if.awvalid),
        .axil_master_awready    (axil_if.awready),
        // 删除了 awuser，其他悬空保持不变
        .axil_master_awid       (), 
        .axil_master_awlen      (),
        .axil_master_awsize     (),
        .axil_master_awburst    (),
        .axil_master_awlock     (),
        .axil_master_awcache    (),
        .axil_master_awqos      (),
        .axil_master_awregion   (),

        // --- 写数据通道 ---
        .axil_master_wdata      (axil_if.wdata),
        .axil_master_wstrb      (axil_if.wstrb),
        .axil_master_wvalid     (axil_if.wvalid),
        .axil_master_wready     (axil_if.wready),
        // 删除了 wuser
        .axil_master_wlast      (), 

        // --- 写响应通道 ---
        .axil_master_bresp      (axil_if.bresp),
        .axil_master_bvalid     (axil_if.bvalid),
        .axil_master_bready     (axil_if.bready),
        .axil_master_bid        (12'd0), 
        // 删除了 buser

        // --- 读地址通道 ---
        .axil_master_araddr     (axil_if.araddr),
        .axil_master_arprot     (axil_if.arprot),
        .axil_master_arvalid    (axil_if.arvalid),
        .axil_master_arready    (axil_if.arready),
        // 删除了 aruser
        .axil_master_arid       (),
        .axil_master_arlen      (),
        .axil_master_arsize     (),
        .axil_master_arburst    (),
        .axil_master_arlock     (),
        .axil_master_arcache    (),
        .axil_master_arqos      (),
        .axil_master_arregion   (),

        // --- 读数据通道 ---
        .axil_master_rdata      (axil_if.rdata),
        .axil_master_rresp      (axil_if.rresp),
        .axil_master_rvalid     (axil_if.rvalid),
        .axil_master_rready     (axil_if.rready),
        .axil_master_rlast      (1'b1), // 这个必须保留为 1
        .axil_master_rid        (12'd0) 
        // 删除了 ruser
    );

    // -------------------------------------------------------------------------
    // 4. 实例化 AES_UART 核心 (DUT)
    // -------------------------------------------------------------------------
    AES_UART #(
        .DATA_W(32), 
        .ADDR_W(32)
    ) u_dut (
        .Clk        (sys_clk),
        .Rst        (sys_rst), // 高电平有效复位
        
        // 利用 modport 连接 interface
        .wr_axil    (axil_if.wr_slv), 
        .rd_axil    (axil_if.rd_slv),
        
        .Rx         (uart_rx_pin),
        .Tx         (uart_tx_pin)
    );

endmodule