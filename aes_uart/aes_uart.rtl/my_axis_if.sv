// SPDX-License-Identifier: MIT
/*
 * AXI4-Stream Interface
 * Based on Xilinx AXI4-Stream specification
 */

`ifndef MY_AXIS_IF_SV
`define MY_AXIS_IF_SV

interface my_axis_if #(
    parameter DATA_W = 8
)
();
    logic [DATA_W-1:0]      tdata;
    logic [(DATA_W/8)-1:0]  tkeep;
    logic                   tlast;
    logic                   tvalid;
    logic                   tready;

    // Master modport (transmitter)
    modport master (
        output tdata, tkeep, tlast, tvalid,
        input  tready
    );

    // Slave modport (receiver)
    modport slave (
        input  tdata, tkeep, tlast, tvalid,
        output tready
    );

endinterface : my_axis_if

`endif
