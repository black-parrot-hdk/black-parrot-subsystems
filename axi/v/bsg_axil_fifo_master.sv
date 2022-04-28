
`include "bsg_defines.v"

module bsg_axil_fifo_master
 import bsg_axi_pkg::*;
 #(parameter `BSG_INV_PARAM(axil_data_width_p)
   , parameter `BSG_INV_PARAM(axil_addr_width_p)

   , localparam axi_mask_width_lp = axil_data_width_p >> 3
   )
  (input                                       clk_i
   , input                                     reset_i

   , input [axil_data_width_p-1:0]             data_i
   , input [axil_addr_width_p-1:0]             addr_i
   , input                                     v_i
   , input                                     w_i
   , input [(axil_data_width_p>>3)-1:0]        wmask_i
   , output logic                              ready_and_o

   , output logic [axil_data_width_p-1:0]      data_o
   , output logic                              v_o
   , input                                     ready_and_i

  //====================== AXI-4 LITE =========================
  // WRITE ADDRESS CHANNEL SIGNALS
  , output logic [axil_addr_width_p-1:0]       m_axil_awaddr_o
  , output [2:0]                               m_axil_awprot_o
  , output logic                               m_axil_awvalid_o
  , input                                      m_axil_awready_i

  // WRITE DATA CHANNEL SIGNALS
  , output logic [axil_data_width_p-1:0]       m_axil_wdata_o
  , output logic [(axil_data_width_p>>3)-1:0]  m_axil_wstrb_o
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
  );

  enum logic [1:0] {e_wait, e_read_rx, e_write_rx} state_n, state_r;
  wire is_wait     = (state_r == e_wait);
  wire is_read_rx  = (state_r == e_read_rx);
  wire is_write_rx = (state_r == e_write_rx);

  wire unused = &{m_axil_rresp_i, m_axil_bresp_i};

  logic wdata_ready_lo;
  bsg_two_fifo
   #(.width_p(axil_data_width_p+axi_mask_width_lp))
   wdata_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({data_i, wmask_i})
     ,.v_i(v_i & w_i)
     ,.ready_o(wdata_ready_lo)

     ,.data_o({m_axil_wdata_o, m_axil_wstrb_o})
     ,.v_o(m_axil_wvalid_o)
     ,.yumi_i(m_axil_wready_i & m_axil_wvalid_o)
     );

  logic addr_ready_lo;
  logic w_lo, addr_v_lo, addr_yumi_li;
  logic [axil_addr_width_p-1:0] addr_lo;
  bsg_two_fifo
   #(.width_p(1+axil_addr_width_p))
   addr_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({w_i, addr_i})
     ,.v_i(v_i)
     ,.ready_o(addr_ready_lo)

     ,.data_o({w_lo, addr_lo})
     ,.v_o(addr_v_lo)
     ,.yumi_i(addr_yumi_li)
     );
  assign ready_and_o = addr_ready_lo & wdata_ready_lo;

  logic return_ready_lo, return_w_lo, return_v_lo, return_yumi_li;
  bsg_two_fifo
   #(.width_p(1))
   return_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(w_lo)
     ,.v_i(addr_yumi_li)
     ,.ready_o(return_ready_lo)

     ,.data_o(return_w_lo)
     ,.v_o(return_v_lo)
     ,.yumi_i(return_yumi_li)
     );

  assign m_axil_arvalid_o = return_ready_lo & addr_v_lo & ~w_lo;
  assign m_axil_araddr_o  = addr_lo;
  assign m_axil_arprot_o  = e_axi_prot_dsn;

  assign m_axil_awvalid_o = return_ready_lo & addr_v_lo & w_lo;
  assign m_axil_awaddr_o  = addr_lo;
  assign m_axil_awprot_o  = e_axi_prot_dsn;

  assign addr_yumi_li = (m_axil_arready_i & m_axil_arvalid_o) | (m_axil_awready_i & m_axil_awvalid_o);

  assign v_o = m_axil_rvalid_i | m_axil_bvalid_i;
  assign data_o = m_axil_rdata_i;
  assign m_axil_bready_o = return_v_lo &  return_w_lo & ready_and_i;
  assign m_axil_rready_o = return_v_lo & ~return_w_lo & ready_and_i;

  assign return_yumi_li = ready_and_i & v_o;

endmodule

