
`include "bp_common_defines.svh"
`include "bsg_manycore_defines.svh"
`include "bsg_manycore_endpoint_to_fifos.svh"

module bp_me_manycore_fifo
 import bp_common_pkg::*;
 import bsg_manycore_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(icache_block_size_in_words_p)

   , localparam mc_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
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
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  localparam x_cord_width_pad_lp = `BSG_CDIV(x_cord_width_p, 8) * 8;
  localparam y_cord_width_pad_lp = `BSG_CDIV(y_cord_width_p, 8) * 8;
  localparam addr_width_pad_lp   = `BSG_CDIV(addr_width_p, 8) * 8;
  localparam data_width_pad_lp   = `BSG_CDIV(data_width_p, 8) * 8;
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  `declare_bsg_manycore_packet_aligned_s(128, addr_width_pad_lp, data_width_pad_lp, x_cord_width_pad_lp, y_cord_width_pad_lp);

  localparam mc_link_bp_req_fifo_addr_gp      = 20'h0_1000;
  localparam mc_link_bp_req_credits_addr_gp   = 20'h0_2000;
  localparam mc_link_mc_rsp_fifo_addr_gp      = 20'h0_3000;
  localparam mc_link_mc_rsp_entries_addr_gp   = 20'h0_4000;
  localparam mc_link_mc_req_fifo_addr_gp      = 20'h0_5000;
  localparam mc_link_mc_req_entries_addr_gp   = 20'h0_6000;
  localparam mc_link_bp_rsp_fifo_addr_gp      = 20'h0_7000;
  localparam mc_link_bp_rsp_credits_addr_gp   = 20'h0_8000;
  localparam mc_link_endpoint_credits_addr_gp = 20'h0_9000;

  localparam reg_els_lp = 9;

  logic [dev_addr_width_gp-1:0] addr_lo;
  logic [dword_width_gp-1:0] data_lo;
  logic [reg_els_lp-1:0][dword_width_gp-1:0] data_li;
  logic bp_req_data_r_v_lo, bp_req_credits_r_v_lo, bp_req_data_w_v_lo, bp_req_credits_w_v_lo;
  logic mc_rsp_data_r_v_lo, mc_rsp_entries_r_v_lo, mc_rsp_data_w_v_lo, mc_rsp_entries_w_v_lo;
  logic mc_req_data_r_v_lo, mc_req_entries_r_v_lo, mc_req_data_w_v_lo, mc_req_entries_w_v_lo;
  logic bp_rsp_data_r_v_lo, bp_rsp_credits_r_v_lo, bp_rsp_data_w_v_lo, bp_rsp_credits_w_v_lo;
  logic endpoint_credits_r_v_lo, endpoint_credits_w_v_lo;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.reg_data_width_p(dword_width_gp)
     ,.reg_addr_width_p(dev_addr_width_gp)
     ,.els_p(reg_els_lp)
     ,.base_addr_p({mc_link_endpoint_credits_addr_gp
                    ,mc_link_bp_rsp_credits_addr_gp, mc_link_bp_rsp_fifo_addr_gp
                    ,mc_link_mc_req_entries_addr_gp, mc_link_mc_req_fifo_addr_gp
                    ,mc_link_mc_rsp_entries_addr_gp, mc_link_mc_rsp_fifo_addr_gp
                    ,mc_link_bp_req_credits_addr_gp, mc_link_bp_req_fifo_addr_gp
                    })
     )
   register
    (.*
     ,.r_v_o({endpoint_credits_r_v_lo
              ,bp_rsp_credits_r_v_lo, bp_rsp_data_r_v_lo
              ,mc_req_entries_r_v_lo, mc_req_data_r_v_lo
              ,mc_rsp_entries_r_v_lo, mc_rsp_data_r_v_lo
              ,bp_req_credits_r_v_lo, bp_req_data_r_v_lo
              })
     ,.w_v_o({endpoint_credits_w_v_lo
              ,bp_rsp_credits_w_v_lo, bp_rsp_data_w_v_lo
              ,mc_req_entries_w_v_lo, mc_req_data_w_v_lo
              ,mc_rsp_entries_w_v_lo, mc_rsp_data_w_v_lo
              ,bp_req_credits_w_v_lo, bp_req_data_w_v_lo
              })
     ,.addr_o(addr_lo)
     ,.size_o()
     ,.data_o(data_lo)
     ,.data_i(data_li)
     );

  // Make into synchronous read
  logic mc_req_entries_r_v_r, mc_req_data_r_v_r;
  logic mc_rsp_entries_r_v_r, mc_rsp_data_r_v_r;
  bsg_dff
   #(.width_p(4))
   sync_reg
    (.clk_i(clk_i)
     ,.data_i({mc_req_entries_r_v_lo, mc_req_data_r_v_lo
               ,mc_rsp_entries_r_v_lo, mc_rsp_data_r_v_lo
               })
     ,.data_o({mc_req_entries_r_v_r, mc_req_data_r_v_r
               ,mc_rsp_entries_r_v_r, mc_rsp_data_r_v_r
               })
     );

  logic [bedrock_fill_width_p-1:0] mc_req_lo;
  logic mc_req_v_lo, mc_req_ready_li;
  logic [bedrock_fill_width_p-1:0] mc_rsp_lo;
  logic mc_rsp_v_lo, mc_rsp_ready_li;
  logic [bedrock_fill_width_p-1:0] host_req_li;
  logic host_req_v_li, host_req_ready_lo;
  logic [bedrock_fill_width_p-1:0] host_rsp_li;
  logic host_rsp_v_li, host_rsp_ready_lo;
  logic [`BSG_WIDTH(32)-1:0] credits_used_lo;
  bsg_manycore_endpoint_to_fifos
   #(.fifo_width_p(2*bedrock_fill_width_p)
     ,.host_width_p(bedrock_fill_width_p)
     ,.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.addr_width_p(addr_width_p)
     ,.data_width_p(data_width_p)
     ,.ep_fifo_els_p(4) // Arbitrary for now
     ,.credit_counter_width_p(`BSG_WIDTH(32))
     ,.rev_fifo_els_p(3)
     ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
     )
   mc_ep_to_fifos
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     // fifo interface
     ,.mc_req_o(mc_req_lo)
     ,.mc_req_v_o(mc_req_v_lo)
     ,.mc_req_ready_i(mc_req_ready_li)

     ,.endpoint_req_i(host_req_li)
     ,.endpoint_req_v_i(host_req_v_li)
     ,.endpoint_req_ready_o(host_req_ready_lo)

     ,.endpoint_rsp_i(host_rsp_li)
     ,.endpoint_rsp_v_i(host_rsp_v_li)
     ,.endpoint_rsp_ready_o(host_rsp_ready_lo)

     ,.mc_rsp_o(mc_rsp_lo)
     ,.mc_rsp_v_o(mc_rsp_v_lo)
     ,.mc_rsp_ready_i(mc_rsp_ready_li)

     // manycore link
     ,.link_sif_i(link_sif_i)
     ,.link_sif_o(link_sif_o)

     // Parameterize
     ,.global_y_i(global_y_i)
     ,.global_x_i(global_x_i)

     ,.out_credits_used_o(credits_used_lo)
     );

  // Dequeue mc req and rsp fifos
  assign mc_rsp_ready_li = mc_rsp_data_r_v_r;
  assign mc_req_ready_li = mc_req_data_r_v_r;

  // Enqueue bp req and rsp fifos
  assign host_req_v_li = bp_req_data_w_v_lo;
  assign host_req_li   = data_lo;
  assign host_rsp_v_li = bp_rsp_data_w_v_lo;
  assign host_rsp_li   = data_lo;

  assign data_li[0] = '0; // Cannot read host req
  assign data_li[1] = host_req_ready_lo;
  assign data_li[2] = mc_rsp_lo;
  assign data_li[3] = mc_rsp_v_lo;
  assign data_li[4] = mc_req_lo;
  assign data_li[5] = mc_req_v_lo;
  assign data_li[6] = '0; // Cannot read host rsp
  assign data_li[7] = host_rsp_ready_lo;
  assign data_li[8] = credits_used_lo;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_manycore_fifo)

