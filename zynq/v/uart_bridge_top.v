
module uart_bridge_top
 #(parameter integer C_UART_AXI_DATA_WIDTH = 32
   , parameter integer C_UART_AXI_ADDR_WIDTH = 12
   , parameter integer C_UI_AXI_DATA_WIDTH = 32
   , parameter integer C_UI_AXI_ADDR_WIDTH = 28
   )
   (input wire                                  aclk
    , input wire                                aresetn

    // WRITE ADDRESS CHANNEL SIGNALS
    , (* mark_debug = "true" *) output wire [C_UART_AXI_ADDR_WIDTH-1:0]   uart_axil_awaddr
    , (* mark_debug = "true" *) output wire [2:0]                         uart_axil_awprot
    , (* mark_debug = "true" *)  output wire                               uart_axil_awvalid
    , (* mark_debug = "true" *)  input wire                                uart_axil_awready

    // WRITE DATA CHANNEL SIGNALS
    , (* mark_debug = "true" *)  output wire [C_UART_AXI_DATA_WIDTH-1:0]   uart_axil_wdata
    , (* mark_debug = "true" *)  output wire [C_UART_AXI_DATA_WIDTH/8-1:0] uart_axil_wstrb
    , (* mark_debug = "true" *)  output wire                               uart_axil_wvalid
    , (* mark_debug = "true" *)  input wire                                uart_axil_wready

    // WRITE RESPONSE CHANNEL SIGNALS
    , (* mark_debug = "true" *)  input [1:0]                               uart_axil_bresp
    , (* mark_debug = "true" *)  input wire                                uart_axil_bvalid
    , (* mark_debug = "true" *)  output wire                               uart_axil_bready

    // READ ADDRESS CHANNEL SIGNALS
    , (* mark_debug = "true" *)  output wire [C_UART_AXI_ADDR_WIDTH-1:0]   uart_axil_araddr
    , (* mark_debug = "true" *)  output wire [2:0]                         uart_axil_arprot
    , (* mark_debug = "true" *)  output wire                               uart_axil_arvalid
    , (* mark_debug = "true" *)  input wire                                uart_axil_arready

    // READ DATA CHANNEL SIGNALS
    , (* mark_debug = "true" *)  input [C_UART_AXI_DATA_WIDTH-1:0]         uart_axil_rdata
    , (* mark_debug = "true" *)  input [1:0]                               uart_axil_rresp
    , (* mark_debug = "true" *)  input wire                                uart_axil_rvalid
    ,  (* mark_debug = "true" *) output wire                               uart_axil_rready

    , (* mark_debug = "true" *) input 									   uart_interrupt

    // WRITE ADDRESS CHANNEL SIGNALS
    , output wire [C_UI_AXI_ADDR_WIDTH-1:0]     ui_axil_awaddr
    , output wire [2:0]                         ui_axil_awprot
    , output wire                               ui_axil_awvalid
    , input wire                                ui_axil_awready

    // WRITE DATA CHANNEL SIGNALS
    , output wire [C_UI_AXI_DATA_WIDTH-1:0 ]    ui_axil_wdata
    , output wire [C_UI_AXI_DATA_WIDTH/8-1:0]   ui_axil_wstrb
    , output wire                               ui_axil_wvalid
    , input wire                                ui_axil_wready

    // WRITE RESPONSE CHANNEL SIGNALS
    , input [1:0]                               ui_axil_bresp
    , input wire                                ui_axil_bvalid
    , output wire                               ui_axil_bready

    // READ ADDRESS CHANNEL SIGNALS
    , output wire [C_UI_AXI_ADDR_WIDTH-1:0]     ui_axil_araddr
    , output wire [2:0]                         ui_axil_arprot
    , output wire                               ui_axil_arvalid
    , input wire                                ui_axil_arready

    // READ DATA CHANNEL SIGNALS
    , input [C_UI_AXI_DATA_WIDTH-1:0]           ui_axil_rdata
    , input [1:0]                               ui_axil_rresp
    , input wire                                ui_axil_rvalid
    , output wire                               ui_axil_rready
    );

  bsg_axil_uart_bridge
   #(.uart_axil_data_width_p(C_UART_AXI_DATA_WIDTH)
     ,.uart_axil_addr_width_p(C_UART_AXI_ADDR_WIDTH)
     ,.ui_axil_data_width_p(C_UI_AXI_DATA_WIDTH)
     ,.ui_axil_addr_width_p(C_UI_AXI_ADDR_WIDTH)
     )
   bridge
    (.clk_i(aclk)
     ,.reset_i(~aresetn)

     ,.uart_axil_awaddr_o(uart_axil_awaddr)
     ,.uart_axil_awprot_o(uart_axil_awprot)
     ,.uart_axil_awvalid_o(uart_axil_awvalid)
     ,.uart_axil_awready_i(uart_axil_awready)

     ,.uart_axil_wdata_o(uart_axil_wdata)
     ,.uart_axil_wstrb_o(uart_axil_wstrb)
     ,.uart_axil_wvalid_o(uart_axil_wvalid)
     ,.uart_axil_wready_i(uart_axil_wready)

     ,.uart_axil_bresp_i(uart_axil_bresp)
     ,.uart_axil_bvalid_i(uart_axil_bvalid)
     ,.uart_axil_bready_o(uart_axil_bready)

     ,.uart_axil_araddr_o(uart_axil_araddr)
     ,.uart_axil_arprot_o(uart_axil_arprot)
     ,.uart_axil_arvalid_o(uart_axil_arvalid)
     ,.uart_axil_arready_i(uart_axil_arready)

     ,.uart_axil_rdata_i(uart_axil_rdata)
     ,.uart_axil_rresp_i(uart_axil_rresp)
     ,.uart_axil_rvalid_i(uart_axil_rvalid)
     ,.uart_axil_rready_o(uart_axil_rready)
     ,.uart_interrupt_i(uart_interrupt)

     ,.ui_axil_awaddr_o(ui_axil_awaddr)
     ,.ui_axil_awprot_o(ui_axil_awprot)
     ,.ui_axil_awvalid_o(ui_axil_awvalid)
     ,.ui_axil_awready_i(ui_axil_awready)

     ,.ui_axil_wdata_o(ui_axil_wdata)
     ,.ui_axil_wstrb_o(ui_axil_wstrb)
     ,.ui_axil_wvalid_o(ui_axil_wvalid)
     ,.ui_axil_wready_i(ui_axil_wready)

     ,.ui_axil_bresp_i(ui_axil_bresp)
     ,.ui_axil_bvalid_i(ui_axil_bvalid)
     ,.ui_axil_bready_o(ui_axil_bready)

     ,.ui_axil_araddr_o(ui_axil_araddr)
     ,.ui_axil_arprot_o(ui_axil_arprot)
     ,.ui_axil_arvalid_o(ui_axil_arvalid)
     ,.ui_axil_arready_i(ui_axil_arready)

     ,.ui_axil_rdata_i(ui_axil_rdata)
     ,.ui_axil_rresp_i(ui_axil_rresp)
     ,.ui_axil_rvalid_i(ui_axil_rvalid)
     ,.ui_axil_rready_o(ui_axil_rready)
     );  

endmodule

