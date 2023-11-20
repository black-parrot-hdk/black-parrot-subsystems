/*
 * Name:
 *   bp_me_axi_subordinate.sv
 *
 * Description:
 *   This module converts AXI4 requests to BedRock Stream messages. It supports up to one
 *   read and write from AXI at the same time. AXI provides no inter-channel ordering so the
 *   sender must enforce ordering if desired. If a read and write request arrive at the same
 *   time, they will be serialized and the requester should assume no determnistic ordering.
 *
 *
 * Note: this module only works if the BedRock data width and AXI data widths are 64-bits
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_axi_subordinate
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

  , parameter s_axi_data_width_p = 64
  , parameter s_axi_addr_width_p = 64
  , parameter s_axi_id_width_p = 1
  , localparam s_axi_mask_width_lp = s_axi_data_width_p>>3
  )
  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   //==================== BP-STREAM SIGNALS ======================
   , input [lce_id_width_p-1:0]                 lce_id_i
   , input [did_width_p-1:0]                    did_i

   , output logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]    mem_fwd_data_o
   , output logic                               mem_fwd_v_o
   , input                                      mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]        mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]           mem_rev_data_i
   , input                                      mem_rev_v_i
   , output logic                               mem_rev_ready_and_o

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

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  bp_bedrock_mem_rev_header_s mem_rev_fifo_header_li;
  logic [s_axi_data_width_p-1:0] mem_rev_fifo_data_li;
  logic mem_rev_fifo_v_li, mem_rev_fifo_ready_and_lo;

  bp_me_stream_gearbox
    #(.bp_params_p(bp_params_p)
      ,.buffered_p(1)
      ,.in_data_width_p(bedrock_fill_width_p)
      ,.out_data_width_p(s_axi_data_width_p)
      ,.payload_width_p(mem_rev_payload_width_lp)
      ,.stream_mask_p(mem_rev_stream_mask_gp)
      )
    mem_rev_gearbox
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.msg_header_i(mem_rev_header_cast_i)
      ,.msg_data_i(mem_rev_data_i)
      ,.msg_v_i(mem_rev_v_i)
      ,.msg_ready_and_o(mem_rev_ready_and_o)
      ,.msg_header_o(mem_rev_fifo_header_li)
      ,.msg_data_o(mem_rev_fifo_data_li)
      ,.msg_v_o(mem_rev_fifo_v_li)
      ,.msg_ready_param_i(mem_rev_fifo_ready_and_lo)
      );

  logic mem_fwd_fifo_v_lo, mem_fwd_fifo_ready_and_li;
  logic [s_axi_data_width_p-1:0] mem_fwd_fifo_data_lo;
  bp_bedrock_mem_fwd_header_s mem_fwd_fifo_header_lo;

  bp_me_stream_gearbox
    #(.bp_params_p(bp_params_p)
      ,.buffered_p(1)
      ,.in_data_width_p(s_axi_data_width_p)
      ,.out_data_width_p(bedrock_fill_width_p)
      ,.payload_width_p(mem_fwd_payload_width_lp)
      ,.stream_mask_p(mem_fwd_stream_mask_gp)
      )
    mem_fwd_gearbox
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.msg_header_i(mem_fwd_fifo_header_lo)
      ,.msg_data_i(mem_fwd_fifo_data_lo)
      ,.msg_v_i(mem_fwd_fifo_v_lo)
      ,.msg_ready_and_o(mem_fwd_fifo_ready_and_li)
      ,.msg_header_o(mem_fwd_header_cast_o)
      ,.msg_data_o(mem_fwd_data_o)
      ,.msg_v_o(mem_fwd_v_o)
      ,.msg_ready_param_i(mem_fwd_ready_and_i)
      );

  logic [s_axi_data_width_p-1:0] wdata_lo;
  logic [s_axi_addr_width_p-1:0] addr_lo;
  logic w_lo;
  logic [2:0] size_lo;

  wire mem_rev_fifo_w_li = (mem_rev_fifo_header_li.msg_type == e_bedrock_mem_uc_wr);
  bp_axi_to_fifo
   #(.s_axi_data_width_p(s_axi_data_width_p)
     ,.s_axi_addr_width_p(s_axi_addr_width_p)
     ,.s_axi_id_width_p(s_axi_id_width_p)
     )
   axi2fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_o(wdata_lo)
     ,.addr_o(addr_lo)
     ,.v_o(mem_fwd_fifo_v_lo)
     ,.w_o(w_lo)
     ,.wmask_o() // unused
     ,.size_o(size_lo)
     ,.yumi_i(mem_fwd_fifo_v_li & mem_fwd_fifo_ready_and_li)

     ,.data_i(mem_rev_fifo_data_li)
     ,.v_i(mem_rev_fifo_v_li)
     ,.w_i(mem_rev_fifo_w_li)
     ,.ready_and_o(mem_rev_fifo_ready_and_lo)

     ,.*
     );

  always_comb begin
    mem_fwd_fifo_data_lo = wdata_lo;
    mem_fwd_fifo_header_lo = '0;
    mem_fwd_fifo_header_lo.payload.lce_id  = lce_id_i;
    mem_fwd_fifo_header_lo.payload.src_did = did_i;
    mem_fwd_fifo_header_lo.addr            = addr_lo;
    mem_fwd_fifo_header_lo.msg_type        = w_lo ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
    mem_fwd_fifo_header_lo.size            = bp_bedrock_msg_size_e'(size_lo);
  end

endmodule

