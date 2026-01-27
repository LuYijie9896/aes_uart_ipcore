// AES_UART_wrapper.sv
// 用于 Platform Designer Component Editor 封装的包装层
module AES_UART_wrapper #(
    parameter DATA_W = 32,
    parameter ADDR_W = 32
) (
    input  logic                Clk,
    input  logic                Rst,

    // =========================================================================
    // AXI4-Lite Slave Interface (用于 Component Editor 识别的标准信号)
    // =========================================================================
    
    // --- 写地址通道 (Write Address Channel) ---
    input  logic [ADDR_W-1:0]   s_axi_awaddr,
    input  logic                s_axi_awvalid,
    output logic                s_axi_awready,
    input  logic [2:0]          s_axi_awprot, // 可选，通常设为 0

    // --- 写数据通道 (Write Data Channel) ---
    input  logic [DATA_W-1:0]   s_axi_wdata,
    input  logic [(DATA_W/8)-1:0] s_axi_wstrb,
    input  logic                s_axi_wvalid,
    output logic                s_axi_wready,

    // --- 写响应通道 (Write Response Channel) ---
    output logic [1:0]          s_axi_bresp,
    output logic                s_axi_bvalid,
    input  logic                s_axi_bready,

    // --- 读地址通道 (Read Address Channel) ---
    input  logic [ADDR_W-1:0]   s_axi_araddr,
    input  logic                s_axi_arvalid,
    output logic                s_axi_arready,
    input  logic [2:0]          s_axi_arprot, // 可选

    // --- 读数据通道 (Read Data Channel) ---
    output logic [DATA_W-1:0]   s_axi_rdata,
    output logic [1:0]          s_axi_rresp,
    output logic                s_axi_rvalid,
    input  logic                s_axi_rready,

    // =========================================================================
    // UART 接口
    // =========================================================================
    input  logic                Rx,
    output logic                Tx
);

    // 1. 实例化内部接口 (Interface Instances)
    // 注意：这里假设 taxi_axil_if 不需要参数，或者参数名一致。
    // 如果你的 interface 定义需要传参，请在这里加上 #(.DATA_W(DATA_W)...)
    taxi_axil_if wr_if(); 
    taxi_axil_if rd_if();

    // 2. 信号映射：将外部标准信号连接到内部 interface 信号
    // 【请注意】请对照你的 taxi_axil_if.sv 文件，确认内部信号名是否为 awaddr, wdata 等。
    // 如果你的接口里叫 aw_addr，请把下面的 .awaddr 改成 .aw_addr
    
    // --- 连接写通道接口 (wr_if) ---
    assign wr_if.awaddr  = s_axi_awaddr;
    assign wr_if.awvalid = s_axi_awvalid;
    assign s_axi_awready = wr_if.awready;
    // assign wr_if.awprot  = s_axi_awprot; // 如果接口里没有这个信号，请注释掉

    assign wr_if.wdata   = s_axi_wdata;
    assign wr_if.wstrb   = s_axi_wstrb;
    assign wr_if.wvalid  = s_axi_wvalid;
    assign s_axi_wready  = wr_if.wready;

    assign s_axi_bresp   = wr_if.bresp;
    assign s_axi_bvalid  = wr_if.bvalid;
    assign wr_if.bready  = s_axi_bready;

    // --- 连接读通道接口 (rd_if) ---
    assign rd_if.araddr  = s_axi_araddr;
    assign rd_if.arvalid = s_axi_arvalid;
    assign s_axi_arready = rd_if.arready;
    // assign rd_if.arprot  = s_axi_arprot; // 同上

    assign s_axi_rdata   = rd_if.rdata;
    assign s_axi_rresp   = rd_if.rresp;
    assign s_axi_rvalid  = rd_if.rvalid;
    assign rd_if.rready  = s_axi_rready;

    // 3. 实例化原始模块
    AES_UART #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W)
    ) u_aes_uart (
        .Clk     (Clk),
        .Rst     (Rst),
        .wr_axil (wr_if),  // 传入写接口实例
        .rd_axil (rd_if),  // 传入读接口实例
        .Rx      (Rx),
        .Tx      (Tx)
    );

endmodule