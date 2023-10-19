

`include "bsg_manycore_defines.vh"

module bsg_manycore_axil_bridge
 import bsg_manycore_pkg::*;
 #(parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(axil_addr_width_p)
   , parameter `BSG_INV_PARAM(axil_data_width_p)

   , localparam axil_mask_width_lp = axil_data_width_p>>3
   , localparam link_sif_width_lp =
       `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
   )
  (input                                       clk_i
   , input                                     reset_i

   , input [link_sif_width_lp-1:0]             link_sif_i
   , output logic [link_sif_width_lp-1:0]      link_sif_o

   //====================== AXI-4 LITE Master =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , output logic [axil_addr_width_p-1:0]       m_axil_awaddr_o
   , output logic [2:0]                         m_axil_awprot_o
   , output logic                               m_axil_awvalid_o
   , input                                      m_axil_awready_i

   // WRITE DATA CHANNEL SIGNALS
   , output logic [axil_data_width_p-1:0]       m_axil_wdata_o
   , output logic [axil_mask_width_lp-1:0]      m_axil_wstrb_o
   , output logic                               m_axil_wvalid_o
   , input                                      m_axil_wready_i

   // WRITE RESPONSE CHANNEL SIGNALS
   , input [1:0]                                m_axil_bresp_i
   , input                                      m_axil_bvalid_i
   , output logic                               m_axil_bready_o

   // READ ADDRESS CHANNEL SIGNALS
   , output logic [axil_addr_width_p-1:0]       m_axil_araddr_o
   , output logic [2:0]                         m_axil_arprot_o
   , output logic                               m_axil_arvalid_o
   , input                                      m_axil_arready_i

   // READ DATA CHANNEL SIGNALS
   , input [axil_data_width_p-1:0]              m_axil_rdata_i
   , input [1:0]                                m_axil_rresp_i
   , input                                      m_axil_rvalid_i
   , output logic                               m_axil_rready_o

   //====================== AXI-4 LITE =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_awaddr_i
   , input [2:0]                                s_axil_awprot_i
   , input                                      s_axil_awvalid_i
   , output logic                               s_axil_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [axil_data_width_p-1:0]              s_axil_wdata_i
   , input [axil_mask_width_lp-1:0]             s_axil_wstrb_i
   , input                                      s_axil_wvalid_i
   , output logic                               s_axil_wready_o

   // WRITE RESPONSE CHANNEL SIGNALS
   , output logic [1:0]                         s_axil_bresp_o
   , output logic                               s_axil_bvalid_o
   , input                                      s_axil_bready_i

   // READ ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_araddr_i
   , input [2:0]                                s_axil_arprot_i
   , input                                      s_axil_arvalid_i
   , output logic                               s_axil_arready_o

   // READ DATA CHANNEL SIGNALS
   , output logic [axil_data_width_p-1:0]       s_axil_rdata_o
   , output logic [1:0]                         s_axil_rresp_o
   , output logic                               s_axil_rvalid_o
   , input                                      s_axil_rready_i
   );

  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  bsg_manycore_link_sif_s link_sif_cast_i, link_sif_cast_o;
  assign link_sif_cast_i = link_sif_i;
  assign link_sif_o = link_sif_cast_o;

  // Instantiate bsg_axil_fifo_master and bsg_axil_fifo_client
  //bsg_axil_fifo_client
  // #(.axil_data_width_p(axil_data_width_p)
  //   ,.axil_addr_width_p(axil_addr_width_p)
  //   )
  // fifo_client
  //  (.clk_i(clk_i)
  //   ,.reset_i(reset_i)

  //   ,.data_o(wdata_lo)
  //   ,.addr_o(addr_lo)
  //   ,.v_o(v_lo)
  //   ,.w_o(w_lo)
  //   ,.wmask_o(wmask_lo)
  //   ,.ready_and_i(ready_and_li)

  //   ,.data_i(rdata_li)
  //   ,.v_i(v_li)
  //   ,.ready_and_o(ready_and_lo)

  //   ,.*
  //   );

  // Stub
  assign s_axil_awready_o = '0;
  assign s_axil_wready_o = '0;
  assign s_axil_bresp_o = '0;
  assign s_axil_bvalid_o = '0;
  assign s_axil_arready_o = '0;
  assign s_axil_rdata_o = '0;
  assign s_axil_rresp_o = '0;
  assign s_axil_rvalid_o = '0;

  assign m_axil_awaddr_o = '0;
  assign m_axil_awprot_o = '0;
  assign m_axil_awvalid_o = '0;
  assign m_axil_wdata_o = '0;
  assign m_axil_wstrb_o = '0;
  assign m_axil_wvalid_o = '0;
  assign m_axil_bready_o = '0;
  assign m_axil_araddr_o = '0;
  assign m_axil_arvalid_o = '0;
  assign m_axil_rready_o = '0;

  assign link_sif_cast_o = '0;

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_axil_bridge)

