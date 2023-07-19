/*
 * Name:
 *   bp_me_fifo_to_axi.sv
 *
 * Description:
 *   This module converts a FIFO interface to AXI4 requests. It supports one outstanding
 *   AXI transaction at a time to preserve ordering, since AXI read and write channels have no
 *   inter-channel ordering guarantees and there is no ordering for transactions to different
 *   peripheral or memory regions.
 *
 */

`include "bsg_defines.v"

module bp_me_fifo_to_axi
 import bsg_axi_pkg::*;
 #(parameter m_axi_data_width_p = 64
  , parameter m_axi_addr_width_p = 64
  , parameter m_axi_id_width_p = 1
  , localparam m_axi_mask_width_lp = (m_axi_data_width_p>>3)
  , localparam lg_m_axi_mask_width_lp = `BSG_SAFE_CLOG2(m_axi_mask_width_lp)
  )
 (//==================== GLOBAL SIGNALS =======================
  input                                        clk_i
  , input                                      reset_i

  , input [m_axi_data_width_p-1:0]             data_i
  , input [m_axi_addr_width_p-1:0]             addr_i
  , input [2:0]                                size_i
  , input                                      v_i
  , input                                      w_i
  , input [m_axi_mask_width_lp-1:0]            wmask_i
  , output logic                               ready_and_o

  , output logic [m_axi_data_width_p-1:0]      data_o
  , output logic                               v_o
  , input                                      ready_and_i

  //====================== AXI-4 =========================
  , output logic [m_axi_addr_width_p-1:0]      m_axi_awaddr_o
  , output logic                               m_axi_awvalid_o
  , input                                      m_axi_awready_i
  , output logic [m_axi_id_width_p-1:0]        m_axi_awid_o
  , output logic                               m_axi_awlock_o
  , output logic [3:0]                         m_axi_awcache_o
  , output logic [2:0]                         m_axi_awprot_o
  , output logic [7:0]                         m_axi_awlen_o
  , output logic [2:0]                         m_axi_awsize_o
  , output logic [1:0]                         m_axi_awburst_o
  , output logic [3:0]                         m_axi_awqos_o
  , output logic [3:0]                         m_axi_awregion_o

  , output logic [m_axi_data_width_p-1:0]      m_axi_wdata_o
  , output logic                               m_axi_wvalid_o
  , input                                      m_axi_wready_i
  , output logic                               m_axi_wlast_o
  , output logic [m_axi_mask_width_lp-1:0]     m_axi_wstrb_o

  , input                                      m_axi_bvalid_i
  , output logic                               m_axi_bready_o
  , input [m_axi_id_width_p-1:0]               m_axi_bid_i
  , input [1:0]                                m_axi_bresp_i

  , output logic [m_axi_addr_width_p-1:0]      m_axi_araddr_o
  , output logic                               m_axi_arvalid_o
  , input                                      m_axi_arready_i
  , output logic [m_axi_id_width_p-1:0]        m_axi_arid_o
  , output logic                               m_axi_arlock_o
  , output logic [3:0]                         m_axi_arcache_o
  , output logic [2:0]                         m_axi_arprot_o
  , output logic [7:0]                         m_axi_arlen_o
  , output logic [2:0]                         m_axi_arsize_o
  , output logic [1:0]                         m_axi_arburst_o
  , output logic [3:0]                         m_axi_arqos_o
  , output logic [3:0]                         m_axi_arregion_o

  , input [m_axi_data_width_p-1:0]             m_axi_rdata_i
  , input                                      m_axi_rvalid_i
  , output logic                               m_axi_rready_o
  , input [m_axi_id_width_p-1:0]               m_axi_rid_i
  , input                                      m_axi_rlast_i
  , input [1:0]                                m_axi_rresp_i
  );

  wire unused = &{m_axil_rresp_i, m_axil_bresp_i};

  logic wdata_ready_lo;
  bsg_one_fifo
   #(.width_p(axil_data_width_p+axi_mask_width_lp))
   wdata_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({data_i, wmask_i})
     ,.v_i(ready_and_o & v_i & w_i)
     ,.ready_o(wdata_ready_lo)

     ,.data_o({m_axil_wdata_o, m_axil_wstrb_o})
     ,.v_o(m_axil_wvalid_o)
     ,.yumi_i(m_axil_wready_i & m_axil_wvalid_o)
     );

  logic addr_ready_lo;
  logic w_lo, addr_v_lo, addr_yumi_li;
  logic [axil_addr_width_p-1:0] addr_lo;
  bsg_one_fifo
   #(.width_p(1+axil_addr_width_p))
   addr_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({w_i, addr_i})
     ,.v_i(ready_and_o & v_i)
     ,.ready_o(addr_ready_lo)

     ,.data_o({w_lo, addr_lo})
     ,.v_o(addr_v_lo)
     ,.yumi_i(addr_yumi_li)
     );

  logic return_ready_lo, return_w_lo, return_v_lo, return_yumi_li;
  bsg_one_fifo
   #(.width_p(1))
   return_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(w_i)
     ,.v_i(ready_and_o & v_i)
     ,.ready_o(return_ready_lo)

     ,.data_o(return_w_lo)
     ,.v_o(return_v_lo)
     ,.yumi_i(return_yumi_li)
     );
  assign ready_and_o = addr_ready_lo & wdata_ready_lo & return_ready_lo;

  assign m_axil_arvalid_o = addr_v_lo & ~w_lo;
  assign m_axil_araddr_o  = addr_lo;
  assign m_axil_arprot_o  = e_axi_prot_dsn;

  assign m_axil_awvalid_o = addr_v_lo & w_lo;
  assign m_axil_awaddr_o  = addr_lo;
  assign m_axil_awprot_o  = e_axi_prot_dsn;

  assign addr_yumi_li = (m_axil_arready_i & m_axil_arvalid_o) | (m_axil_awready_i & m_axil_awvalid_o);

  assign v_o = return_v_lo & (return_w_lo ? m_axil_bvalid_i : m_axil_rvalid_i);
  assign data_o = m_axil_rdata_i;
  assign m_axil_bready_o = return_v_lo &  return_w_lo & ready_and_i;
  assign m_axil_rready_o = return_v_lo & ~return_w_lo & ready_and_i;

  assign return_yumi_li = ready_and_i & v_o;

endmodule

