
module ethernet_top
 #(parameter C_S00_AXI_DATA_WIDTH = 32
   , parameter C_S00_AXI_ADDR_WIDTH = 32
   )
  (input wire                                    aclk
   , input wire                                  aresetn

   , input wire                                  clk250
   , input wire                                  clk250_reset
   , input wire                                  tx_clk_gen_reset

   , output wire                                 tx_clk
   , input wire                                  tx_reset

   , output wire                                 rx_clk
   , input wire                                  rx_reset

   , input wire                                  iodelay_ref_clk

   , input wire [C_S00_AXI_ADDR_WIDTH-1:0]       s_axil_awaddr
   , input wire [2:0]                            s_axil_awprot
   , input wire                                  s_axil_awvalid
   , output wire                                 s_axil_awready

   , input wire [C_S00_AXI_DATA_WIDTH-1:0]       s_axil_wdata
   , input wire [(C_S00_AXI_DATA_WIDTH>>3)-1:0]  s_axil_wstrb
   , input wire                                  s_axil_wvalid
   , output wire                                 s_axil_wready

   , output wire [1:0]                           s_axil_bresp
   , output wire                                 s_axil_bvalid
   , input wire                                  s_axil_bready

   , input wire [C_S00_AXI_ADDR_WIDTH-1:0]       s_axil_araddr
   , input wire [2:0]                            s_axil_arprot
   , input wire                                  s_axil_arvalid
   , output wire                                 s_axil_arready

   , output wire [C_S00_AXI_DATA_WIDTH-1:0]      s_axil_rdata
   , output wire [1:0]                           s_axil_rresp
   , output wire                                 s_axil_rvalid
   , input wire                                  s_axil_rready

   , input wire                                  rgmii_rx_clk
   , input wire  [3:0]                           rgmii_rxd
   , input wire                                  rgmii_rx_ctl
   , output wire                                 rgmii_tx_clk
   , output wire [3:0]                           rgmii_txd
   , output wire                                 rgmii_tx_ctl

   , output wire                                 irq
   );

  bsg_axil_ethernet
   #(.axil_data_width_p(C_S00_AXI_DATA_WIDTH)
     ,.axil_addr_width_p(C_S00_AXI_ADDR_WIDTH)
     )
   ethernet
    (.clk_i(aclk)
     ,.reset_i(~aresetn)

     ,.clk250_i(clk250)
     ,.clk250_reset_i(clk250_reset)
     ,.tx_clk_gen_reset_i(tx_clk_gen_reset)

     ,.tx_clk_i(tx_clk)
     ,.tx_reset_i(tx_reset)

     ,.rx_clk(rx_clk)
     ,.rx_reset(rx_reset)

     ,.iodelay_ref_clk_i(iodelay_ref_clk)

     ,.s_axil_awaddr_i(s_axil_awaddr)
     ,.s_axil_awprot_i(s_axil_awprot)
     ,.s_axil_awvalid_i(s_axil_awvalid)
     ,.s_axil_awready_o(s_axil_awready)

     ,.s_axil_wdata_i(s_axil_wdata)
     ,.s_axil_wstrb_i(s_axil_wstrb)
     ,.s_axil_wvalid_i(s_axil_wvalid)
     ,.s_axil_wready_o(s_axil_wready)

     ,.s_axil_bresp_o(s_axil_bresp)
     ,.s_axil_bvalid_o(s_axil_bvalid)
     ,.s_axil_bready_i(s_axil_bready)

     ,.s_axil_araddr_i(s_axil_araddr)
     ,.s_axil_arprot_i(s_axil_arprot)
     ,.s_axil_arvalid_i(s_axil_arvalid)
     ,.s_axil_arready_o(s_axil_arready)

     ,.s_axil_rdata_o(s_axil_rdata)
     ,.s_axil_rresp_o(s_axil_rresp)
     ,.s_axil_rvalid_o(s_axil_rvalid)
     ,.s_axil_rready_i(s_axil_rready)

     ,.rgmii_rx_clk_i(rgmii_rx_clk)
     ,.rgmii_rxd_i(rgmii_rxd)
     ,.rgmii_rx_ctl_i(rgmii_rx_ctl)
     ,.rgmii_tx_clk_o(rgmii_tx_clk)
     ,.rgmii_txd_o(rgmii_txd)
     ,.rgmii_tx_ctl_o(rgmii_tx_ctl)

     ,.irq_o(irq)
     );


endmodule

