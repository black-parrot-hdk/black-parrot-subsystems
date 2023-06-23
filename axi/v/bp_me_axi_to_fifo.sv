/*
 * Name:
 *   bp_me_axi_to_fifo.sv
 *
 * Description:
 *   This module converts an AXI4 subordinate interface to a fifo interface. The independent
 *   read and write channels are serialized to the output fifo interface and responses are expected
 *   to return in-order.
 *
 */

`include "bsg_defines.v"

module bp_me_axi_to_fifo
 import bsg_axi_pkg::*;
 #(parameter s_axi_data_width_p = 64
  , parameter s_axi_addr_width_p = 64
  , parameter s_axi_id_width_p = 1
  , parameter s_axi_user_width_p = 1
  , localparam s_axi_mask_width_lp = s_axi_data_width_p>>3
  )
  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   , output logic [s_axi_data_width_p-1:0]      data_o
   , output logic [s_axi_addr_width_p-1:0]      addr_o
   , output logic                               v_o
   , output logic                               w_o
   , output logic [s_axi_mask_width_lp-1:0]     wmask_o
   , input                                      ready_and_i

   , input [s_axi_data_width_p-1:0]             data_i
   , input                                      v_i
   , output logic                               ready_and_o


   //====================== AXI-4 =========================
   , input [s_axi_addr_width_p-1:0]             s_axi_awaddr_i
   , input                                      s_axi_awvalid_i
   , output logic                               s_axi_awready_o
   , input [s_axi_id_width_p-1:0]               s_axi_awid_i
   , input                                      s_axi_awlock_i
   , input [3:0]                                s_axi_awcache_i
   , input [2:0]                                s_axi_awprot_i
   , input [7:0]                                s_axi_awlen_i
   , input [2:0]                                s_axi_awsize_i
   , input [1:0]                                s_axi_awburst_i
   , input [3:0]                                s_axi_awqos_i
   , input [3:0]                                s_axi_awregion_i
   , input [s_axi_user_width_p-1:0]             s_axi_awuser_i

   , input [s_axi_data_width_p-1:0]             s_axi_wdata_i
   , input                                      s_axi_wvalid_i
   , output logic                               s_axi_wready_o
   , input                                      s_axi_wlast_i
   , input [s_axi_mask_width_lp-1:0]            s_axi_wstrb_i
   , input [s_axi_user_width_p-1:0]             s_axi_wuser_i

   , output logic                               s_axi_bvalid_o
   , input                                      s_axi_bready_i
   , output logic [s_axi_id_width_p-1:0]        s_axi_bid_o
   , output logic [1:0]                         s_axi_bresp_o
   , output logic [s_axi_user_width_p-1:0]      s_axi_buser_o

   , input [s_axi_addr_width_p-1:0]             s_axi_araddr_i
   , input                                      s_axi_arvalid_i
   , output logic                               s_axi_arready_o
   , input [s_axi_id_width_p-1:0]               s_axi_arid_i
   , input                                      s_axi_arlock_i
   , input [3:0]                                s_axi_arcache_i
   , input [2:0]                                s_axi_arprot_i
   , input [7:0]                                s_axi_arlen_i
   , input [2:0]                                s_axi_arsize_i
   , input [1:0]                                s_axi_arburst_i
   , input [3:0]                                s_axi_arqos_i
   , input [3:0]                                s_axi_arregion_i
   , input [s_axi_user_width_p-1:0]             s_axi_aruser_i

   , output logic [s_axi_data_width_p-1:0]      s_axi_rdata_o
   , output logic                               s_axi_rvalid_o
   , input                                      s_axi_rready_i
   , output logic [s_axi_id_width_p-1:0]        s_axi_rid_o
   , output logic                               s_axi_rlast_o
   , output logic [1:0]                         s_axi_rresp_o
   , output logic [s_axi_user_width_p-1:0]      s_axi_ruser_o
   );

  // read return interface fifo
  logic v_li, yumi_lo;
  logic [s_axi_data_width_p-1:0] data_li;
  bsg_two_fifo
    #(.width_p(s_axi_data_width_p))
    read_return_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(data_i)
      ,.v_i(v_i)
      ,.ready_o(ready_and_o)
      ,.data_o(data_li)
      ,.v_o(v_li)
      ,.yumi_i(yumi_lo)
      );

  // AR channel fifo
  bsg_two_fifo
    #(.width_p(s_axi_addr_width_p+s_axi_id_width_p+s_axi_user_width_p))
    read_return_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_arid_i, s_axi_aruser_i})
      ,.v_i()
      ,.ready_o()
      ,.data_o({s_axi_rid_o, s_axi_ruser_o})
      ,.v_o()
      ,.yumi_i()
      );

  assign s_axi_rdata_o = data_li;


///////////////////////////////////////////////////////////////////////////////////
  wire unused = &{s_axil_awprot_i, s_axil_arprot_i};
  assign s_axi_bresp_o = e_axi_resp_okay;
  assign s_axi_rresp_o = e_axi_resp_okay;

  logic [axil_addr_width_p-1:0] araddr_li;
  logic araddr_v_li, araddr_yumi_lo;
  bsg_two_fifo
   #(.width_p(axil_addr_width_p))
   araddr_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(s_axil_araddr_i)
     ,.v_i(s_axil_arvalid_i)
     ,.ready_o(s_axil_arready_o)

     ,.data_o(araddr_li)
     ,.v_o(araddr_v_li)
     ,.yumi_i(araddr_yumi_lo)
     );

  logic [axil_addr_width_p-1:0] awaddr_li;
  logic awaddr_v_li, awaddr_yumi_lo;
  bsg_two_fifo
   #(.width_p(axil_addr_width_p))
   awaddr_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(s_axil_awaddr_i)
     ,.v_i(s_axil_awvalid_i)
     ,.ready_o(s_axil_awready_o)

     ,.data_o(awaddr_li)
     ,.v_o(awaddr_v_li)
     ,.yumi_i(awaddr_yumi_lo)
     );

  logic [axil_data_width_p-1:0] wdata_li;
  logic [axil_mask_width_lp-1:0] wmask_li;
  logic wdata_v_li, wdata_yumi_lo;
  bsg_two_fifo
   #(.width_p(axil_mask_width_lp+axil_data_width_p))
   wdata_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({s_axil_wstrb_i, s_axil_wdata_i})
     ,.v_i(s_axil_wvalid_i)
     ,.ready_o(s_axil_wready_o)

     ,.data_o({wmask_li, wdata_li})
     ,.v_o(wdata_v_li)
     ,.yumi_i(wdata_yumi_lo)
     );

  logic return_v_li, return_ready_lo, return_w_lo, return_v_lo, return_yumi_li;
  bsg_two_fifo
   #(.width_p(1))
   return_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(w_o)
     ,.v_i(return_v_li)
     ,.ready_o(return_ready_lo)

     ,.data_o(return_w_lo)
     ,.v_o(return_v_lo)
     ,.yumi_i(return_yumi_li)
     );

  // Align read addresses to bus width (per axil spec)
  // TODO: Replace with https://github.com/bespoke-silicon-group/basejump_stl/pull/565/files
  `ifndef BSG_ALIGN
  `define BSG_ALIGN(addr_mp, nb_mp) \
    ({addr_mp[$bits(addr_mp)-1:$clog2(nb_mp)], {$clog2(nb_mp){1'b0}}}) 
  `endif

  // Prioritize reads over writes
  assign addr_o  = araddr_v_li ? `BSG_ALIGN(araddr_li, axil_mask_width_lp) : awaddr_li;
  assign data_o  = wdata_li;
  assign v_o     = return_ready_lo & (araddr_v_li | (awaddr_v_li & wdata_v_li));
  assign w_o     = ~araddr_v_li;
  assign wmask_o = wmask_li;

  assign araddr_yumi_lo = ready_and_i & v_o & araddr_v_li;
  assign awaddr_yumi_lo = ready_and_i & v_o & ~araddr_v_li;
  assign wdata_yumi_lo = awaddr_yumi_lo;

  assign s_axil_rdata_o  = data_i;
  assign s_axil_rvalid_o = v_i & ~return_w_lo;
  assign s_axil_bvalid_o = v_i &  return_w_lo;

  assign ready_and_o = (return_v_lo & return_w_lo & s_axil_bready_i) | (return_v_lo & ~return_w_lo & s_axil_rready_i);

  assign return_v_li = ready_and_i & v_o;
  assign return_yumi_li = ready_and_o & v_i;


endmodule

