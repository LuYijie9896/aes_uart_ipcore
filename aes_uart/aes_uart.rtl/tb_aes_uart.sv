`timescale 1ns / 1ps

module tb_aes_uart;

    // ================================================================
    // 测试开关（放在文件开头便于操作）
    // ================================================================
    // `define TB_TEST_UART_TX       // 基础TX验证：115200/8N1，写TDR后监测Tx
    // `define TB_TEST_UART_RX       // 基础RX验证：115200/8N1，驱动Rx后读RDR
    // `define TB_TEST_UART_TX_ADV   // 普通TX全面测试：9600、5/6/7位、奇偶校验、停止位（不含时序验证）
    `define TB_TEST_UART_RX_ADV     // 普通RX全面测试：9600、5/6/7位、奇偶校验、1.5/2停止位

    // ================================================================
    // 参数配置
    // ================================================================
    localparam int CLK_FREQ_HZ = 50_000_000; // 50MHz
    localparam int BAUD_RATE   = 115200;
    localparam time CLK_PERIOD = 20ns;

    // ================================================================
    // AXI-Lite 基地址与寄存器偏移
    // ================================================================
    localparam logic [31:0] BASE_ADDR = 32'h4000_0000;
    localparam logic [31:0] ADDR_CR1  = BASE_ADDR + 32'h00;
    localparam logic [31:0] ADDR_CR2  = BASE_ADDR + 32'h04;
    localparam logic [31:0] ADDR_BRR  = BASE_ADDR + 32'h08;
    localparam logic [31:0] ADDR_ISR  = BASE_ADDR + 32'h0C;
    localparam logic [31:0] ADDR_ICR  = BASE_ADDR + 32'h10;
    localparam logic [31:0] ADDR_RDR  = BASE_ADDR + 32'h14;
    localparam logic [31:0] ADDR_TDR  = BASE_ADDR + 32'h18;

    // ================================================================
    // DUT 端口
    // ================================================================
    logic Clk;
    logic Rst_n;

    logic [31:0] awaddr;
    logic [2:0]  awprot;
    logic        awvalid;
    logic        awready;

    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;

    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    logic [31:0] araddr;
    logic [2:0]  arprot;
    logic        arvalid;
    logic        arready;

    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

    logic Rx;
    logic Tx;

    // ISR 采样信号（用于波形观察）
    logic [31:0] isr_snap;
    logic [7:0]  isr_snap_tag;

    // ================================================================
    // DUT 实例
    // ================================================================
    AES_UART dut (
        .Clk    (Clk),
        .Rst_n  (Rst_n),

        .awaddr (awaddr),
        .awprot (awprot),
        .awvalid(awvalid),
        .awready(awready),

        .wdata  (wdata),
        .wstrb  (wstrb),
        .wvalid (wvalid),
        .wready (wready),

        .bresp  (bresp),
        .bvalid (bvalid),
        .bready (bready),

        .araddr (araddr),
        .arprot (arprot),
        .arvalid(arvalid),
        .arready(arready),

        .rdata  (rdata),
        .rresp  (rresp),
        .rvalid (rvalid),
        .rready (rready),

        .Rx     (Rx),
        .Tx     (Tx)
    );

    // ================================================================
    // 时钟与复位
    // ================================================================
    initial begin
        Clk = 1'b0;
        forever #(CLK_PERIOD/2) Clk = ~Clk;
    end

    initial begin
        Rst_n  = 1'b0;
        Rx     = 1'b1; // 空闲高电平
        awaddr = '0;
        awprot = 3'b000;
        awvalid= 1'b0;
        wdata  = '0;
        wstrb  = 4'hF;
        wvalid = 1'b0;
        bready = 1'b0;
        araddr = '0;
        arprot = 3'b000;
        arvalid= 1'b0;
        rready = 1'b0;

        repeat (10) @(posedge Clk);
        Rst_n = 1'b1;
        repeat (5) @(posedge Clk);
    end

    // ================================================================
    // 计算 BRR 值（12.4 固定小数）
    // ================================================================
    function automatic logic [15:0] calc_brr(input int clk_hz, input int baud);
        longint unsigned prescale_fixed;
        begin
                // baud_clk = baud * 8，因此 BRR = (clk_hz * 16) / (baud * 8) = (clk_hz * 2) / baud
                prescale_fixed = (clk_hz * 2 + baud/2) / baud; // 四舍五入
            calc_brr = prescale_fixed[15:0];
        end
    endfunction

    // ================================================================
    // AXI-Lite 读写任务
    // ================================================================
    task automatic axil_write(input logic [31:0] addr, input logic [31:0] data);
        bit aw_done;
        bit w_done;
        begin
            aw_done = 1'b0;
            w_done  = 1'b0;

            awaddr  <= addr;
            awvalid <= 1'b1;
            wdata   <= data;
            wvalid  <= 1'b1;
            wstrb   <= 4'hF;

            while (!(aw_done && w_done)) begin
                @(posedge Clk);
                if (awready) aw_done = 1'b1;
                if (wready)  w_done  = 1'b1;
            end

            awvalid <= 1'b0;
            wvalid  <= 1'b0;

            bready  <= 1'b1;
            while (!bvalid) @(posedge Clk);
            @(posedge Clk);
            bready  <= 1'b0;
        end
    endtask

    task automatic axil_read(input logic [31:0] addr, output logic [31:0] data);
        begin
            araddr  <= addr;
            arvalid <= 1'b1;

            while (!arready) @(posedge Clk);
            arvalid <= 1'b0;

            rready  <= 1'b1;
            while (!rvalid) @(posedge Clk);
            data = rdata;
            @(posedge Clk);
            rready <= 1'b0;
        end
    endtask

    task automatic wait_txe;
        logic [31:0] isr_val;
        begin
            do begin
                axil_read(ADDR_ISR, isr_val);
            end while (isr_val[6] == 1'b0);
        end
    endtask

    task automatic wait_rxne;
        logic [31:0] isr_val;
        begin
            do begin
                axil_read(ADDR_ISR, isr_val);
            end while (isr_val[4] == 1'b0);
        end
    endtask

    task automatic clear_isr_flags;
        begin
            // 清除 PE/FE/ORE/IDLE/TC 标志
            axil_write(ADDR_ICR, 32'h0000_001F);
        end
    endtask

    task automatic snapshot_isr(input [7:0] tag);
        begin
            axil_read(ADDR_ISR, isr_snap);
            isr_snap_tag <= tag;
        end
    endtask

    // ================================================================
    // UART 发送/接收任务
    // ================================================================
    realtime bit_period;
    semaphore test_sem = new(1);

    task automatic uart_send_byte(input byte tx_byte);
        int i;
        begin
            // 起始位
            Rx <= 1'b0;
            #(bit_period);
            // 数据位（LSB 优先）
            for (i = 0; i < 8; i++) begin
                Rx <= tx_byte[i];
                #(bit_period);
            end
            // 停止位
            Rx <= 1'b1;
            #(bit_period);
        end
    endtask

    task automatic uart_send_frame(
        input int data_bits_num,
        input bit parity_en,
        input bit parity_type,
        input int stop_sel,
        input byte tx_data
    );
        int i;
        bit parity_calc;
        realtime stop_len;
        begin
            // 空闲
            Rx <= 1'b1;
            #(bit_period);

            // 起始位
            Rx <= 1'b0;
            #(bit_period);

            // 数据位（LSB 优先）
            for (i = 0; i < data_bits_num; i++) begin
                Rx <= tx_data[i];
                #(bit_period);
            end

            // 奇偶校验位
            if (parity_en) begin
                parity_calc = 1'b0;
                for (i = 0; i < data_bits_num; i++) begin
                    parity_calc = parity_calc ^ tx_data[i];
                end
                if (parity_type) parity_calc = ~parity_calc;
                Rx <= parity_calc;
                #(bit_period);
            end

            // 停止位
            case (stop_sel)
                1: stop_len = 1.5;
                2: stop_len = 2.0;
                default: stop_len = 1.0;
            endcase
            Rx <= 1'b1;
            #(bit_period * stop_len);
        end
    endtask

    task automatic uart_send_frame_with_isr(
        input int data_bits_num,
        input bit parity_en,
        input bit parity_type,
        input int stop_sel,
        input byte tx_data,
        input [7:0] tag_start
    );
        int i;
        bit parity_calc;
        realtime stop_len;
        begin
            // 空闲
            Rx <= 1'b1;
            #(bit_period);

            // 起始位（中点采样 ISR）
            Rx <= 1'b0;
            #(bit_period * 0.5);
            snapshot_isr(tag_start);
            #(bit_period * 0.5);

            // 数据位（LSB 优先）
            for (i = 0; i < data_bits_num; i++) begin
                Rx <= tx_data[i];
                #(bit_period);
            end

            // 奇偶校验位
            if (parity_en) begin
                parity_calc = 1'b0;
                for (i = 0; i < data_bits_num; i++) begin
                    parity_calc = parity_calc ^ tx_data[i];
                end
                if (parity_type) parity_calc = ~parity_calc;
                Rx <= parity_calc;
                #(bit_period);
            end

            // 停止位
            case (stop_sel)
                1: stop_len = 1.5;
                2: stop_len = 2.0;
                default: stop_len = 1.0;
            endcase
            Rx <= 1'b1;
            #(bit_period * stop_len);
        end
    endtask

    task automatic uart_capture_byte(output byte rx_byte);
        int i;
        time timeout_cnt;
        begin
            rx_byte = 8'h00;
            timeout_cnt = 0;

            // 等待起始位
            while (Tx == 1'b1) begin
                #(bit_period/10.0);
                timeout_cnt = timeout_cnt + 1;
                if (timeout_cnt > 2000) begin
                    $display("[UART][FAIL] Start bit timeout");
                    $finish;
                end
            end

            // 对齐到数据采样点
            #(bit_period * 1.5);
            for (i = 0; i < 8; i++) begin
                rx_byte[i] = Tx;
                #(bit_period);
            end

            // 停止位检查
            if (Tx !== 1'b1) begin
                $display("[UART][FAIL] Stop bit error");
                $finish;
            end
        end
    endtask

    task automatic uart_capture_frame(
        input int data_bits_num,
        input bit parity_en,
        input bit parity_type,
        input int stop_sel,
        output byte rx_data,
        output bit parity_ok,
        output bit stop_ok
    );
        int i;
        time timeout_cnt;
        bit parity_calc;
        bit parity_sample;
        realtime stop_len;
        begin
            rx_data = 8'h00;
            parity_ok = 1'b1;
            stop_ok = 1'b1;
            timeout_cnt = 0;

            // 等待起始位
            while (Tx == 1'b1) begin
                #(bit_period/10.0);
                timeout_cnt = timeout_cnt + 1;
                if (timeout_cnt > 2000) begin
                    $display("[UART][FAIL] Start bit timeout");
                    $finish;
                end
            end

            // 对齐到数据采样点
            #(bit_period * 1.5);
            for (i = 0; i < data_bits_num; i++) begin
                rx_data[i] = Tx;
                #(bit_period);
            end

            // 奇偶校验位
            if (parity_en) begin
                parity_sample = Tx;
                parity_calc = 1'b0;
                for (i = 0; i < data_bits_num; i++) begin
                    parity_calc = parity_calc ^ rx_data[i];
                end
                if (parity_type) parity_calc = ~parity_calc;
                if (parity_sample != parity_calc) begin
                    parity_ok = 1'b0;
                end
                #(bit_period);
            end

            // 停止位检测（按中点采样）
            case (stop_sel)
                1: stop_len = 1.5; // 1.5 stop bits
                2: stop_len = 2.0; // 2 stop bits
                default: stop_len = 1.0; // 1 stop bit
            endcase

            // 先对齐到停止位起点
            #(bit_period/2.0);
            if (Tx !== 1'b1) stop_ok = 1'b0;

            if (stop_len >= 1.5) begin
                #(bit_period);
                if (Tx !== 1'b1) stop_ok = 1'b0;
            end
        end
    endtask

    // 保留：停止位时序验证已取消

    // ================================================================
    // 公共初始化
    // ================================================================
    task automatic uart_init;
        logic [15:0] brr_val;
        logic [31:0] cr1_val;
        begin
            brr_val = calc_brr(CLK_FREQ_HZ, BAUD_RATE);
            axil_write(ADDR_BRR, {16'd0, brr_val});
            axil_write(ADDR_CR2, 32'd0);

            // AUE=1, RE=1, TE=1, 8位数据, 1停止位, 无校验, 正常模式
            cr1_val = 32'h0000_0007;
            axil_write(ADDR_CR1, cr1_val);
        end
    endtask

    task automatic uart_config(
        input int baud,
        input int data_bits_num,
        input bit parity_en,
        input bit parity_type,
        input int stop_sel
    );
        logic [15:0] brr_val;
        logic [31:0] cr1_val;
        logic [1:0] wl;
        logic [1:0] stop;
        begin
            // 关闭模块后再配置波特率
            axil_write(ADDR_CR1, 32'h0000_0000);
            brr_val = calc_brr(CLK_FREQ_HZ, baud);
            axil_write(ADDR_BRR, {16'd0, brr_val});

            case (data_bits_num)
                7: wl = 2'd1;
                6: wl = 2'd2;
                5: wl = 2'd3;
                default: wl = 2'd0; // 8位
            endcase

            case (stop_sel)
                1: stop = 2'd1; // 1.5位
                2: stop = 2'd2; // 2位
                default: stop = 2'd0; // 1位
            endcase

            // AUE/RE/TE 使能，其它按需配置
            cr1_val = 32'h0;
            cr1_val[0] = 1'b1; // AUE
            cr1_val[1] = 1'b1; // RE
            cr1_val[2] = 1'b1; // TE
            cr1_val[10:9] = wl;
            cr1_val[8:7]  = stop;
            cr1_val[6] = parity_en;
            cr1_val[5] = parity_type;
            axil_write(ADDR_CR1, cr1_val);
        end
    endtask

    // ================================================================
    // 任务区（Task）
    // ================================================================

    // ================================================================
    // 测试区（Test Cases）
    // ================================================================
    // UART 发送验证：写 TDR -> 监测 Tx
    // ================================================================
`ifdef TB_TEST_UART_TX
    initial begin
        byte cap_byte;
        bit_period = 1e9 / BAUD_RATE;

        @(posedge Rst_n);
        test_sem.get(1);
        uart_init();
        repeat (5) @(posedge Clk);

        axil_write(ADDR_TDR, 32'h0000_00A5);
        uart_capture_byte(cap_byte);

        if (cap_byte == 8'hA5)
            $display("[UART][TX] TX pass: 0x%02h", cap_byte);
        else begin
            $display("[UART][TX][FAIL] Expect=0xA5, Got=0x%02h", cap_byte);
            $finish;
        end

        test_sem.put(1);
    end
`endif

    // ================================================================
    // UART 接收验证：驱动 Rx -> 读 RDR
    // ================================================================
`ifdef TB_TEST_UART_RX
    initial begin
        logic [31:0] isr_val;
        logic [31:0] rdr_val;

        bit_period = 1e9 / BAUD_RATE;

        @(posedge Rst_n);
        test_sem.get(1);
        uart_init();
        repeat (5) @(posedge Clk);

        uart_send_byte(8'h3C);

        // 等待 RXNE 置位
        do begin
            axil_read(ADDR_ISR, isr_val);
        end while (isr_val[4] == 1'b0);

        axil_read(ADDR_RDR, rdr_val);

        if (rdr_val[7:0] == 8'h3C)
            $display("[UART][RX] RX pass: 0x%02h", rdr_val[7:0]);
        else begin
            $display("[UART][RX][FAIL] Expect=0x3C, Got=0x%02h", rdr_val[7:0]);
            $finish;
        end

        test_sem.put(1);
    end
`endif

    // ================================================================
    // 普通TX全面测试（最少次数覆盖）
    // ================================================================
`ifdef TB_TEST_UART_TX_ADV
    initial begin
        byte cap_data;
        bit parity_ok;
        bit stop_ok;
        logic [31:0] isr_val;

        bit_period = 1e9 / 9600.0;

        @(posedge Rst_n);
        test_sem.get(1);

        // 用例1：9600波特率，7位数据，偶校验，1.5停止位
        uart_config(9600, 7, 1'b1, 1'b0, 1);
        wait_txe();
        axil_write(ADDR_TDR, 32'h0000_0055);
        uart_capture_frame(7, 1'b1, 1'b0, 1, cap_data, parity_ok, stop_ok);
        if ((cap_data[6:0] == 7'h55) && parity_ok && stop_ok)
            $display("[UART][TX_ADV] Case1 pass");
        else begin
            $display("[UART][TX_ADV][FAIL] Case1 fail data=0x%02h parity=%0d stop=%0d", cap_data, parity_ok, stop_ok);
            $finish;
        end

        // 用例2：9600波特率，5位数据，奇校验，2停止位
        uart_config(9600, 5, 1'b1, 1'b1, 2);
        wait_txe();
        axil_write(ADDR_TDR, 32'h0000_001B);
        uart_capture_frame(5, 1'b1, 1'b1, 2, cap_data, parity_ok, stop_ok);
        if ((cap_data[4:0] == 5'h1B) && parity_ok && stop_ok)
            $display("[UART][TX_ADV] Case2 pass");
        else begin
            $display("[UART][TX_ADV][FAIL] Case2 fail data=0x%02h parity=%0d stop=%0d", cap_data, parity_ok, stop_ok);
            $finish;
        end

        // 用例3：9600波特率，6位数据，无校验，1停止位
        uart_config(9600, 6, 1'b0, 1'b0, 0);
        wait_txe();
        axil_write(ADDR_TDR, 32'h0000_002D);
        uart_capture_frame(6, 1'b0, 1'b0, 0, cap_data, parity_ok, stop_ok);
        if ((cap_data[5:0] == 6'h2D) && parity_ok && stop_ok)
            $display("[UART][TX_ADV] Case3 pass");
        else begin
            $display("[UART][TX_ADV][FAIL] Case3 fail data=0x%02h parity=%0d stop=%0d", cap_data, parity_ok, stop_ok);
            $finish;
        end

        test_sem.put(1);
    end
`endif

    // ================================================================
    // 普通RX全面测试（最少次数覆盖）
    // ================================================================
`ifdef TB_TEST_UART_RX_ADV
    initial begin
        logic [31:0] rdr_val;
        logic [31:0] isr_val;

        bit_period = 1e9 / 9600.0;

        @(posedge Rst_n);
        test_sem.get(1);

        // 用例1：9600波特率，7位数据，偶校验，1.5停止位
        uart_config(9600, 7, 1'b1, 1'b0, 1);
        clear_isr_flags();
        snapshot_isr(8'h11); // after config
        uart_send_frame_with_isr(7, 1'b1, 1'b0, 1, 8'h55, 8'h12); // start bit
        snapshot_isr(8'h12); // after send
        wait_rxne();
        snapshot_isr(8'h13); // RXNE set
        axil_read(ADDR_RDR, rdr_val);
        snapshot_isr(8'h14); // after read
        axil_read(ADDR_ISR, isr_val);
        if ((rdr_val[6:0] == 7'h55) && (isr_val[1] == 1'b0) && (isr_val[0] == 1'b0))
            $display("[UART][RX_ADV] Case1 pass");
        else begin
            $display("[UART][RX_ADV][FAIL] Case1 fail data=0x%02h PE=%0d FE=%0d", rdr_val[7:0], isr_val[0], isr_val[1]);
            $finish;
        end

        // 用例2：9600波特率，5位数据，奇校验，2停止位
        uart_config(9600, 5, 1'b1, 1'b1, 2);
        clear_isr_flags();
        snapshot_isr(8'h21);
        uart_send_frame(5, 1'b1, 1'b1, 2, 8'h1B);
        snapshot_isr(8'h22);
        wait_rxne();
        snapshot_isr(8'h23);
        axil_read(ADDR_RDR, rdr_val);
        snapshot_isr(8'h24);
        axil_read(ADDR_ISR, isr_val);
        if ((rdr_val[4:0] == 5'h1B) && (isr_val[1] == 1'b0) && (isr_val[0] == 1'b0))
            $display("[UART][RX_ADV] Case2 pass");
        else begin
            $display("[UART][RX_ADV][FAIL] Case2 fail data=0x%02h PE=%0d FE=%0d", rdr_val[7:0], isr_val[0], isr_val[1]);
            $finish;
        end

        // 用例3：9600波特率，6位数据，无校验，1停止位
        uart_config(9600, 6, 1'b0, 1'b0, 0);
        clear_isr_flags();
        snapshot_isr(8'h31);
        uart_send_frame(6, 1'b0, 1'b0, 0, 8'h2D);
        snapshot_isr(8'h32);
        wait_rxne();
        snapshot_isr(8'h33);
        axil_read(ADDR_RDR, rdr_val);
        snapshot_isr(8'h34);
        axil_read(ADDR_ISR, isr_val);
        if ((rdr_val[5:0] == 6'h2D) && (isr_val[1] == 1'b0) && (isr_val[0] == 1'b0))
            $display("[UART][RX_ADV] Case3 pass");
        else begin
            $display("[UART][RX_ADV][FAIL] Case3 fail data=0x%02h PE=%0d FE=%0d", rdr_val[7:0], isr_val[0], isr_val[1]);
            $finish;
        end

        test_sem.put(1);
        $display("[UART][RX_ADV] All cases done");
        $finish;
    end
`endif

endmodule
