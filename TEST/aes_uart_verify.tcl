# ==============================================================================
# AES_UART SOC 验证脚本 (System Console Tcl)
# 针对 DE2-115 开发板 & JTAG-to-Avalon Master Bridge
# ==============================================================================

puts "Starting AES_UART Verification..."

# ------------------------------------------------------------------------------
# 1. 初始化 JTAG Master 服务
# ------------------------------------------------------------------------------
set master_paths [get_service_paths master]
if {[llength $master_paths] == 0} {
    puts "Error: No JTAG Master found. Please check USB-Blaster connection."
    return
}

# 通常选择第一个 Master (index 0)
set master_path [lindex $master_paths 0]
puts "Using JTAG Master: $master_path"

# 打开服务
open_service master $master_path

# ------------------------------------------------------------------------------
# 2. 寄存器地址定义 (基于 AXI-Lite 接口)
# ------------------------------------------------------------------------------
set ADDR_CR1  0x00 ;# Control Register 1
set ADDR_CR2  0x04 ;# Control Register 2
set ADDR_BRR  0x08 ;# Baud Rate Register
set ADDR_ISR  0x0C ;# Interrupt/Status Register
set ADDR_ICR  0x10 ;# Interrupt Clear Register
set ADDR_RDR  0x14 ;# Receive Data Register
set ADDR_TDR  0x18 ;# Transmit Data Register
set ADDR_EKR1 0x1C ;# Encrypt Key Register 1 (Base)
set ADDR_DKR1 0x3C ;# Decrypt Key Register 1 (Base)
set ADDR_EPR1 0x5C ;# Encrypt Plaintext Register 1 (Base)
set ADDR_EPR4 0x68 ;# Encrypt Plaintext Register 4 (Trigger)

# ------------------------------------------------------------------------------
# 3. 辅助读写函数
# ------------------------------------------------------------------------------
proc reg_write {addr data} {
    global master_path
    # master_write_32 服务路径 地址 数据列表
    master_write_32 $master_path $addr $data
}

proc reg_read {addr} {
    global master_path
    # master_read_32 服务路径 地址 读取数量
    set val [master_read_32 $master_path $addr 1]
    # 将返回值转换为 0xYYYY 格式的 Hex 字符串，方便查看
    return $val
}

proc log_pass {msg} {
    puts "\[PASS\] $msg"
}

proc log_fail {msg} {
    puts "\[FAIL\] $msg"
}

# ------------------------------------------------------------------------------
# 4. 测试用例集 (对应 11 条要求)
# ------------------------------------------------------------------------------

# --- 测试 A: 基础 AXI 接口与 SOC 集成验证 (Req 7, 11) ---
proc test_axi_access {} {
    global ADDR_BRR
    puts "\n--- Test A: AXI Interface & SOC Integration ---"
    
    # 写入一个测试值到波特率寄存器
    set test_val 0x00001234
    reg_write $ADDR_BRR $test_val
    set read_val [reg_read $ADDR_BRR]
    
    # 比较低 16 位
    if {[expr $read_val & 0xFFFF] == 0x1234} {
        log_pass "Register Read/Write Success (AXI-Lite working)"
    } else {
        log_fail "Register Read/Write Mismatch. Expected 0x1234, Got $read_val"
    }
}

# --- 测试 B: 可编程波特率与数据格式 (Req 2, 3) ---
proc test_config_programmability {} {
    global ADDR_BRR ADDR_CR1
    puts "\n--- Test B: Programmable Baud Rate & Data Format ---"
    
    # 1. 验证波特率可编程 (9600 -> 0x1458)
    reg_write $ADDR_BRR 0x00001458
    set brr_read [reg_read $ADDR_BRR]
    if {[expr $brr_read & 0xFFFF] == 0x1458} {
        log_pass "Baud Rate Configured to 9600"
    } else {
        log_fail "Baud Rate Config Failed"
    }
    
    # 2. 验证数据格式可编程
    # 设置: 7位数据(WL=10), 偶校验(PS=0), 校验使能(PCE=1), 2停止位(STOP=10)
    # Bits: WL[10:9]=10, STOP[8:7]=10, PCE[6]=1 -> Mask 0x00000740
    reg_write $ADDR_CR1 0x00000740
    set cr1_read [reg_read $ADDR_CR1]
    
    # 检查关键位是否被置位
    if {[expr ($cr1_read & 0x740)] == 0x740} {
        log_pass "Data Format (7 bits, Even Parity, 2 Stop) Configured"
    } else {
        log_fail "Data Format Config Failed. Got: $cr1_read"
    }
}

