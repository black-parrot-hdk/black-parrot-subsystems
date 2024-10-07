
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_pce_l15_if.svh"

module bp_piton_tile
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_unicore_parrotpiton_cfg // Warning: Change this at your own peril!
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   `declare_bp_pce_l15_if_widths(paddr_width_p, dword_width_gp)
   )
  (input                                               clk_i
   , input                                             reset_i
   , input [7:0]                                       config_coreid_x
   , input [7:0]                                       config_coreid_y
   , input [7:0]                                       config_coreid_flat

   , input                                             timer_irq_i
   , input                                             software_irq_i
   , input                                             m_external_irq_i
   , input                                             s_external_irq_i

   // Transducer -> L1.5
   , output logic [4:0]                                transducer_l15_rqtype
   , output logic                                      transducer_l15_nc
   , output logic [2:0]                                transducer_l15_size
   , output logic                                      transducer_l15_val
   , output logic [39:0]                               transducer_l15_address
   , output logic [63:0]                               transducer_l15_data
   , output logic [1:0]                                transducer_l15_l1rplway
   , output logic                                      transducer_l15_threadid
   , output logic [3:0]                                transducer_l15_amo_op
   , output logic                                      transducer_l15_prefetch
   , output logic                                      transducer_l15_invalidate_cacheline
   , output logic                                      transducer_l15_blockstore
   , output logic                                      transducer_l15_blockinitstore
   , output logic [63:0]                               transducer_l15_data_next_entry
   , output logic [32:0]                               transducer_l15_csm_data
   , input                                             l15_transducer_ack

   // L1.5 -> Transducer
   , input                                             l15_transducer_val
   , input [3:0]                                       l15_transducer_returntype
   , input [63:0]                                      l15_transducer_data_0
   , input [63:0]                                      l15_transducer_data_1
   , input [63:0]                                      l15_transducer_data_2
   , input [63:0]                                      l15_transducer_data_3
   , input                                             l15_transducer_noncacheable
   , input                                             l15_transducer_atomic
   , input                                             l15_transducer_threadid
   , input [11:0]                                      l15_transducer_inval_address_15_4
   , input                                             l15_transducer_inval_icache_inval
   , input                                             l15_transducer_inval_dcache_inval
   , input                                             l15_transducer_inval_icache_all_way
   , input                                             l15_transducer_inval_dcache_all_way
   , input [1:0]                                       l15_transducer_inval_way
   , output logic                                      transducer_l15_req_ack
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_fe_icache_engine_if(paddr_width_p, icache_tag_width_p, icache_sets_p, icache_assoc_p, icache_data_width_p, icache_block_width_p, icache_fill_width_p, icache_req_id_width_p);
  `declare_bp_be_dcache_engine_if(paddr_width_p, dcache_tag_width_p, dcache_sets_p, dcache_assoc_p, dcache_data_width_p, dcache_block_width_p, dcache_fill_width_p, dcache_req_id_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_pce_l15_if(paddr_width_p, dword_width_gp);

  bp_be_dcache_req_s dcache_req_lo;
  bp_fe_icache_req_s icache_req_lo;
  logic dcache_req_v_lo, dcache_req_yumi_li, dcache_req_lock_li, dcache_req_credits_full_li, dcache_req_credits_empty_li;
  logic icache_req_v_lo, icache_req_yumi_li, icache_req_lock_li, icache_req_credits_full_li, icache_req_credits_empty_li;

  bp_be_dcache_req_metadata_s dcache_req_metadata_lo;
  bp_fe_icache_req_metadata_s icache_req_metadata_lo;
  logic dcache_req_metadata_v_lo, icache_req_metadata_v_lo;

  bp_be_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_li;
  bp_fe_icache_tag_mem_pkt_s icache_tag_mem_pkt_li;
  logic dcache_tag_mem_pkt_v_li, dcache_tag_mem_pkt_yumi_lo;
  logic icache_tag_mem_pkt_v_li, icache_tag_mem_pkt_yumi_lo;
  bp_be_dcache_tag_info_s dcache_tag_mem_lo;
  bp_fe_icache_tag_info_s icache_tag_mem_lo;

  bp_be_dcache_data_mem_pkt_s dcache_data_mem_pkt_li;
  bp_fe_icache_data_mem_pkt_s icache_data_mem_pkt_li;
  logic dcache_data_mem_pkt_v_li, dcache_data_mem_pkt_yumi_lo;
  logic icache_data_mem_pkt_v_li, icache_data_mem_pkt_yumi_lo;
  logic [dcache_block_width_p-1:0] dcache_data_mem_lo;
  logic [icache_block_width_p-1:0] icache_data_mem_lo;

  bp_be_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_li;
  bp_fe_icache_stat_mem_pkt_s icache_stat_mem_pkt_li;
  logic dcache_stat_mem_pkt_v_li, dcache_stat_mem_pkt_yumi_lo;
  logic icache_stat_mem_pkt_v_li, icache_stat_mem_pkt_yumi_lo;
  bp_be_dcache_stat_info_s dcache_stat_mem_lo;
  bp_fe_icache_stat_info_s icache_stat_mem_lo;

  logic [paddr_width_p-1:0] dcache_req_addr_li, icache_req_addr_li;

  logic dcache_req_last_li, icache_req_last_li;
  logic dcache_req_critical_li, icache_req_critical_li;

  bp_pce_l15_req_s [1:0] pce_l15_req_lo;
  logic [1:0] pce_l15_req_v_lo, pce_l15_req_ready_and_li;
  bp_l15_pce_ret_s [1:0] l15_pce_ret_li;
  logic [1:0] l15_pce_ret_v_li, l15_pce_ret_ready_and_lo;

  bp_pce_l15_req_s [1:1] _pce_l15_req_lo;
  logic [1:1] _pce_l15_req_v_lo, _pce_l15_req_ready_and_li;
  bp_l15_pce_ret_s [1:1] _l15_pce_ret_li;
  logic [1:1] _l15_pce_ret_v_li, _l15_pce_ret_ready_and_lo;

  logic freezen_r;
  wire int_wakeup = l15_transducer_val & (l15_transducer_returntype == e_int_ret);
  bsg_dff_reset_set_clear
   #(.width_p(1))
   unfreeze_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(int_wakeup)
     ,.clear_i(1'b0)
     ,.data_o(freezen_r)
     );
  wire freeze = ~freezen_r;

  localparam boot_pc_lp = 32'h0010000;
  bp_cfg_bus_s cfg_bus_lo;
  assign cfg_bus_lo =
    '{freeze      : freeze
      ,npc        : boot_pc_lp
      ,core_id    : config_coreid_flat
      ,icache_id  : 1'b0
      ,icache_mode: e_lce_mode_normal
      ,dcache_id  : 1'b1
      ,dcache_mode: e_lce_mode_normal
      ,cce_id     : '0
      ,cce_mode   : e_cce_mode_uncached
      ,hio_mask   : '1
      ,did         : 1'b1
      };

  wire posedge_clk =  clk_i;
  wire negedge_clk = ~clk_i;

  bp_core_minimal
   #(.bp_params_p(bp_params_p))
   core_minimal
    (.clk_i(posedge_clk)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_lo)

     ,.icache_req_o(icache_req_lo)
     ,.icache_req_v_o(icache_req_v_lo)
     ,.icache_req_yumi_i(icache_req_yumi_li)
     ,.icache_req_lock_i(icache_req_lock_li)
     ,.icache_req_metadata_o(icache_req_metadata_lo)
     ,.icache_req_metadata_v_o(icache_req_metadata_v_lo)
     ,.icache_req_id_i(icache_req_id_li)
     ,.icache_req_critical_i(icache_req_critical_li)
     ,.icache_req_last_i(icache_req_last_li)
     ,.icache_req_credits_full_i(icache_req_credits_full_li)
     ,.icache_req_credits_empty_i(icache_req_credits_empty_li)

     ,.icache_tag_mem_pkt_i(icache_tag_mem_pkt_li)
     ,.icache_tag_mem_pkt_v_i(icache_tag_mem_pkt_v_li)
     ,.icache_tag_mem_pkt_yumi_o(icache_tag_mem_pkt_yumi_lo)
     ,.icache_tag_mem_o(icache_tag_mem_lo)

     ,.icache_data_mem_pkt_i(icache_data_mem_pkt_li)
     ,.icache_data_mem_pkt_v_i(icache_data_mem_pkt_v_li)
     ,.icache_data_mem_pkt_yumi_o(icache_data_mem_pkt_yumi_lo)
     ,.icache_data_mem_o(icache_data_mem_lo)

     ,.icache_stat_mem_pkt_v_i(icache_stat_mem_pkt_v_li)
     ,.icache_stat_mem_pkt_i(icache_stat_mem_pkt_li)
     ,.icache_stat_mem_pkt_yumi_o(icache_stat_mem_pkt_yumi_lo)
     ,.icache_stat_mem_o(icache_stat_mem_lo)

     ,.dcache_req_o(dcache_req_lo)
     ,.dcache_req_v_o(dcache_req_v_lo)
     ,.dcache_req_yumi_i(dcache_req_yumi_li)
     ,.dcache_req_lock_i(dcache_req_lock_li)
     ,.dcache_req_metadata_o(dcache_req_metadata_lo)
     ,.dcache_req_metadata_v_o(dcache_req_metadata_v_lo)
     ,.dcache_req_id_i(dcache_req_id_li)
     ,.dcache_req_critical_i(dcache_req_critical_li)
     ,.dcache_req_last_i(dcache_req_last_li)
     ,.dcache_req_credits_full_i(dcache_req_credits_full_li)
     ,.dcache_req_credits_empty_i(dcache_req_credits_empty_li)

     ,.dcache_tag_mem_pkt_i(dcache_tag_mem_pkt_li)
     ,.dcache_tag_mem_pkt_v_i(dcache_tag_mem_pkt_v_li)
     ,.dcache_tag_mem_pkt_yumi_o(dcache_tag_mem_pkt_yumi_lo)
     ,.dcache_tag_mem_o(dcache_tag_mem_lo)

     ,.dcache_data_mem_pkt_i(dcache_data_mem_pkt_li)
     ,.dcache_data_mem_pkt_v_i(dcache_data_mem_pkt_v_li)
     ,.dcache_data_mem_pkt_yumi_o(dcache_data_mem_pkt_yumi_lo)
     ,.dcache_data_mem_o(dcache_data_mem_lo)

     ,.dcache_stat_mem_pkt_v_i(dcache_stat_mem_pkt_v_li)
     ,.dcache_stat_mem_pkt_i(dcache_stat_mem_pkt_li)
     ,.dcache_stat_mem_pkt_yumi_o(dcache_stat_mem_pkt_yumi_lo)
     ,.dcache_stat_mem_o(dcache_stat_mem_lo)

     ,.debug_irq_i(1'b0)
     ,.timer_irq_i(timer_irq_i)
     ,.software_irq_i(software_irq_i)
     ,.m_external_irq_i(m_external_irq_i)
     ,.s_external_irq_i(s_external_irq_i)
     );

  bp_pce
   #(.bp_params_p(bp_params_p)
    ,.assoc_p(icache_assoc_p)
    ,.sets_p(icache_sets_p)
    ,.block_width_p(icache_block_width_p)
    ,.fill_width_p(icache_fill_width_p)
    ,.data_width_p(icache_data_width_p)
    ,.tag_width_p(icache_tag_width_p)
    ,.id_width_p(icache_req_id_width_p)
    ,.pce_id_p(0)
    )
   icache_pce
   (.clk_i(posedge_clk)
    ,.reset_i(reset_i)

    ,.cache_req_i(icache_req_lo)
    ,.cache_req_v_i(icache_req_v_lo)
    ,.cache_req_yumi_o(icache_req_yumi_li)
    ,.cache_req_lock_o(icache_req_lock_li)
    ,.cache_req_metadata_i(icache_req_metadata_lo)
    ,.cache_req_metadata_v_i(icache_req_metadata_v_lo)
    ,.cache_req_addr_o(icache_req_addr_li)
    ,.cache_req_critical_o(icache_req_critical_li)
    ,.cache_req_last_o(icache_req_last_li)
    ,.cache_req_credits_full_o(icache_req_credits_full_li)
    ,.cache_req_credits_empty_o(icache_req_credits_empty_li)

    ,.tag_mem_pkt_o(icache_tag_mem_pkt_li)
    ,.tag_mem_pkt_v_o(icache_tag_mem_pkt_v_li)
    ,.tag_mem_pkt_yumi_i(icache_tag_mem_pkt_yumi_lo)

    ,.data_mem_pkt_o(icache_data_mem_pkt_li)
    ,.data_mem_pkt_v_o(icache_data_mem_pkt_v_li)
    ,.data_mem_pkt_yumi_i(icache_data_mem_pkt_yumi_lo)

    ,.stat_mem_pkt_o(icache_stat_mem_pkt_li)
    ,.stat_mem_pkt_v_o(icache_stat_mem_pkt_v_li)
    ,.stat_mem_pkt_yumi_i(icache_stat_mem_pkt_yumi_lo)

    ,.pce_l15_req_o(pce_l15_req_lo[0])
    ,.pce_l15_req_v_o(pce_l15_req_v_lo[0])
    ,.pce_l15_req_ready_and_i(pce_l15_req_ready_and_li[0])

    ,.l15_pce_ret_i(l15_pce_ret_li[0])
    ,.l15_pce_ret_v_i(l15_pce_ret_v_li[0])
    ,.l15_pce_ret_ready_and_o(l15_pce_ret_ready_and_lo[0])
    );

  bp_pce
   #(.bp_params_p(bp_params_p)
    ,.assoc_p(dcache_assoc_p)
    ,.sets_p(dcache_sets_p)
    ,.block_width_p(dcache_block_width_p)
    ,.fill_width_p(dcache_fill_width_p)
    ,.data_width_p(dcache_data_width_p)
    ,.tag_width_p(dcache_tag_width_p)
    ,.id_width_p(dcache_req_id_width_p)
    ,.pce_id_p(1)
    )
   dcache_pce
   (.clk_i(negedge_clk)
    ,.reset_i(reset_i)

    ,.cache_req_i(dcache_req_lo)
    ,.cache_req_v_i(dcache_req_v_lo)
    ,.cache_req_yumi_o(dcache_req_yumi_li)
    ,.cache_req_lock_o(dcache_req_lock_li)
    ,.cache_req_metadata_i(dcache_req_metadata_lo)
    ,.cache_req_metadata_v_i(dcache_req_metadata_v_lo)
    ,.cache_req_addr_o(dcache_req_addr_li)
    ,.cache_req_critical_o(dcache_req_critical_li)
    ,.cache_req_last_o(dcache_req_last_li)
    ,.cache_req_credits_full_o(dcache_req_credits_full_li)
    ,.cache_req_credits_empty_o(dcache_req_credits_empty_li)

    ,.tag_mem_pkt_o(dcache_tag_mem_pkt_li)
    ,.tag_mem_pkt_v_o(dcache_tag_mem_pkt_v_li)
    ,.tag_mem_pkt_yumi_i(dcache_tag_mem_pkt_yumi_lo)

    ,.data_mem_pkt_o(dcache_data_mem_pkt_li)
    ,.data_mem_pkt_v_o(dcache_data_mem_pkt_v_li)
    ,.data_mem_pkt_yumi_i(dcache_data_mem_pkt_yumi_lo)

    ,.stat_mem_pkt_o(dcache_stat_mem_pkt_li)
    ,.stat_mem_pkt_v_o(dcache_stat_mem_pkt_v_li)
    ,.stat_mem_pkt_yumi_i(dcache_stat_mem_pkt_yumi_lo)

    ,.pce_l15_req_o(_pce_l15_req_lo[1])
    ,.pce_l15_req_v_o(_pce_l15_req_v_lo[1])
    ,.pce_l15_req_ready_and_i(_pce_l15_req_ready_and_li[1])

    ,.l15_pce_ret_i(_l15_pce_ret_li[1])
    ,.l15_pce_ret_v_i(_l15_pce_ret_v_li[1])
    ,.l15_pce_ret_ready_and_o(_l15_pce_ret_ready_and_lo[1])
    );

  bsg_dlatch
   #(.width_p($bits(bp_pce_l15_req_s)+2), .i_know_this_is_a_bad_idea_p(1))
   posedge_latch
    (.clk_i(posedge_clk)
     ,.data_i({_pce_l15_req_lo[1], _pce_l15_req_v_lo[1], pce_l15_req_ready_and_li[1]})
     ,.data_o({pce_l15_req_lo[1], pce_l15_req_v_lo[1], _pce_l15_req_ready_and_li[1]})
     );

  // Synchronize back to negedge clk
  bsg_two_fifo
   #(.width_p($bits(bp_l15_pce_ret_s)))
   negedge_fifo
    (.clk_i(negedge_clk)
     ,.reset_i(reset_i)

     ,.data_i(l15_pce_ret_li[1])
     ,.v_i(l15_pce_ret_v_li[1])
     ,.ready_param_o(l15_pce_ret_ready_and_lo[1])

     ,.data_o(_l15_pce_ret_li[1])
     ,.v_o(_l15_pce_ret_v_li[1])
     ,.yumi_i(_l15_pce_ret_ready_and_lo[1] & _l15_pce_ret_v_li[1])
     );

  // PCE -> L1.5 - Arbitration logic
  // 2 elements to support writeback
  bp_pce_l15_req_s [1:0] fifo_lo;
  logic [1:0] fifo_v_lo, fifo_yumi_li;
  for (genvar i = 0; i < 2; i++)
    begin : fifo
      bsg_two_fifo
       #(.width_p($bits(bp_pce_l15_req_s)))
       mem_fifo
        (.clk_i(posedge_clk)
         ,.reset_i(reset_i)

         ,.data_i(pce_l15_req_lo[i])
         ,.v_i(pce_l15_req_v_lo[i])
         ,.ready_param_o(pce_l15_req_ready_and_li[i])

         ,.data_o(fifo_lo[i])
         ,.v_o(fifo_v_lo[i])
         ,.yumi_i(fifo_yumi_li[i])
         );
    end

  logic [1:0] fifo_grants_lo;
  bsg_arb_fixed
   #(.inputs_p(2), .lo_to_hi_p(0))
   cmd_arbiter
    (.ready_then_i(1'b1)
     ,.reqs_i(fifo_v_lo)
     ,.grants_o(fifo_grants_lo)
     );

  bp_pce_l15_req_s fifo_selected_lo;
  bsg_mux_one_hot
   #(.width_p($bits(bp_pce_l15_req_s)), .els_p(2))
   cmd_select
    (.data_i(fifo_lo)
     ,.sel_one_hot_i(fifo_grants_lo)
     ,.data_o(fifo_selected_lo)
     );

  // PCE -> L1.5 signals
  assign transducer_l15_rqtype = fifo_selected_lo.rqtype;
  assign transducer_l15_nc = fifo_selected_lo.nc;
  assign transducer_l15_size = fifo_selected_lo.size;
  assign transducer_l15_address = fifo_selected_lo.address;
  assign transducer_l15_data = fifo_selected_lo.data;
  assign transducer_l15_l1rplway = fifo_selected_lo.l1rplway;
  assign transducer_l15_val = |fifo_grants_lo;
  assign transducer_l15_amo_op = fifo_selected_lo.amo_op;
  assign fifo_yumi_li[0] = fifo_grants_lo[0] & l15_transducer_ack;
  assign fifo_yumi_li[1] = fifo_grants_lo[1] & l15_transducer_ack;

  // Unused signals
  assign transducer_l15_threadid = '0;
  assign transducer_l15_prefetch = '0;
  assign transducer_l15_invalidate_cacheline = '0;
  assign transducer_l15_blockstore = '0;
  assign transducer_l15_blockinitstore = '0;
  assign transducer_l15_data_next_entry = '0;
  assign transducer_l15_csm_data = '0;

  // L1.5 -> PCE
  for (genvar i = 0; i < 2; i++)
    begin : l15_pce_ret
      assign l15_pce_ret_li[i].rtntype = bp_l15_pce_ret_type_e'(l15_transducer_returntype);
      assign l15_pce_ret_li[i].noncacheable = l15_transducer_noncacheable;
      assign l15_pce_ret_li[i].data_0 = l15_transducer_data_0;
      assign l15_pce_ret_li[i].data_1 = l15_transducer_data_1;
      assign l15_pce_ret_li[i].data_2 = l15_transducer_data_2;
      assign l15_pce_ret_li[i].data_3 = l15_transducer_data_3;
      assign l15_pce_ret_li[i].threadid = l15_transducer_threadid;
      assign l15_pce_ret_li[i].atomic = l15_transducer_atomic;
      assign l15_pce_ret_li[i].inval_address_15_4 = l15_transducer_inval_address_15_4;
      assign l15_pce_ret_li[i].inval_icache_inval = l15_transducer_inval_icache_inval;
      assign l15_pce_ret_li[i].inval_dcache_inval = l15_transducer_inval_dcache_inval;
      assign l15_pce_ret_li[i].inval_icache_all_way = l15_transducer_inval_icache_all_way;
      assign l15_pce_ret_li[i].inval_dcache_all_way = l15_transducer_inval_dcache_all_way;
      assign l15_pce_ret_li[i].inval_way = l15_transducer_inval_way;
    end
  // Need to enqueue invalidates onto both
  wire pce0_req_ack = l15_pce_ret_ready_and_lo[0] & l15_pce_ret_ready_and_lo[1] & l15_pce_ret_v_li[0];
  wire pce1_req_ack = l15_pce_ret_ready_and_lo[0] & l15_pce_ret_ready_and_lo[1] & l15_pce_ret_v_li[1];
  // Autoack wakeup interrupt
  assign transducer_l15_req_ack = pce0_req_ack | pce1_req_ack | int_wakeup;

  assign l15_pce_ret_v_li[0] = l15_transducer_val
    && (l15_transducer_inval_icache_inval
        || l15_transducer_inval_icache_all_way
        || l15_transducer_returntype inside {e_ifill_ret}
        );

  assign l15_pce_ret_v_li[1] = l15_transducer_val
    && (l15_transducer_inval_dcache_inval
        || l15_transducer_inval_dcache_all_way
        || l15_transducer_returntype inside {e_load_ret, e_st_ack, e_atomic_ret}
        );

endmodule

