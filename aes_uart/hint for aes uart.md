# AES_UART IP Core 开发指南与寄存器定义

## 1. 项目背景与开发规范 (Project Rules)

请仔细阅读以下规则，并在后续代码生成中严格遵守：

### 1.1 平台与语言

* 
**开发平台**：Xilinx Vitis 2025.2 。


* 
**编程语言**：SystemVerilog 。


* **代码风格**：
* 必须符合 Xilinx 平台规则 。


* 代码逻辑尽可能通用，避免过度依赖特定平台原语 。


* 
**注释**：必须使用**中文**，且保持简洁 。





### 1.2 验证策略 (Testbench Strategy)

* 
**步进式测试**：严禁一次性生成大量测试代码。必须按照指令，每次仅生成针对特定功能的验证代码 。


* 
**单一文件架构**：所有功能测试必须集成在同一个 `tb` 文件中 。


* 
**独立控制**：每个功能测试块必须相互独立（例如使用 `task` 或 `initial` 块配合宏定义/开关），确保可以随时启动或关闭任意测试，且能复现先前的测试 。


* 
**输出信息**：仿真打印信息需简洁、直观 。



---

## 2. 寄存器映射详解 (Register Mapping)

IP 核包含以下寄存器，基地址偏移如下：

### 2.1 Control Register 1 (AES_UART_CR1)

* 
**Address Offset**: `0x00` 


* **Reset Value**: `0x00000000`

| Bit Range | Name | Access | Description |
| --- | --- | --- | --- |
| 31:17 | Reserved | - | 保留 |
| 16:15 | **WM[1:0]** | RW | <br>**工作模式 (Work Mode)** 

<br>

<br>00: 正常模式 (Manual)<br>

<br>01: 自动模式1 (自动接收数据->加密->发出)<br>

<br>10: 自动模式2 (自动接收加密数据->解密->发出)<br>

<br>11: 回环模式 (Loopback) |
| 14:13 | **EL[1:0]** | RW | <br>**加密密钥长度 (Encryption Key Length)** 

<br>

<br>00: 128-bit, 01: 192-bit, 10: 256-bit |
| 12:11 | **DL[1:0]** | RW | <br>**解密密钥长度 (Decryption Key Length)** 

<br>

<br>00: 128-bit, 01: 192-bit, 10: 256-bit |
| 10:9 | **WL[1:0]** | RW | <br>**数据位长度 (Word Length)** 

<br>

<br>00: 8-bit, 01: 7-bit, 10: 6-bit, 11: 5-bit |
| 8:7 | **STOP[1:0]** | RW | <br>**停止位 (Stop Bits)** 

<br>

<br>00: 1-bit, 01: 1.5-bit, 10: 2-bit |
| 6 | **PCE** | RW | <br>**校验位使能 (Parity Control Enable)** 

<br>

<br>0: 失能, 1: 使能 |
| 5 | **PS** | RW | <br>**校验选择 (Parity Selection)** 

<br>

<br>0: 偶校验, 1: 奇校验 |
| 4 | **EE** | RW | <br>**加密使能 (Encryption Enable)** 

<br>

<br>0: 失能, 1: 使能 |
| 3 | **DE** | RW | <br>**解密使能 (Decryption Enable)** 

<br>

<br>0: 失能, 1: 使能 |
| 2 | **TE** | RW | <br>**发送使能 (TX Enable)** 

<br>

<br>0: 失能, 1: 使能 |
| 1 | **RE** | RW | <br>**接收使能 (RX Enable)** 

<br>

<br>0: 失能, 1: 使能 |
| 0 | **AUE** | RW | <br>**全局使能 (AESUART Enable)** 

<br>

<br>**注意**: 模块使用前必须置 1。 |

### 2.2 Control Register 2 (AES_UART_CR2)

* 
**Address Offset**: `0x04` 



| Bit Range | Name | Access | Description |
| --- | --- | --- | --- |
| 19:17 | **TXFTCFG[2:0]** | RW | <br>**发送 FIFO 阈值配置** 

<br>

<br>000: 1/8, 001: 1/4, 010: 1/2, 011: 3/4, 100: 7/8, 101: Empty |
| 16 | **TXFTIE** | RW | <br>**发送 FIFO 阈值中断使能** 

 |
| 12:10 | **RXFTCFG[2:0]** | RW | <br>**接收 FIFO 阈值配置** 

<br>

<br>000: 1/8, 001: 1/4, 010: 1/2, 011: 3/4, 100: 7/8, 101: Full |
| 9 | **RXFTIE** | RW | <br>**接收 FIFO 阈值中断使能** 

 |
| 8 | **RXFFIE** | RW | <br>**接收 FIFO 满中断使能** 

 |
