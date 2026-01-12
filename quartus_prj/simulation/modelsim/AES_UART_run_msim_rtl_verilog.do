transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/uart/rtl {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/uart/rtl/uart_brg.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/port {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/port/taxi_axis_if.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/port {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/port/taxi_axil_if.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/axilregs/rtl {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/axilregs/rtl/axilregs_pkg.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher/InvSubBytes.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher/InvShiftRows.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher/InvSBox.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher/InvMixColumns.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher/InvAESRound.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/common {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/common/SBox.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/common {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/common/KeyExpander.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/common {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/common/AddRoundKey.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher/SubBytes.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher/ShiftRows.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher/MixColumns.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher/AESRound.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/uart/rtl {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/uart/rtl/uart_tx.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/uart/rtl {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/uart/rtl/uart_rx.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/uart/rtl {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/uart/rtl/uart.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/port {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/port/axis_mux.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/fifo/rtl {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/fifo/rtl/fifo.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/axilregs/rtl {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/axilregs/rtl/axil_regs.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/invcipher/InvAESCipher.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/aescore/rtl/cipher/AESCipher.sv}
vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/AES_UART {D:/GitHub_Repository/aes_uart_ipcore/AES_UART/AES_UART.sv}

vlog -sv -work work +incdir+D:/GitHub_Repository/aes_uart_ipcore/quartus_prj/../../../FPGA/Project/quartus/AES_UART/AES_UART {D:/GitHub_Repository/aes_uart_ipcore/quartus_prj/../../../FPGA/Project/quartus/AES_UART/AES_UART/tb_AES_UART.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  tb_AES_UART

add wave *
view structure
view signals
run 10 ms
