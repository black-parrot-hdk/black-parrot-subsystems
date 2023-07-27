
`include "bp_common_defines.svh"
`include "bsg_manycore_defines.vh"

module bp_cce_to_mc_dram
 import bp_common_pkg::*;
 import bsg_manycore_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_y_cord_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(icache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(num_vcache_rows_p)
   , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(vcache_size_p)
   , parameter `BSG_INV_PARAM(vcache_sets_p)
   , parameter `BSG_INV_PARAM(num_tiles_x_p)
   , localparam x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
   , parameter `BSG_INV_PARAM(num_tiles_y_p)
   , localparam y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)

   , parameter `BSG_INV_PARAM(outstanding_words_p)

   , localparam pod_cord_width_lp = pod_x_cord_width_p+pod_y_cord_width_p
   , localparam mc_link_sif_width_lp =
       `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
   )
  (input                                        clk_i
   , input                                      reset_i

   , input [mem_fwd_header_width_lp-1:0]        mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]           mem_fwd_data_i
   , input                                      mem_fwd_v_i
   , output logic                               mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0] mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]    mem_rev_data_o
   , output logic                               mem_rev_v_o
   , input                                      mem_rev_ready_and_i

   , input [mc_link_sif_width_lp-1:0]           link_sif_i
   , output logic [mc_link_sif_width_lp-1:0]    link_sif_o

   , input [x_cord_width_p-1:0]                 global_x_i
   , input [y_cord_width_p-1:0]                 global_y_i
   , input [pod_cord_width_lp-1:0]              dram_pod_i
   , input [addr_width_p-1:0]                   dram_offset_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);

  bp_bedrock_mem_fwd_header_s fsm_fwd_header_li;
  logic [word_width_gp-1:0] fsm_fwd_data_li;
  logic fsm_fwd_v_li, fsm_fwd_yumi_lo;
  logic [paddr_width_p-1:0] fsm_fwd_addr_li;
  logic fsm_fwd_new_lo, fsm_fwd_critical_lo, fsm_fwd_last_lo;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.fsm_data_width_p(word_width_gp)
     ,.block_width_p(bedrock_block_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     )
   cce_to_cache_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(mem_fwd_header_cast_i)
     ,.msg_data_i(mem_fwd_data_i)
     ,.msg_v_i(mem_fwd_v_i)
     ,.msg_ready_and_o(mem_fwd_ready_and_o)

     ,.fsm_header_o(fsm_fwd_header_li)
     ,.fsm_data_o(fsm_fwd_data_li)
     ,.fsm_v_o(fsm_fwd_v_li)
     ,.fsm_yumi_i(fsm_fwd_yumi_lo)
     ,.fsm_addr_o(fsm_fwd_addr_li)
     ,.fsm_new_o(fsm_fwd_new_lo)
     ,.fsm_critical_o(fsm_fwd_critical_lo)
     ,.fsm_last_o(fsm_fwd_last_lo)
     );

  bp_bedrock_mem_rev_header_s fsm_rev_header_lo;
  logic [word_width_gp-1:0] fsm_rev_data_lo;
  logic fsm_rev_v_lo, fsm_rev_ready_and_li;
  logic [paddr_width_p-1:0] fsm_rev_addr_lo;
  logic fsm_rev_new_lo, fsm_rev_critical_lo, fsm_rev_last_lo;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.fsm_data_width_p(word_width_gp)
     ,.block_width_p(bedrock_block_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     )
   cce_to_cache_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(mem_rev_header_cast_o)
     ,.msg_data_o(mem_rev_data_o)
     ,.msg_v_o(mem_rev_v_o)
     ,.msg_ready_and_i(mem_rev_ready_and_i)

     ,.fsm_header_i(fsm_rev_header_lo)
     ,.fsm_data_i(fsm_rev_data_lo)
     ,.fsm_v_i(fsm_rev_v_lo)
     ,.fsm_ready_and_o(fsm_rev_ready_and_li)
     ,.fsm_addr_o(fsm_rev_addr_lo)
     ,.fsm_new_o(fsm_rev_new_lo)
     ,.fsm_critical_o(fsm_rev_critical_lo)
     ,.fsm_last_o(fsm_rev_last_lo)
     );

  bsg_manycore_global_addr_s mem_fwd_eva_li;
  assign mem_fwd_eva_li = fsm_fwd_addr_li;

  bsg_manycore_packet_s        packet_lo;
  logic                        packet_v_lo;
  logic                        packet_yumi_li;

  bsg_manycore_return_packet_s return_packet_li;
  logic                        return_packet_v_li;

  bsg_manycore_packet_s        packet_li;
  logic                        packet_v_li;
  logic                        packet_ready_lo;

  bsg_manycore_return_packet_s return_packet_lo;
  logic                        return_packet_v_lo;
  logic                        return_packet_yumi_li;
  logic                        return_packet_fifo_full_lo;

  logic [5:0]                  out_credits_used_lo;

  bsg_manycore_endpoint_fc
   #(.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
     ,.fifo_els_p(4)
     )
   blackparrot_endpoint
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.link_sif_i(link_sif_i)
     ,.link_sif_o(link_sif_o)

     //--------------------------------------------------------
     // 1. in_request signal group
     ,.packet_o(packet_lo)
     ,.packet_v_o(packet_v_lo)
     ,.packet_yumi_i(packet_yumi_li)

     //--------------------------------------------------------
     // 2. out_response signal group
     //    responses that will send back to the network
     ,.return_packet_i(return_packet_li)
     ,.return_packet_v_i(return_packet_v_li)

     //--------------------------------------------------------
     // 3. out_request signal group
     //    request that will send to the network
     ,.packet_i(packet_li)
     ,.packet_v_i(packet_v_li)
     ,.packet_credit_or_ready_o(packet_ready_lo)

     //--------------------------------------------------------
     // 4. in_response signal group
     //    responses that send back from the network
     //    the node shold always be ready to receive this response.
     ,.return_packet_o(return_packet_lo)
     ,.return_packet_v_o(return_packet_v_lo)
     ,.return_packet_yumi_i(return_packet_yumi_li)
     ,.return_packet_fifo_full_o()

     ,.out_credits_used_o(out_credits_used_lo)
     );

  // Stub incoming connection
  assign packet_yumi_li = 0;
  assign return_packet_v_li = '0;
  assign return_packet_li = '0;

  // DRAM hash function
  logic [x_cord_width_p-1:0] dram_x_cord_lo;
  logic [y_cord_width_p-1:0] dram_y_cord_lo;
  logic [addr_width_p-1:0] dram_epa_lo;

  wire [data_width_p-2:0] dram_addr_li = fsm_fwd_addr_li + dram_offset_i;
  wire [data_width_p-1:0] dram_eva_li  = {1'b1, dram_addr_li};
  wire [pod_y_cord_width_p-1:0] dram_pod_y_li = dram_pod_i[0+:pod_y_cord_width_p];
  wire [pod_x_cord_width_p-1:0] dram_pod_x_li = dram_pod_i[pod_y_cord_width_p+:pod_x_cord_width_p];
  bsg_manycore_dram_hash_function
   #(.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.pod_x_cord_width_p(pod_x_cord_width_p)
     ,.pod_y_cord_width_p(pod_y_cord_width_p)
     ,.x_subcord_width_p(x_subcord_width_lp)
     ,.y_subcord_width_p(y_subcord_width_lp)
     ,.num_vcache_rows_p(num_vcache_rows_p)
     ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
     )
   dram_hash
    (.eva_i(dram_eva_li)
     ,.pod_x_i(dram_pod_x_li)
     ,.pod_y_i(dram_pod_y_li)

     ,.x_cord_o(dram_x_cord_lo)
     ,.y_cord_o(dram_y_cord_lo)
     ,.epa_o(dram_epa_lo)
     );

  localparam trans_id_width_lp = `BSG_SAFE_CLOG2(outstanding_words_p);
  logic [trans_id_width_lp-1:0] trans_id_lo;
  logic trans_id_v_lo, trans_id_yumi_li;
  logic [data_width_p-1:0] dram_rev_data_lo;
  logic [trans_id_width_lp-1:0] dram_rev_id_lo;
  logic dram_rev_v_lo, dram_rev_yumi_li;
  logic dram_returned_v_li;

  wire [bsg_manycore_reg_id_width_gp-1:0] dram_returned_reg_id_li = return_packet_lo.reg_id;
  wire [data_width_p-1:0] dram_returned_data_li = return_packet_lo.data;
  bsg_fifo_reorder
   #(.width_p(data_width_p), .els_p(outstanding_words_p))
   return_data_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.fifo_alloc_id_o(trans_id_lo[0+:trans_id_width_lp])
     ,.fifo_alloc_v_o(trans_id_v_lo)
     ,.fifo_alloc_yumi_i(trans_id_yumi_li)

     // We write an entry on credit return in order to determine when to send
     //   back a store response.  A little inefficent, but allocating storage for
     //   worst case (all loads) isn't unreasonable
     ,.write_id_i(dram_returned_reg_id_li[0+:trans_id_width_lp])
     ,.write_data_i(dram_returned_data_li)
     ,.write_v_i(dram_returned_v_li)

     ,.fifo_deq_data_o(dram_rev_data_lo)
     ,.fifo_deq_id_o(dram_rev_id_lo)
     ,.fifo_deq_v_o(dram_rev_v_lo)
     ,.fifo_deq_yumi_i(dram_rev_yumi_li)

     ,.empty_o()
     );

  // TODO: This could be reduced to a fifo of size 32/burst_len
  bp_bedrock_mem_rev_header_s dram_rev_header_lo;
  bsg_mem_1r1w
   #(.width_p($bits(fsm_fwd_header_li)), .els_p(outstanding_words_p))
   return_headers
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)

     ,.w_v_i(trans_id_yumi_li)
     ,.w_addr_i(trans_id_lo)
     ,.w_data_i(fsm_fwd_header_li)

     ,.r_v_i(dram_rev_yumi_li)
     ,.r_addr_i(dram_rev_id_lo)
     ,.r_data_o(dram_rev_header_lo)
     );

  //////////////////////////////////////////////
  // Outgoing Request
  //////////////////////////////////////////////
  always_comb
    begin
      fsm_fwd_yumi_lo = fsm_fwd_v_li & trans_id_v_lo & packet_ready_lo;
      trans_id_yumi_li = fsm_fwd_yumi_lo;
      packet_v_li = trans_id_yumi_li;

      packet_li = '0;
      packet_li.op_v2        = (fsm_fwd_header_li.msg_type inside {e_bedrock_mem_wr}) ? e_remote_sw : e_remote_load;
      packet_li.src_y_cord   = global_y_i;
      packet_li.src_x_cord   = global_x_i;
      packet_li.addr         = dram_epa_lo;
      packet_li.y_cord       = dram_y_cord_lo;
      packet_li.x_cord       = dram_x_cord_lo;
      packet_li.payload.data = fsm_fwd_data_li;
      packet_li.reg_id       = bsg_manycore_reg_id_width_gp'(trans_id_lo);

      // We can always ack mmio requests, because we've allocated space in the reorder fifo
      return_packet_yumi_li = return_packet_v_lo;
      dram_returned_v_li = return_packet_yumi_li;

      // Send out mmio response opportunistically
      fsm_rev_header_lo = dram_rev_header_lo;
      fsm_rev_data_lo = dram_rev_data_lo;
      fsm_rev_v_lo = dram_rev_v_lo;
      dram_rev_yumi_li = fsm_rev_ready_and_li & fsm_rev_v_lo;
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_to_mc_dram)