| 7 | **TXFEIE** | RW | <br>**发送 FIFO 空中断使能** 

 |
| 6 | **EREIE** | RW | <br>**加密寄存器空中断使能** 

 |
| 5 | **DRNEIE** | RW | <br>**解密寄存器非空中断使能** 

 |
| 4 | **TXEIE** | RW | <br>**发送寄存器空中断使能** 

 |
| 3 | **TCIE** | RW | <br>**发送完成中断使能** 

 |
| 2 | **RXNEIE** | RW | <br>**接收寄存器非空中断使能** 

 |
| 1 | **IDLEIE** | RW | <br>**空闲中断使能** 

 |
| 0 | **EIE** | RW | <br>**错误中断使能** (PE/FE/ORE) 

 |

### 2.3 Baud Rate Register (AES_UART_BRR)

* 
**Address Offset**: `0x08` 



| Bit Range | Name | Access | Description |
| --- | --- | --- | --- |
| 15:4 | **DIV_Mantissa[11:0]** | RW | 波特率分频系数整数部分 

 |
| 3:0 | **DIV_Fraction[3:0]** | RW | 波特率分频系数小数部分 

 |

### 2.4 Interrupt & Status Register (AES_UART_ISR)

* 
**Address Offset**: `0x0C` 



| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| 13 | **TXFT** | R | TXFIFO 达到阈值标志 

 |
| 12 | **RXFT** | R | RXFIFO 达到阈值标志 

 |
| 11 | **RXFF** | R | RXFIFO 满标志 

 |
| 10 | **TXFE** | R | TXFIFO 空标志 

 |
| 9 | **BUSY** | R | 忙标志 

 |
| 8 | **ERE** | R | <br>**加密寄存器空 (Encryption Register Empty)** 

<br>

<br>1 = 允许写入新明文。 |
| 7 | **DRNE** | R | <br>**解密寄存器非空 (Decryption Register Not Empty)** 

<br>

<br>1 = 有解密后的明文待读取。 |
| 6 | **TXE** | R | 发送寄存器空 

 |
| 5 | **TC** | R | 发送完成 (Transmission Complete) 

 |
| 4 | **RXNE** | R | 接收寄存器非空 

 |
| 3 | **IDLE** | R | 线路空闲检测 

 |
| 2 | **ORE** | R | 溢出错误 (Overrun Error) 

 |
| 1 | **FE** | R | 帧错误 (Framing Error) 

 |
| 0 | **PE** | R | 校验错误 (Parity Error) 

 |

### 2.5 Interrupt Clear Register (AES_UART_ICR)

* 
**Address Offset**: `0x10` 


* **功能**: 写 1 清除 ISR 中对应的标志位。

| Bit | Name | Description |
| --- | --- | --- |
| 4 | **TCCF** | 清除 TC 标志 

 |
| 3 | **IDLECF** | 清除 IDLE 标志 

 |
| 2 | **ORECF** | 清除 ORE 标志 

 |
| 1 | **FECF** | 清除 FE 标志 

 |
| 0 | **PECF** | 清除 PE 标志 

 |

### 2.6 Data Registers

* 
**AES_UART_RDR (0x14)**: 接收数据寄存器 (只读)。用于**非解密模式**下接收数据 。


* 
**AES_UART_TDR (0x18)**: 发送数据寄存器 (读写)。用于**非加密模式**下发送数据 。



### 2.7 Key & Processing Registers (AES Core)

**注意：多字长寄存器遵循高位填充，低位补0原则。**

#### Encryption Keys (0x1C ~ 0x38)

* 
**AES_UART_EKR1~8**: 存放加密密钥。宽度需与 `EL` 设置匹配 。



#### Decryption Keys (0x3C ~ 0x58)

* 
**AES_UART_DKR1~8**: 存放解密密钥。宽度需与 `DL` 设置匹配 。



#### Encryption Plaintext Input (0x5C ~ 0x68)

* 
**AES_UART_EPR1~4**: 存放待加密明文 。


* 
**关键逻辑**: 数据必须由低地址向高地址写入。**当最高地址寄存器 (EPR4) 被写入后，硬件自动开启加密**，并将数据压入后级 。


* 
**状态检查**: 写入前需检查 `ISR[ERE]` 是否为 1 。



#### Decryption Plaintext Output (0x6C ~ 0x78)

* 
**AES_UART_DPR1~4**: 存放解密后的明文 。


* 
**关键逻辑**: 数据必须由低地址向高地址读取。**当最高地址寄存器 (DPR4) 被读取后，硬件自动更新下一组解密数据** 。


* 
**状态检查**: 读取前需检查 `ISR[DRNE]` 是否为 1 。


