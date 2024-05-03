
module watchdog_top
 #(// The period of the watchdog (default to 1s @2.5MHz)
     parameter integer WATCHDOG_PERIOD      = 250000000
   , parameter integer WATCHDOG_ADDRESS     = 32'h0f00000
   , parameter integer C_M00_AXI_DATA_WIDTH = 32
   , parameter integer C_M00_AXI_ADDR_WIDTH = 28
   )
  (input wire                                        aclk
   , input wire                                      aresetn

   , input wire                                      tag_clk
   , input wire                                      tag_data

   //====================== AXI-4 LITE =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , output wire [C_M00_AXI_ADDR_WIDTH-1:0]          m_axil_awaddr
   , output wire [2:0]                               m_axil_awprot
   , output wire                                     m_axil_awvalid
   , input wire                                      m_axil_awready

   // WRITE DATA CHANNEL SIGNALS
   , output wire [C_M00_AXI_DATA_WIDTH-1:0]          m_axil_wdata
   , output wire [C_M00_AXI_DATA_WIDTH/8-1:0]        m_axil_wstrb
   , output wire                                     m_axil_wvalid
   , input wire                                      m_axil_wready

   // WRITE RESPONSE CHANNEL SIGNALS
   , input wire [1:0]                                m_axil_bresp
   , input wire                                      m_axil_bvalid
   , output wire                                     m_axil_bready

   // READ ADDRESS CHANNEL SIGNALS
   , output wire [C_M00_AXI_ADDR_WIDTH-1:0]          m_axil_araddr
   , output wire [2:0]                               m_axil_arprot
   , output wire                                     m_axil_arvalid
   , input wire                                      m_axil_arready

   // READ DATA CHANNEL SIGNALS
   , input wire [C_M00_AXI_DATA_WIDTH-1:0]           m_axil_rdata
   , input wire [1:0]                                m_axil_rresp
   , input wire                                      m_axil_rvalid
   , output wire                                     m_axil_rready
   );

  bsg_axil_watchdog
   #(.watchdog_period_p(WATCHDOG_PERIOD)
     ,.watchdog_address_p(WATCHDOG_ADDRESS)
     ,.axil_data_width_p(C_M00_AXI_DATA_WIDTH)
     ,.axil_addr_width_p(C_M00_AXI_ADDR_WIDTH)
     )
   watchdog
    (.clk_i(aclk)
     ,.reset_i(~aresetn)

     ,.tag_clk_i(tag_clk)
     ,.tag_data_i(tag_data)
        
     ,.m_axil_awaddr_o(m_axil_awaddr)
     ,.m_axil_awprot_o(m_axil_awprot)
     ,.m_axil_awvalid_o(m_axil_awvalid)
     ,.m_axil_awready_i(m_axil_awready)

     ,.m_axil_wdata_o(m_axil_wdata)
     ,.m_axil_wstrb_o(m_axil_wstrb)
     ,.m_axil_wvalid_o(m_axil_wvalid)
     ,.m_axil_wready_i(m_axil_wready)

     ,.m_axil_bresp_i(m_axil_bresp)
     ,.m_axil_bvalid_i(m_axil_bvalid)
     ,.m_axil_bready_o(m_axil_bready)

     ,.m_axil_araddr_o(m_axil_araddr)
     ,.m_axil_arprot_o(m_axil_arprot)
     ,.m_axil_arvalid_o(m_axil_arvalid)
     ,.m_axil_arready_i(m_axil_arready)

     ,.m_axil_rdata_i(m_axil_rdata)
     ,.m_axil_rresp_i(m_axil_rresp)
     ,.m_axil_rvalid_i(m_axil_rvalid)
     ,.m_axil_rready_o(m_axil_rready)
     );

endmodule

