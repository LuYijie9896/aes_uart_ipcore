	component jtag_axi_sys is
		port (
			axil_master_awid     : out std_logic_vector(7 downto 0);                     -- awid
			axil_master_awaddr   : out std_logic_vector(31 downto 0);                    -- awaddr
			axil_master_awlen    : out std_logic_vector(7 downto 0);                     -- awlen
			axil_master_awsize   : out std_logic_vector(2 downto 0);                     -- awsize
			axil_master_awburst  : out std_logic_vector(1 downto 0);                     -- awburst
			axil_master_awlock   : out std_logic_vector(0 downto 0);                     -- awlock
			axil_master_awcache  : out std_logic_vector(3 downto 0);                     -- awcache
			axil_master_awprot   : out std_logic_vector(2 downto 0);                     -- awprot
			axil_master_awqos    : out std_logic_vector(3 downto 0);                     -- awqos
			axil_master_awregion : out std_logic_vector(3 downto 0);                     -- awregion
			axil_master_awvalid  : out std_logic;                                        -- awvalid
			axil_master_awready  : in  std_logic                     := 'X';             -- awready
			axil_master_wdata    : out std_logic_vector(31 downto 0);                    -- wdata
			axil_master_wstrb    : out std_logic_vector(3 downto 0);                     -- wstrb
			axil_master_wlast    : out std_logic;                                        -- wlast
			axil_master_wvalid   : out std_logic;                                        -- wvalid
			axil_master_wready   : in  std_logic                     := 'X';             -- wready
			axil_master_bid      : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- bid
			axil_master_bresp    : in  std_logic_vector(1 downto 0)  := (others => 'X'); -- bresp
			axil_master_bvalid   : in  std_logic                     := 'X';             -- bvalid
			axil_master_bready   : out std_logic;                                        -- bready
			axil_master_arid     : out std_logic_vector(7 downto 0);                     -- arid
			axil_master_araddr   : out std_logic_vector(31 downto 0);                    -- araddr
			axil_master_arlen    : out std_logic_vector(7 downto 0);                     -- arlen
			axil_master_arsize   : out std_logic_vector(2 downto 0);                     -- arsize
			axil_master_arburst  : out std_logic_vector(1 downto 0);                     -- arburst
			axil_master_arlock   : out std_logic_vector(0 downto 0);                     -- arlock
			axil_master_arcache  : out std_logic_vector(3 downto 0);                     -- arcache
			axil_master_arprot   : out std_logic_vector(2 downto 0);                     -- arprot
			axil_master_arqos    : out std_logic_vector(3 downto 0);                     -- arqos
			axil_master_arregion : out std_logic_vector(3 downto 0);                     -- arregion
			axil_master_arvalid  : out std_logic;                                        -- arvalid
			axil_master_arready  : in  std_logic                     := 'X';             -- arready
			axil_master_rid      : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- rid
			axil_master_rdata    : in  std_logic_vector(31 downto 0) := (others => 'X'); -- rdata
			axil_master_rresp    : in  std_logic_vector(1 downto 0)  := (others => 'X'); -- rresp
			axil_master_rlast    : in  std_logic                     := 'X';             -- rlast
			axil_master_rvalid   : in  std_logic                     := 'X';             -- rvalid
			axil_master_rready   : out std_logic;                                        -- rready
			clk_clk              : in  std_logic                     := 'X';             -- clk
			reset_reset_n        : in  std_logic                     := 'X'              -- reset_n
		);
	end component jtag_axi_sys;

	u0 : component jtag_axi_sys
		port map (
			axil_master_awid     => CONNECTED_TO_axil_master_awid,     -- axil_master.awid
			axil_master_awaddr   => CONNECTED_TO_axil_master_awaddr,   --            .awaddr
			axil_master_awlen    => CONNECTED_TO_axil_master_awlen,    --            .awlen
			axil_master_awsize   => CONNECTED_TO_axil_master_awsize,   --            .awsize
			axil_master_awburst  => CONNECTED_TO_axil_master_awburst,  --            .awburst
			axil_master_awlock   => CONNECTED_TO_axil_master_awlock,   --            .awlock
			axil_master_awcache  => CONNECTED_TO_axil_master_awcache,  --            .awcache
			axil_master_awprot   => CONNECTED_TO_axil_master_awprot,   --            .awprot
			axil_master_awqos    => CONNECTED_TO_axil_master_awqos,    --            .awqos
			axil_master_awregion => CONNECTED_TO_axil_master_awregion, --            .awregion
			axil_master_awvalid  => CONNECTED_TO_axil_master_awvalid,  --            .awvalid
			axil_master_awready  => CONNECTED_TO_axil_master_awready,  --            .awready
			axil_master_wdata    => CONNECTED_TO_axil_master_wdata,    --            .wdata
			axil_master_wstrb    => CONNECTED_TO_axil_master_wstrb,    --            .wstrb
			axil_master_wlast    => CONNECTED_TO_axil_master_wlast,    --            .wlast
			axil_master_wvalid   => CONNECTED_TO_axil_master_wvalid,   --            .wvalid
			axil_master_wready   => CONNECTED_TO_axil_master_wready,   --            .wready
			axil_master_bid      => CONNECTED_TO_axil_master_bid,      --            .bid
			axil_master_bresp    => CONNECTED_TO_axil_master_bresp,    --            .bresp
			axil_master_bvalid   => CONNECTED_TO_axil_master_bvalid,   --            .bvalid
			axil_master_bready   => CONNECTED_TO_axil_master_bready,   --            .bready
			axil_master_arid     => CONNECTED_TO_axil_master_arid,     --            .arid
			axil_master_araddr   => CONNECTED_TO_axil_master_araddr,   --            .araddr
			axil_master_arlen    => CONNECTED_TO_axil_master_arlen,    --            .arlen
			axil_master_arsize   => CONNECTED_TO_axil_master_arsize,   --            .arsize
			axil_master_arburst  => CONNECTED_TO_axil_master_arburst,  --            .arburst
			axil_master_arlock   => CONNECTED_TO_axil_master_arlock,   --            .arlock
			axil_master_arcache  => CONNECTED_TO_axil_master_arcache,  --            .arcache
			axil_master_arprot   => CONNECTED_TO_axil_master_arprot,   --            .arprot
			axil_master_arqos    => CONNECTED_TO_axil_master_arqos,    --            .arqos
			axil_master_arregion => CONNECTED_TO_axil_master_arregion, --            .arregion
			axil_master_arvalid  => CONNECTED_TO_axil_master_arvalid,  --            .arvalid
			axil_master_arready  => CONNECTED_TO_axil_master_arready,  --            .arready
			axil_master_rid      => CONNECTED_TO_axil_master_rid,      --            .rid
			axil_master_rdata    => CONNECTED_TO_axil_master_rdata,    --            .rdata
			axil_master_rresp    => CONNECTED_TO_axil_master_rresp,    --            .rresp
			axil_master_rlast    => CONNECTED_TO_axil_master_rlast,    --            .rlast
			axil_master_rvalid   => CONNECTED_TO_axil_master_rvalid,   --            .rvalid
			axil_master_rready   => CONNECTED_TO_axil_master_rready,   --            .rready
			clk_clk              => CONNECTED_TO_clk_clk,              --         clk.clk
			reset_reset_n        => CONNECTED_TO_reset_reset_n         --       reset.reset_n
		);

