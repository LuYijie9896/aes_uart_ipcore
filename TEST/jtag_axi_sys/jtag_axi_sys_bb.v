
module jtag_axi_sys (
	axil_master_awid,
	axil_master_awaddr,
	axil_master_awlen,
	axil_master_awsize,
	axil_master_awburst,
	axil_master_awlock,
	axil_master_awcache,
	axil_master_awprot,
	axil_master_awqos,
	axil_master_awregion,
	axil_master_awvalid,
	axil_master_awready,
	axil_master_wdata,
	axil_master_wstrb,
	axil_master_wlast,
	axil_master_wvalid,
	axil_master_wready,
	axil_master_bid,
	axil_master_bresp,
	axil_master_bvalid,
	axil_master_bready,
	axil_master_arid,
	axil_master_araddr,
	axil_master_arlen,
	axil_master_arsize,
	axil_master_arburst,
	axil_master_arlock,
	axil_master_arcache,
	axil_master_arprot,
	axil_master_arqos,
	axil_master_arregion,
	axil_master_arvalid,
	axil_master_arready,
	axil_master_rid,
	axil_master_rdata,
	axil_master_rresp,
	axil_master_rlast,
	axil_master_rvalid,
	axil_master_rready,
	clk_clk,
	reset_reset_n);	

	output	[7:0]	axil_master_awid;
	output	[31:0]	axil_master_awaddr;
	output	[7:0]	axil_master_awlen;
	output	[2:0]	axil_master_awsize;
	output	[1:0]	axil_master_awburst;
	output	[0:0]	axil_master_awlock;
	output	[3:0]	axil_master_awcache;
	output	[2:0]	axil_master_awprot;
	output	[3:0]	axil_master_awqos;
	output	[3:0]	axil_master_awregion;
	output		axil_master_awvalid;
	input		axil_master_awready;
	output	[31:0]	axil_master_wdata;
	output	[3:0]	axil_master_wstrb;
	output		axil_master_wlast;
	output		axil_master_wvalid;
	input		axil_master_wready;
	input	[7:0]	axil_master_bid;
	input	[1:0]	axil_master_bresp;
	input		axil_master_bvalid;
	output		axil_master_bready;
	output	[7:0]	axil_master_arid;
	output	[31:0]	axil_master_araddr;
	output	[7:0]	axil_master_arlen;
	output	[2:0]	axil_master_arsize;
	output	[1:0]	axil_master_arburst;
	output	[0:0]	axil_master_arlock;
	output	[3:0]	axil_master_arcache;
	output	[2:0]	axil_master_arprot;
	output	[3:0]	axil_master_arqos;
	output	[3:0]	axil_master_arregion;
	output		axil_master_arvalid;
	input		axil_master_arready;
	input	[7:0]	axil_master_rid;
	input	[31:0]	axil_master_rdata;
	input	[1:0]	axil_master_rresp;
	input		axil_master_rlast;
	input		axil_master_rvalid;
	output		axil_master_rready;
	input		clk_clk;
	input		reset_reset_n;
endmodule
