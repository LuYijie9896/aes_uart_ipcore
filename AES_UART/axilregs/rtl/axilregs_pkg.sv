// SPDX-License-Identifier: MIT
`timescale 1ns / 1ps

package axilregs_pkg;

    // =========================================================================
    // Control Register 1 (CR1) - Offset 0x00
    // =========================================================================
    typedef struct packed {
        logic [15:0] reserved;  // 31:16 保留
        logic        wm;        // 15: 工作模式 (0:正常, 1:回环)
        logic [1:0]  el;        // 14:13: 加密密钥长度 (00:128, 01:192, 10:256)
        logic [1:0]  dl;        // 12:11: 解密密钥长度
        logic [1:0]  wl;        // 10:9: 数据位长度
        logic [1:0]  stop;      // 8:7: 停止位长度
        logic        pce;       // 6: 校验位控制使能
        logic        ps;        // 5: 校验位选择 (0:偶, 1:奇)
        logic        ee;        // 4: 加密使能
        logic        de;        // 3: 解密使能
        logic        te;        // 2: 发送使能
        logic        re;        // 1: 接收使能
        logic        aue;       // 0: 全局使能
    } cr1_reg_t;

    // =========================================================================
    // Control Register 2 (CR2) - Offset 0x04
    // =========================================================================
    typedef struct packed {
        logic [11:0] reserved;      // 31:20 保留
        logic [2:0]  txftcfg;       // 19:17: TXFIFO 阈值配置
        logic        txftie;        // 16: TXFIFO 阈值中断使能
        logic [2:0]  reserved2;     // 15:13 保留
        logic [2:0]  rxftcfg;       // 12:10: RXFIFO 阈值配置
        logic        rxftie;        // 9: RXFIFO 阈值中断使能
        logic        rxffie;        // 8: RXFIFO 满中断使能
        logic        txfeie;        // 7: TXFIFO 空中断使能
        logic        ereie;         // 6: 加密寄存器空中断使能
        logic        drneie;        // 5: 解密寄存器非空中断使能
        logic        txeie;         // 4: 发送寄存器空中断使能
        logic        tcie;          // 3: 发送完成中断使能
        logic        rxneie;        // 2: 接收寄存器非空中断使能
        logic        idleie;        // 1: IDLE 中断使能
        logic        eie;           // 0: 错误中断使能
    } cr2_reg_t;

    // =========================================================================
    // Baud Rate Register (BRR) - Offset 0x08
    // =========================================================================
    typedef struct packed {
        logic [15:0] reserved;      // 31:16 保留
        logic [11:0] mantissa;      // 15:4: 整数部分
        logic [3:0]  fraction;      // 3:0: 小数部分
    } brr_reg_t;

    // =========================================================================
    // Interrupt Status Register (ISR) - Offset 0x0C
    // =========================================================================
    typedef struct packed {
        logic [17:0] reserved;      // 31:14 保留
        logic        txft;          // 13: TXFIFO 阈值标志
        logic        rxft;          // 12: RXFIFO 阈值标志
        logic        rxff;          // 11: RXFIFO 满
        logic        txfe;          // 10: TXFIFO 空
        logic        busy;          // 9: 忙标志
        logic        ere;           // 8: 加密寄存器空
        logic        drne;          // 7: 解密寄存器非空
        logic        txe;           // 6: 发送寄存器空
        logic        tc;            // 5: 发送完成
        logic        rxne;          // 4: 接收寄存器非空
        logic        idle;          // 3: 线路空闲
        logic        ore;           // 2: 溢出错误
        logic        fe;            // 1: 帧错误
        logic        pe;            // 0: 校验错误
    } isr_reg_t;

    // =========================================================================
    // Interrupt Clear Register (ICR) - Offset 0x10
    // 用于产生清除脉冲
    // =========================================================================
    typedef struct packed {
        logic [26:0] reserved;      // 31:5
        logic        tccf;          // 4: 清除 TC
        logic        idlecf;        // 3: 清除 IDLE
        logic        orecf;         // 2: 清除 ORE
        logic        fecf;          // 1: 清除 FE
        logic        pecf;          // 0: 清除 PE
    } icr_reg_t;

endpackage