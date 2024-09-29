
module debug_top
 #(parameter C_M00_AXI_DATA_WIDTH = 32
   , parameter C_M00_AXI_ADDR_WIDTH = 32
   , parameter C_S00_AXI_DATA_WIDTH = 32
   , parameter C_S00_AXI_ADDR_WIDTH = 32
   , parameter DM_BUS_WIDTH = 32
   )
  (input wire                                    aclk
   , input wire                                  aresetn

   //====================== AXI-4 LITE =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , output wire [C_M00_AXI_ADDR_WIDTH-1:0]      m_axil_awaddr
   , output wire [2:0]                           m_axil_awprot
   , output wire                                 m_axil_awvalid
   , input wire                                  m_axil_awready

   // WRITE DATA CHANNEL SIGNALS
   , output wire [C_M00_AXI_DATA_WIDTH-1:0]      m_axil_wdata
   , output wire [(C_M00_AXI_DATA_WIDTH>>3)-1:0] m_axil_wstrb
   , output wire                                 m_axil_wvalid
   , input wire                                  m_axil_wready

   // WRITE RESPONSE CHANNEL SIGNALS
   , input wire [1:0]                            m_axil_bresp
   , input wire                                  m_axil_bvalid
   , output wire                                 m_axil_bready

   // READ ADDRESS CHANNEL SIGNALS
   , output wire [C_M00_AXI_ADDR_WIDTH-1:0]      m_axil_araddr
   , output wire [2:0]                           m_axil_arprot
   , output wire                                 m_axil_arvalid
   , input wire                                  m_axil_arready

   // READ DATA CHANNEL SIGNALS
   , input wire [C_M00_AXI_DATA_WIDTH-1:0]       m_axil_rdata
   , input wire [1:0]                            m_axil_rresp
   , input wire                                  m_axil_rvalid
   , output wire                                 m_axil_rready

   , input wire [C_S00_AXI_ADDR_WIDTH-1:0]       s_axil_awaddr
   , input wire [2:0]                            s_axil_awprot
   , input wire                                  s_axil_awvalid
   , output wire                                 s_axil_awready

   // WRITE DATA CHANNEL SIGNALS
   , input wire [C_S00_AXI_DATA_WIDTH-1:0]       s_axil_wdata
   , input wire [(C_S00_AXI_DATA_WIDTH>>3)-1:0]  s_axil_wstrb
   , input wire                                  s_axil_wvalid
   , output wire                                 s_axil_wready

   // WRITE RESPONSE CHANNEL SIGNALS
   , output wire [1:0]                           s_axil_bresp
   , output wire                                 s_axil_bvalid
   , input wire                                  s_axil_bready

   // READ ADDRESS CHANNEL SIGNALS
   , input wire [C_S00_AXI_ADDR_WIDTH-1:0]       s_axil_araddr
   , input wire [2:0]                            s_axil_arprot
   , input wire                                  s_axil_arvalid
   , output wire                                 s_axil_arready

   // READ DATA CHANNEL SIGNALS
   , output wire [C_S00_AXI_DATA_WIDTH-1:0]      s_axil_rdata
   , output wire [1:0]                           s_axil_rresp
   , output wire                                 s_axil_rvalid
   , input wire                                  s_axil_rready
   );

  bsg_axil_debug
   #(.m_axil_data_width_p(C_M00_AXI_DATA_WIDTH)
     ,.m_axil_addr_width_p(C_M00_AXI_ADDR_WIDTH)
     ,.s_axil_data_width_p(C_S00_AXI_DATA_WIDTH)
     ,.s_axil_addr_width_p(C_S00_AXI_ADDR_WIDTH)
     ,.bus_width_p(DM_BUS_WIDTH)
     )
   debug
    (.clk_i(aclk)
     ,.reset_i(~aresetn)

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
     );

endmodule