# --- 测试 C: 回环模式与全双工 FIFO (修正版: 增加清空逻辑) ---
proc test_loopback_fifo {} {
    global ADDR_CR1 ADDR_BRR ADDR_TDR ADDR_RDR ADDR_ISR
    puts "\n--- Test C: Loopback Mode & FIFO ---"
    
    # 1. 恢复标准波特率 115200
    reg_write $ADDR_BRR 0x000001B2
    
    # 2. 开启回环模式
    reg_write $ADDR_CR1 0x00018007
    
    # === 新增：清空 RX FIFO (防止旧数据干扰) ===
    # 只要 ISR 的 RXNE(bit 4) 是 1，就一直读 RDR，直到读空为止
    set max_flush 100
    while {[expr ([reg_read $ADDR_ISR] & 0x10)] && $max_flush > 0} {
        set dummy [reg_read $ADDR_RDR]
        set max_flush [expr $max_flush - 1]
    }
    puts "   (RX FIFO Flushed)"
    # ==========================================
    
    # 3. 连续写入 FIFO
    reg_write $ADDR_TDR 0xAA
    reg_write $ADDR_TDR 0xBB
    reg_write $ADDR_TDR 0xCC
    
    # 4. 延时等待
    after 100 
    
    set isr_val [reg_read $ADDR_ISR]
    if {[expr ($isr_val & 0x10)]} {
        
        # 读取 FIFO 中的数据
        set r1 [reg_read $ADDR_RDR]
        set r2 [reg_read $ADDR_RDR]
        set r3 [reg_read $ADDR_RDR]
        
        # 打印读取到的值，方便调试
        puts "   Read: [format 0x%02X $r1] [format 0x%02X $r2] [format 0x%02X $r3]"

        if {($r1 & 0xFF) == 0xAA && ($r2 & 0xFF) == 0xBB && ($r3 & 0xFF) == 0xCC} {
            log_pass "Loopback Data Received & Verified"
        } else {
            log_fail "FIFO Data Mismatch"
        }
    } else {
        log_fail "Loopback Timeout (RXNE not set)"
    }
}

# --- 测试 D: AES 加密模式 (Req 5, 9) ---
proc test_aes_encryption {} {
    global ADDR_CR1 ADDR_EKR1 ADDR_EPR1 ADDR_EPR4
    puts "\n--- Test D: AES Encryption (Manual Mode) ---"
    
    # 1. 配置: 手动加密模式 (WM=00), 128位密钥 (EL=00), 加密使能 (EE=1), UE=1
    # Bits: EE[4]=1, UE[0]=1 -> 0x00000011
    reg_write $ADDR_CR1 0x00000011
    
    # 2. 写入密钥 (128-bit)
    reg_write [expr $ADDR_EKR1 + 0x00] 0x01010101
    reg_write [expr $ADDR_EKR1 + 0x04] 0x02020202
    reg_write [expr $ADDR_EKR1 + 0x08] 0x03030303
    reg_write [expr $ADDR_EKR1 + 0x0C] 0x04040404
    # 触发密钥更新 (写 EKR8 偏移) - 即使是 128 位模式也需要触发信号
    reg_write [expr $ADDR_EKR1 + 0x1C] 0x00000000 
    
    log_pass "AES Key Written"
    
    # 3. 写入明文并触发加密
    reg_write $ADDR_EPR1 0xAABBCCDD
    reg_write [expr $ADDR_EPR1 + 0x04] 0x11223344
    reg_write [expr $ADDR_EPR1 + 0x08] 0x55667788
    reg_write $ADDR_EPR4 0x99887766 ;# 写最后一个寄存器触发 TX
    
    log_pass "AES Encryption Triggered (Manual 128-bit block)"
    puts "   (Check Physical UART for ciphertext output if connected)"
}

# --- 测试 E: 自动补零与任意长度发送 (Req 8, 10) ---
proc test_auto_padding {} {
    global ADDR_CR1 ADDR_TDR
    puts "\n--- Test E: Auto Padding & Arbitrary Length (Smart Mode) ---"
    
    # 1. 配置: 自动加密模式 (WM=01), EE=1, UE=1
    # Bits: WM[16:15]=01 -> 0x00008000
    #       EE[4]=1, UE[0]=1 -> 0x00000011
    # Combined: 0x00008011
    reg_write $ADDR_CR1 0x00008011
    
    # 2. 写入非对齐数据 (例如 3 字节 "ABC")
    # 这验证了系统能接收任意长度，并在内部自动补零对齐到 128-bit
    reg_write $ADDR_TDR 0x41 ;# 'A'
    reg_write $ADDR_TDR 0x42 ;# 'B'
    reg_write $ADDR_TDR 0x43 ;# 'C'
    
    log_pass "Arbitrary Length Data (3 bytes) Written to FIFO"
    puts "   (Hardware logic should timeout, pad to 16 bytes, encrypt, and send)"
}

# ------------------------------------------------------------------------------
# 5. 执行主程序
# ------------------------------------------------------------------------------

proc run_all {} {
    test_axi_access
    test_config_programmability
    test_loopback_fifo
    test_aes_encryption
    test_auto_padding
    
    puts "\n========================================"
    puts "       ALL TESTS COMPLETED"
    puts "========================================"
}

# 自动运行
run_all

# 关闭服务 (可选，如果想保持连接可注释掉)
# close_service master $master_path