/*
 * Name:
 *   bp_me_axi_to_fifo.sv
 *
 * Description:
 *   This module converts an AXI4 subordinate interface to a fifo interface. The independent
 *   read and write channels are serialized to the output fifo interface and responses are expected
 *   to return in-order.
 *
 * Constraints and Assumptions:
 *   - data width must be 64-bits
 *   - address must be naturally aligned to request size (axsize)
 *   - 8, 16, and 32-bit requests must have axlen equal to 1
 *   - requests with axsize of 64-bits may have axlen greater than 1
 *
 *
 */

`include "bsg_defines.v"

module bp_me_axi_to_fifo
 import bsg_axi_pkg::*;
 #(parameter s_axi_data_width_p = 64
  , parameter s_axi_addr_width_p = 64
  , parameter s_axi_id_width_p = 1
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
   , output logic [2:0]                         size_o
   , input                                      ready_and_i

   , input [s_axi_data_width_p-1:0]             data_i
   , input                                      v_i
   , input                                      w_i
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

   , input [s_axi_data_width_p-1:0]             s_axi_wdata_i
   , input                                      s_axi_wvalid_i
   , output logic                               s_axi_wready_o
   , input                                      s_axi_wlast_i
   , input [s_axi_mask_width_lp-1:0]            s_axi_wstrb_i

   , output logic                               s_axi_bvalid_o
   , input                                      s_axi_bready_i
   , output logic [s_axi_id_width_p-1:0]        s_axi_bid_o
   , output logic [1:0]                         s_axi_bresp_o

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

   , output logic [s_axi_data_width_p-1:0]      s_axi_rdata_o
   , output logic                               s_axi_rvalid_o
   , input                                      s_axi_rready_i
   , output logic [s_axi_id_width_p-1:0]        s_axi_rid_o
   , output logic                               s_axi_rlast_o
   , output logic [1:0]                         s_axi_rresp_o
   );

  // AW channel fifo
  logic [s_axi_addr_width_p-1:0] awaddr_li;
  logic [s_axi_id_width_p-1:0] awid_li;
  logic [2:0] awsize_li;
  logic awvalid_li, awyumi_lo;
  bsg_one_fifo
    #(.width_p(s_axi_addr_width_p+s_axi_id_width_p+3))
    aw_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_awaddr_i, s_axi_awid_i, s_axi_awsize_i})
      ,.v_i(s_axi_awvalid_i)
      ,.ready_o(s_axi_awready_o)
      ,.data_o({awaddr_li, awid_li, awsize_li})
      ,.v_o(awvalid_li)
      ,.yumi_i(awyumi_lo)
      );

  // W channel fifo
  logic [s_axi_data_width_p-1:0] wdata_li;
  logic [s_axi_mask_width_lp-1:0] wstrb_li;
  logic wvalid_li, wyumi_lo;
  bsg_one_fifo
    #(.width_p(s_axi_data_width_p+s_axi_mask_width_p))
    w_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_wstrb_i, s_axi_wdata_i})
      ,.v_i(s_axi_wvalid_i)
      ,.ready_o(s_axi_wready_o)
      ,.data_o({wstrb_li, wdata_li})
      ,.v_o(wvalid_li)
      ,.yumi_i(wyumi_lo)
      );

  // AR channel fifo
  logic [s_axi_addr_width_p-1:0] araddr_li;
  logic [s_axi_id_width_p-1:0] arid_li;
  logic [2:0] arsize_li;
  logic arvalid_li, aryumi_lo;
  bsg_one_fifo
    #(.width_p(s_axi_addr_width_p+s_axi_id_width_p+3))
    ar_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_araddr_i, s_axi_arid_i, s_axi_arsize_i})
      ,.v_i(s_axi_arvalid_i)
      ,.ready_o(s_axi_arready_o)
      ,.data_o({araddr_li, arid_li, arsize_li})
      ,.v_o(arvalid_li)
      ,.yumi_i(aryumi_lo)
      );

  // response (read data) fifo
  // every read and write sent will enqueue a response here
  logic response_v_li, response_yumi_lo, response_w_li;
  logic [s_axi_data_width_p-1:0] response_data_li;
  bsg_one_fifo
    #(.width_p(s_axi_data_width_p+1))
    response_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from FIFO interface
      ,.v_i(v_i)
      ,.ready_o(ready_and_o)
      ,.data_i({w_i, data_i})
      // to AXI
      ,.v_o(response_v_li)
      ,.yumi_i(response_yumi_lo)
      ,.data_o({response_w_li, response_data_li})
      );

  // send to client if valid request from AXI and response fifo has capacity
  // prioritize reads over writes
  assign v_o = ready_and_o & (arvalid_li | (awvalid_li & wvalid_li));
  assign addr_o = arvalid_li ? araddr_li : awaddr_li;
  assign data_o = wdata_li;
  assign w_o = ~arvalid_li;
  assign wmask_o = wstrb_li;
  assign size_o = arvalid_li ? arsize_li : awsize_li;

  // B channel (write) response
  assign s_axi_bvalid_o = response_v_li & response_w_li;
  assign s_axi_bresp_o = e_axi_resp_okay;
  assign s_axi_bid_o = awid_li;
  assign awyumi_lo = s_axi_bvalid_o & s_axi_bready_i;
  assign wyumi_lo = s_axi_bvalid_o & s_axi_bready_i;

  // R channel (read) response
  assign s_axi_rvalid_o = response_v_li & ~response_w_li;
  assign s_axi_rresp_o = e_axi_resp_okay;
  assign s_axi_rdata_o = response_data_li;
  assign s_axi_rlast_o = 1'b1; // only single transfers handled
  assign s_axi_rid_o = arid_li;
  assign aryumi_lo = s_axi_rvalid_o & s_axi_rready_i;

  // response fifo dequeue
  // consume when sending B or R response
  assign response_yumi_lo = (s_axi_bvalid_o & s_axi_bready_i) | (s_axi_rvalid_o & s_axi_rready_i);

endmodule

