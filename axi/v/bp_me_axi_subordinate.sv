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
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

  , parameter s_axi_data_width_p = 64
  , parameter s_axi_addr_width_p = 64
  , parameter s_axi_id_width_p = 1
  , parameter s_axi_user_width_p = 1
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

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  logic [axil_data_width_p-1:0] wdata_lo;
  logic [axil_addr_width_p-1:0] addr_lo;
  logic v_lo, w_lo, ready_and_li;
  logic [axil_mask_width_lp-1:0] wmask_lo;

  logic [axil_data_width_p-1:0] rdata_li;
  logic v_li, ready_and_lo;
  bsg_axil_fifo_client
   #(.axil_data_width_p(axil_data_width_p)
     ,.axil_addr_width_p(axil_addr_width_p)
     )
   fifo_client
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_o(wdata_lo)
     ,.addr_o(addr_lo)
     ,.v_o(v_lo)
     ,.w_o(w_lo)
     ,.wmask_o(wmask_lo)
     ,.ready_and_i(ready_and_li)

     ,.data_i(rdata_li)
     ,.v_i(v_li)
     ,.ready_and_o(ready_and_lo)

     ,.*
     );

  localparam lg_axil_mask_width_lp = `BSG_SAFE_CLOG2(axil_mask_width_lp);
  always_comb
    begin
      mem_fwd_data_o = wdata_lo;
      mem_fwd_header_cast_o = '0;
      mem_fwd_header_cast_o.payload.lce_id = lce_id_i;
      mem_fwd_header_cast_o.payload.did    = did_i;
      mem_fwd_header_cast_o.addr           = addr_lo;
      mem_fwd_header_cast_o.msg_type       = w_lo ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
      if (~w_lo) begin
        // reads are full width
        mem_fwd_header_cast_o.size = bp_bedrock_msg_size_e'(lg_axil_mask_width_lp);
      end else begin
        // TODO: check address aligned with write strobes and for error cases (including mask 'h00),
        // reply with AXIL error response, and do not send BedRock message.
        case (wmask_lo)
          axil_mask_width_lp'('h80)
          ,axil_mask_width_lp'('h40)
          ,axil_mask_width_lp'('h20)
          ,axil_mask_width_lp'('h10)
          ,axil_mask_width_lp'('h08)
          ,axil_mask_width_lp'('h04)
          ,axil_mask_width_lp'('h02)
          ,axil_mask_width_lp'('h01): mem_fwd_header_cast_o.size = e_bedrock_msg_size_1;
          axil_mask_width_lp'('hC0)
          ,axil_mask_width_lp'('h30)
          ,axil_mask_width_lp'('h0C)
          ,axil_mask_width_lp'('h03): mem_fwd_header_cast_o.size = e_bedrock_msg_size_2;
          axil_mask_width_lp'('hF0)
          ,axil_mask_width_lp'('h0F): mem_fwd_header_cast_o.size = e_bedrock_msg_size_4;
          axil_mask_width_lp'('hFF): mem_fwd_header_cast_o.size = e_bedrock_msg_size_8;
          default: mem_fwd_header_cast_o.size = e_bedrock_msg_size_8;
        endcase
      end

      mem_fwd_v_o = v_lo;
      ready_and_li = mem_fwd_ready_and_i;
    end

  always_comb
    begin
      rdata_li = mem_rev_data_i;
      v_li = mem_rev_v_i;
      mem_rev_ready_and_o = ready_and_lo;
    end

endmodule

