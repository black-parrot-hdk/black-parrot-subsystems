
module uart_bridge_top
 #(parameter integer C_M00_AXI_DATA_WIDTH = 32
   , parameter integer C_M00_AXI_ADDR_WIDTH = 10
   , parameter integer C_GP0_AXI_DATA_WIDTH = 32
   , parameter integer C_GP0_AXI_ADDR_WIDTH = 28
   , parameter integer UART_BASE_ADDR = 32'h1100000
   )
   (input wire                                  aclk
    , input wire                                aresetn

    // WRITE ADDRESS CHANNEL SIGNALS
    , output wire [C_M00_AXI_ADDR_WIDTH-1:0]    m_axil_awaddr_o
    , output wire [2:0]                         m_axil_awprot_o
    , output wire                               m_axil_awvalid_o
    , input wire                                m_axil_awready_i

    // WRITE DATA CHANNEL SIGNALS
    , output wire [C_M00_AXI_DATA_WIDTH-1:0]    m_axil_wdata_o
    , output wire [C_M00_AXI_DATA_WIDTH/8-1:0]  m_axil_wstrb_o
    , output wire                               m_axil_wvalid_o
    , input wire                                m_axil_wready_i

    // WRITE RESPONSE CHANNEL SIGNALS
    , input [1:0]                               m_axil_bresp_i
    , input wire                                m_axil_bvalid_i
    , output wire                               m_axil_bready_o

    // READ ADDRESS CHANNEL SIGNALS
    , output wire [C_M00_AXI_ADDR_WIDTH-1:0]    m_axil_araddr_o
    , output wire [2:0]                         m_axil_arprot_o
    , output wire                               m_axil_arvalid_o
    , input wire                                m_axil_arready_i

    // READ DATA CHANNEL SIGNALS
    , input [C_M00_AXI_DATA_WIDTH-1:0]          m_axil_rdata_i
    , input [1:0]                               m_axil_rresp_i
    , input wire                                m_axil_rvalid_i
    , output wire                               m_axil_rready_o

    // WRITE ADDRESS CHANNEL SIGNALS
    , output wire [C_GP0_AXI_ADDR_WIDTH-1:0]    gp0_axil_awaddr_o
    , output wire [2:0]                         gp0_axil_awprot_o
    , output wire                               gp0_axil_awvalid_o
    , input wire                                gp0_axil_awready_i

    // WRITE DATA CHANNEL SIGNALS
    , output wire [C_GP0_AXI_DATA_WIDTH-1:0 ]   gp0_axil_wdata_o
    , output wire [C_GP0_AXI_DATA_WIDTH/8-1:0]  gp0_axil_wstrb_o
    , output wire                               gp0_axil_wvalid_o
    , input wire                                gp0_axil_wready_i

    // WRITE RESPONSE CHANNEL SIGNALS
    , input [1:0]                               gp0_axil_bresp_i
    , input wire                                gp0_axil_bvalid_i
    , output wire                               gp0_axil_bready_o

    // READ ADDRESS CHANNEL SIGNALS
    , output wire [C_GP0_AXI_ADDR_WIDTH-1:0]    gp0_axil_araddr_o
    , output wire [2:0]                         gp0_axil_arprot_o
    , output wire                               gp0_axil_arvalid_o
    , input wire                                gp0_axil_arready_i

    // READ DATA CHANNEL SIGNALS
    , input [C_GP0_AXI_DATA_WIDTH-1:0]          gp0_axil_rdata_i
    , input [1:0]                               gp0_axil_rresp_i
    , input wire                                gp0_axil_rvalid_i
    , output wire                               gp0_axil_rready_o
    );

  bsg_zynq_uart_bridge
   #(.m_axil_data_width_p(C_M00_AXI_DATA_WIDTH)
     ,.m_axil_addr_width_p(C_M00_AXI_ADDR_WIDTH)
     ,.uart_base_addr_p(UART_BASE_ADDR)
     ,.gp0_axil_data_width_p(C_GP0_AXI_DATA_WIDTH)
     ,.gp0_axil_addr_width_p(C_GP0_AXI_ADDR_WIDTH)
     )
   bridge
    (.clk_i(aclk)
     ,.reset_i(~aresetn)

     ,.m_axil_awaddr_o(m01_axi_awaddr)
     ,.m_axil_awprot_o(m01_axi_awprot)
     ,.m_axil_awvalid_o(m01_axi_awvalid)
     ,.m_axil_awready_i(m01_axi_awready)

     ,.m_axil_wdata_o(m01_axi_wdata)
     ,.m_axil_wstrb_o(m01_axi_wstrb)
     ,.m_axil_wvalid_o(m01_axi_wvalid)
     ,.m_axil_wready_i(m01_axi_wready)

     ,.m_axil_bresp_i(m01_axi_bresp)
     ,.m_axil_bvalid_i(m01_axi_bvalid)
     ,.m_axil_bready_o(m01_axi_bready)

     ,.m_axil_araddr_o(m01_axi_araddr)
     ,.m_axil_arprot_o(m01_axi_arprot)
     ,.m_axil_arvalid_o(m01_axi_arvalid)
     ,.m_axil_arready_i(m01_axi_arready)

     ,.m_axil_rdata_i(m01_axi_rdata)
     ,.m_axil_rresp_i(m01_axi_rresp)
     ,.m_axil_rvalid_i(m01_axi_rvalid)
     ,.m_axil_rready_o(m01_axi_rready)

     ,.gp0_axil_awaddr_o(gp0_axil_awaddr)
     ,.gp0_axil_awprot_o(gp0_axil_awprot)
     ,.gp0_axil_awvalid_o(gp0_axil_awvalid)
     ,.gp0_axil_awready_i(gp0_axil_awready)

     ,.gp0_axil_wdata_o(gp0_axil_wdata)
     ,.gp0_axil_wstrb_o(gp0_axil_wstrb)
     ,.gp0_axil_wvalid_o(gp0_axil_wvalid)
     ,.gp0_axil_wready_i(gp0_axil_wready)

     ,.gp0_axil_bresp_i(gp0_axil_bresp)
     ,.gp0_axil_bvalid_i(gp0_axil_bvalid)
     ,.gp0_axil_bready_o(gp0_axil_bready)

     ,.gp0_axil_araddr_o(gp0_axil_araddr)
     ,.gp0_axil_arprot_o(gp0_axil_arprot)
     ,.gp0_axil_arvalid_o(gp0_axil_arvalid)
     ,.gp0_axil_arready_i(gp0_axil_arready)

     ,.gp0_axil_rdata_i(gp0_axil_rdata)
     ,.gp0_axil_rresp_i(gp0_axil_rresp)
     ,.gp0_axil_rvalid_i(gp0_axil_rvalid)
     ,.gp0_axil_rready_o(gp0_axil_rready)
     );  

endmodule

