`timescale 1ns / 1ps
`default_nettype none

import axilregs_pkg::*;

module axil_regs #
(
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)
(
    input  wire logic clk,
    input  wire logic rst,

    //external interface (conect with CPU)
    // AXI4-Lite Control Interface
    taxi_axil_if.wr_slv s_axil_wr,      // WR
    taxi_axil_if.rd_slv s_axil_rd,      // RD

    //internal interface (conect with AES_UART core)
    output cr1_reg_t    o_cr1,          // CR1
    output cr2_reg_t    o_cr2,          // CR2
    output brr_reg_t    o_brr,          // BRR
    input  isr_reg_t    i_isr,          // ISR

    output logic [31:0] o_ekr[7:0],     // EKR
    output logic [31:0] o_dkr[7:0],     // DKR

    // AXI-Stream Data Interface
    taxi_axis_if.snk    s_axis_rdr,     // RDR
    taxi_axis_if.src    m_axis_tdr,     // TDR
    taxi_axis_if.src    m_axis_epr,     // EPR
    taxi_axis_if.snk    s_axis_dpr,     // DPR

    output logic        o_ekey_update,
    output logic        o_dkey_update,
    output logic        o_ekey_len_update,
    output logic        o_dkey_len_update
);

    // =========================================================================
    // 1. 地址定义（偏移）
    // =========================================================================

    // 控制与状态寄存器
    localparam ADDR_CR1  = 8'h00;
    localparam ADDR_CR2  = 8'h04;
    localparam ADDR_BRR  = 8'h08;
    localparam ADDR_ISR  = 8'h0C;
    localparam ADDR_ICR  = 8'h10;

    // 数据寄存器
    localparam ADDR_RDR  = 8'h14;
    localparam ADDR_TDR  = 8'h18;
    
    localparam ADDR_EKR1 = 8'h1C;
    localparam ADDR_EKR2 = 8'h20;
    localparam ADDR_EKR3 = 8'h24;
    localparam ADDR_EKR4 = 8'h28;
    localparam ADDR_EKR5 = 8'h2C;
    localparam ADDR_EKR6 = 8'h30;
    localparam ADDR_EKR7 = 8'h34;
    localparam ADDR_EKR8 = 8'h38;
    
    localparam ADDR_DKR1 = 8'h3C;
    localparam ADDR_DKR2 = 8'h40;
    localparam ADDR_DKR3 = 8'h44;
    localparam ADDR_DKR4 = 8'h48;
    localparam ADDR_DKR5 = 8'h4C;
    localparam ADDR_DKR6 = 8'h50;
    localparam ADDR_DKR7 = 8'h54;
    localparam ADDR_DKR8 = 8'h58;

    localparam ADDR_EPR1 = 8'h5C;
    localparam ADDR_EPR2 = 8'h60;
    localparam ADDR_EPR3 = 8'h64;
    localparam ADDR_EPR4 = 8'h68;

    localparam ADDR_DPR1 = 8'h6C;
    localparam ADDR_DPR2 = 8'h70;
    localparam ADDR_DPR3 = 8'h74;
    localparam ADDR_DPR4 = 8'h78;

    // =========================================================================
    // 2. 内部寄存器
    // =========================================================================

    cr1_reg_t           reg_cr1         ;
    cr2_reg_t           reg_cr2         ;
    brr_reg_t           reg_brr         ;
    isr_reg_t           reg_isr         ;
    icr_reg_t           reg_icr         ;
    logic       [31:0]  reg_rdr         ;
    logic       [31:0]  reg_tdr         ;
    logic       [31:0]  reg_ekr [7:0]   ;
    logic       [31:0]  reg_dkr [7:0]   ;
    logic       [31:0]  reg_epr [3:0]   ;
    logic       [31:0]  reg_dpr [3:0]   ;

    assign o_cr1 = reg_cr1;
    assign o_cr2 = reg_cr2;
    assign o_brr = reg_brr;
    assign o_ekr = reg_ekr;
    assign o_dkr = reg_dkr;

    // Internal signals must be declared before use
    logic mem_wr_en;
    logic mem_rd_en;
    logic [7:0] wr_addr;
    logic [7:0] rd_addr;

    always_ff @(posedge clk) begin
        if (rst) begin
            o_ekey_update     <= 1'b0;
            o_dkey_update     <= 1'b0;
            o_ekey_len_update <= 1'b0;
            o_dkey_len_update <= 1'b0;
        end else begin
            o_ekey_update     <= (mem_wr_en && (wr_addr == ADDR_EKR8));
            o_dkey_update     <= (mem_wr_en && (wr_addr == ADDR_DKR8));
            o_ekey_len_update <= (mem_wr_en && (wr_addr == ADDR_CR1));
            o_dkey_len_update <= (mem_wr_en && (wr_addr == ADDR_CR1));
        end
    end

    // =========================================================================
    // 3. 内部逻辑与寄存器
    // =========================================================================

    // AXI Lite Handshake Signals
    logic s_axil_awready_reg = 1'b0, s_axil_awready_next;
    logic s_axil_wready_reg = 1'b0, s_axil_wready_next;
    logic s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
    logic s_axil_arready_reg = 1'b0, s_axil_arready_next;
    logic s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;    
    logic [DATA_W-1:0] s_axil_rdata_reg = '0;
  

    // 地址偏移
    assign wr_addr = s_axil_wr.awaddr[7:0];
    assign rd_addr = s_axil_rd.araddr[7:0];

    // =========================================================================
    // 4. 写通道逻辑
    // =========================================================================
    
    // AXI 握手状态机
    assign s_axil_wr.awready = s_axil_awready_reg;
    assign s_axil_wr.wready  = s_axil_wready_reg;
    assign s_axil_wr.bresp   = 2'b00;
    assign s_axil_wr.buser   = '0;
    assign s_axil_wr.bvalid  = s_axil_bvalid_reg;

    always_comb begin
        mem_wr_en = 1'b0;
        s_axil_awready_next = 1'b0;
        s_axil_wready_next = 1'b0;
        s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_wr.bready;

        if (s_axil_wr.awvalid && s_axil_wr.wvalid && (!s_axil_wr.bvalid || s_axil_wr.bready) && (!s_axil_wr.awready && !s_axil_wr.wready)) begin            
            s_axil_awready_next = 1'b1;
            s_axil_wready_next = 1'b1;
            s_axil_bvalid_next = 1'b1;
            mem_wr_en = 1'b1;
        end
    end

    // 寄存器写入逻辑
    always_ff @(posedge clk) begin
        if (rst) begin
            s_axil_awready_reg <= 1'b0;
            s_axil_wready_reg  <= 1'b0;
            s_axil_bvalid_reg  <= 1'b0;
            reg_cr1 <= '0; 
            reg_cr2 <= '0; 
            reg_brr <= '0;
            reg_icr <= '0;
            reg_tdr <= '0;
            for (int i=0; i<8; i++) begin reg_ekr[i] <= '0; reg_dkr[i] <= '0; end
            for (int i=0; i<4; i++) reg_epr[i] <= '0;
        end else begin
            s_axil_awready_reg <= s_axil_awready_next;
            s_axil_wready_reg  <= s_axil_wready_next;
            s_axil_bvalid_reg  <= s_axil_bvalid_next;
            reg_icr <= '0;

            if (mem_wr_en) begin
                case (wr_addr)
                    ADDR_CR1:  reg_cr1    <= s_axil_wr.wdata;
                    ADDR_CR2:  reg_cr2    <= s_axil_wr.wdata;
                    ADDR_BRR:  reg_brr    <= s_axil_wr.wdata;
                    ADDR_ICR:  reg_icr    <= s_axil_wr.wdata;

                    ADDR_TDR:  reg_tdr    <= s_axil_wr.wdata;

                    ADDR_EKR1: reg_ekr[0] <= s_axil_wr.wdata;
                    ADDR_EKR2: reg_ekr[1] <= s_axil_wr.wdata;
                    ADDR_EKR3: reg_ekr[2] <= s_axil_wr.wdata;
                    ADDR_EKR4: reg_ekr[3] <= s_axil_wr.wdata;
                    ADDR_EKR5: reg_ekr[4] <= s_axil_wr.wdata;
                    ADDR_EKR6: reg_ekr[5] <= s_axil_wr.wdata;
                    ADDR_EKR7: reg_ekr[6] <= s_axil_wr.wdata;
                    ADDR_EKR8: reg_ekr[7] <= s_axil_wr.wdata;
                    
                    ADDR_DKR1: reg_dkr[0] <= s_axil_wr.wdata;
                    ADDR_DKR2: reg_dkr[1] <= s_axil_wr.wdata;
                    ADDR_DKR3: reg_dkr[2] <= s_axil_wr.wdata;
                    ADDR_DKR4: reg_dkr[3] <= s_axil_wr.wdata;
                    ADDR_DKR5: reg_dkr[4] <= s_axil_wr.wdata;
                    ADDR_DKR6: reg_dkr[5] <= s_axil_wr.wdata;
                    ADDR_DKR7: reg_dkr[6] <= s_axil_wr.wdata;
                    ADDR_DKR8: reg_dkr[7] <= s_axil_wr.wdata;
                    
                    ADDR_EPR1: reg_epr[0] <= s_axil_wr.wdata;
                    ADDR_EPR2: reg_epr[1] <= s_axil_wr.wdata;
                    ADDR_EPR3: reg_epr[2] <= s_axil_wr.wdata;
                    ADDR_EPR4: reg_epr[3] <= s_axil_wr.wdata;
                endcase
            end
        end
    end

    // =========================================================================
    // 5. 读通道逻辑
    // =========================================================================
    
    assign s_axil_rd.arready = s_axil_arready_reg;
    assign s_axil_rd.rdata   = s_axil_rdata_reg;
    assign s_axil_rd.rresp   = 2'b00;
    assign s_axil_rd.ruser   = '0;
    assign s_axil_rd.rvalid  = s_axil_rvalid_reg;

    always_comb begin
        mem_rd_en = 1'b0;
        s_axil_arready_next = 1'b0;
        s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rd.rready;

        if (s_axil_rd.arvalid && (!s_axil_rd.rvalid || s_axil_rd.rready) && (!s_axil_rd.arready)) begin
            s_axil_arready_next = 1'b1;
            s_axil_rvalid_next = 1'b1;
            mem_rd_en = 1'b1;
        end
    end

    // 读数据映射
    always_ff @(posedge clk) begin
        if (rst) begin
            s_axil_arready_reg <= 1'b0;
            s_axil_rvalid_reg  <= 1'b0;
            s_axil_rdata_reg   <= '0;
        end else begin
            s_axil_arready_reg <= s_axil_arready_next;
            s_axil_rvalid_reg  <= s_axil_rvalid_next;

            if (mem_rd_en) begin
                case (rd_addr)
                    ADDR_CR1:  s_axil_rdata_reg <= reg_cr1   ;
                    ADDR_CR2:  s_axil_rdata_reg <= reg_cr2   ;
                    ADDR_BRR:  s_axil_rdata_reg <= reg_brr   ;
                    ADDR_ISR:  s_axil_rdata_reg <= reg_isr   ;  

                    ADDR_RDR:  s_axil_rdata_reg <= reg_rdr   ;
                    ADDR_TDR:  s_axil_rdata_reg <= reg_tdr   ;

                    ADDR_EKR1: s_axil_rdata_reg <= reg_ekr[0];
                    ADDR_EKR2: s_axil_rdata_reg <= reg_ekr[1];
                    ADDR_EKR3: s_axil_rdata_reg <= reg_ekr[2];
                    ADDR_EKR4: s_axil_rdata_reg <= reg_ekr[3];
                    ADDR_EKR5: s_axil_rdata_reg <= reg_ekr[4];
                    ADDR_EKR6: s_axil_rdata_reg <= reg_ekr[5];
                    ADDR_EKR7: s_axil_rdata_reg <= reg_ekr[6];
                    ADDR_EKR8: s_axil_rdata_reg <= reg_ekr[7];
                    
                    ADDR_DKR1: s_axil_rdata_reg <= reg_dkr[0];
                    ADDR_DKR2: s_axil_rdata_reg <= reg_dkr[1];
                    ADDR_DKR3: s_axil_rdata_reg <= reg_dkr[2];
                    ADDR_DKR4: s_axil_rdata_reg <= reg_dkr[3];
                    ADDR_DKR5: s_axil_rdata_reg <= reg_dkr[4];
                    ADDR_DKR6: s_axil_rdata_reg <= reg_dkr[5];
                    ADDR_DKR7: s_axil_rdata_reg <= reg_dkr[6];
                    ADDR_DKR8: s_axil_rdata_reg <= reg_dkr[7];

                    ADDR_EPR1: s_axil_rdata_reg <= reg_epr[0];
                    ADDR_EPR2: s_axil_rdata_reg <= reg_epr[1];
                    ADDR_EPR3: s_axil_rdata_reg <= reg_epr[2];
                    ADDR_EPR4: s_axil_rdata_reg <= reg_epr[3];

                    ADDR_DPR1: s_axil_rdata_reg <= reg_dpr[0];
                    ADDR_DPR2: s_axil_rdata_reg <= reg_dpr[1];
                    ADDR_DPR3: s_axil_rdata_reg <= reg_dpr[2];
                    ADDR_DPR4: s_axil_rdata_reg <= reg_dpr[3]; 

                    default: s_axil_rdata_reg <= 32'd0;
                endcase
            end
        end
    end

    // =========================================================================
    // 6. AXIS 发送逻辑 (TDR, EPR)
    // =========================================================================
    
    logic reg_tdr_valid;
    logic reg_epr_valid;   

    assign m_axis_tdr.tvalid = reg_tdr_valid;
    assign m_axis_tdr.tdata  = reg_tdr[7:0];
    assign m_axis_epr.tvalid = reg_epr_valid;
    assign m_axis_epr.tdata  = {reg_epr[3], reg_epr[2], reg_epr[1], reg_epr[0]};

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_tdr_valid <= 1'b0;
            reg_epr_valid <= 1'b0;
        end else begin
            if (mem_wr_en && (wr_addr == ADDR_TDR)) begin
                reg_tdr_valid <= 1'b1;
            end
            else if (m_axis_tdr.tready && reg_tdr_valid) begin  
                reg_tdr_valid <= 1'b0;
            end

            if (mem_wr_en && (wr_addr == ADDR_EPR4)) begin
                reg_epr_valid <= 1'b1;
            end
            else if (m_axis_epr.tready && reg_epr_valid) begin  
                reg_epr_valid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 7. AXIS 接收逻辑 (RDR, DPR)
    // =========================================================================
    
    logic reg_rdr_ready;
    logic reg_dpr_ready;

    assign s_axis_rdr.tready = reg_rdr_ready;
    assign s_axis_dpr.tready = reg_dpr_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_rdr_ready <= 1'b1;
            reg_rdr       <= '0;
            reg_dpr_ready <= 1'b1;
            reg_dpr[0]    <= '0;
            reg_dpr[1]    <= '0;
            reg_dpr[2]    <= '0;
            reg_dpr[3]    <= '0;
        end else begin
            if (s_axis_rdr.tready && s_axis_rdr.tvalid) begin
                reg_rdr_ready <= 1'b0;
                reg_rdr       <= {24'd0, s_axis_rdr.tdata};
            end
            else if (mem_rd_en && (rd_addr == ADDR_RDR)) begin
                reg_rdr_ready <= 1'b1;
            end

            if (s_axis_dpr.tready && s_axis_dpr.tvalid) begin
                reg_dpr_ready <= 1'b0;
                reg_dpr[0]    <= s_axis_dpr.tdata[31:0];
                reg_dpr[1]    <= s_axis_dpr.tdata[63:32];
                reg_dpr[2]    <= s_axis_dpr.tdata[95:64];
                reg_dpr[3]    <= s_axis_dpr.tdata[127:96];
            end
            else if (mem_rd_en && (rd_addr == ADDR_DPR4)) begin
                reg_dpr_ready <= 1'b1;
            end
        end
    end

    // =========================================================================
    // 8. ISR 更新逻辑
    // =========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_isr <= '0;
        end
        else begin
            // PE
            if (i_isr.pe) begin
                reg_isr.pe <= 1'b1;
            end else if (reg_icr.pecf) begin
                reg_isr.pe <= 1'b0;
            end

            // FE
            if (i_isr.fe) begin
                reg_isr.fe <= 1'b1;
            end else if (reg_icr.fecf) begin
                reg_isr.fe <= 1'b0;
            end

            // ORE
            if (i_isr.ore) begin
                reg_isr.ore <= 1'b1;
            end else if (reg_icr.orecf) begin
                reg_isr.ore <= 1'b0;
            end

            // IDLE
            if (i_isr.idle) begin
                reg_isr.idle <= 1'b1;
            end else if (reg_icr.idlecf) begin
                reg_isr.idle <= 1'b0;
            end

            // RXNE
            if (!reg_rdr_ready) begin
                reg_isr.rxne <= 1'b1;
            end else begin
                reg_isr.rxne <= 1'b0;
            end

            // TC
            if (i_isr.tc) begin
                reg_isr.tc <= 1'b1;
            end else if (reg_icr.tccf) begin
                reg_isr.tc <= 1'b0;
            end

            // TXE
            if (!reg_tdr_valid) begin
                reg_isr.txe <= 1'b1;
            end else begin
                reg_isr.txe <= 1'b0;
            end

            // DRNE
            if (!reg_dpr_ready) begin
                reg_isr.drne <= 1'b1;
            end else begin
                reg_isr.drne <= 1'b0;
            end

            // ERE
            if (!reg_epr_valid) begin
                reg_isr.ere <= 1'b1;
            end else begin
                reg_isr.ere <= 1'b0;
            end

            // BUSY
            reg_isr.busy <= i_isr.busy;

            // TXFE
            reg_isr.txfe <= i_isr.txfe;
            
            // RXFF
            reg_isr.rxff <= i_isr.rxff;

            // RXFT
            reg_isr.rxft <= i_isr.rxft;

            // TXFT
            reg_isr.txft <= i_isr.txft;
        end
    end    



endmodule