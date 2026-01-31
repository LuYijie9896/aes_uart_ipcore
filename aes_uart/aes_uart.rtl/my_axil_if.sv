// SPDX-License-Identifier: MIT
/*
 * AXI4-Lite Interface
 * Based on Xilinx AXI4-Lite specification
 */

`ifndef MY_AXIL_IF_SV
`define MY_AXIL_IF_SV

interface my_axil_if #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)
();
    // Write Address Channel
    logic [ADDR_W-1:0]      awaddr;
    logic [2:0]             awprot;
    logic                   awvalid;
    logic                   awready;
    
    // Write Data Channel
    logic [DATA_W-1:0]      wdata;
    logic [(DATA_W/8)-1:0]  wstrb;
    logic                   wvalid;
    logic                   wready;
    
    // Write Response Channel
    logic [1:0]             bresp;
    logic                   bvalid;
    logic                   bready;
    
    // Read Address Channel
    logic [ADDR_W-1:0]      araddr;
    logic [2:0]             arprot;
    logic                   arvalid;
    logic                   arready;
    
    // Read Data Channel
    logic [DATA_W-1:0]      rdata;
    logic [1:0]             rresp;
    logic                   rvalid;
    logic                   rready;

    // Master modport (for AXI master)
    modport master (
        output awaddr, awprot, awvalid, wdata, wstrb, wvalid, bready, araddr, arprot, arvalid, rready,
        input  awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid
    );

    // Slave modport (for AXI slave)
    modport slave (
        input  awaddr, awprot, awvalid, wdata, wstrb, wvalid, bready, araddr, arprot, arvalid, rready,
        output awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid
    );

endinterface : my_axil_if

`endif
