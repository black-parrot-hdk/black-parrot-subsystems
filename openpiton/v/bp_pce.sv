// This module describes the P-Mesh Cache Engine (PCE) which is the interface
// between the L1 Caches of BlackParrot and the L1.5 Cache of OpenPiton

`include "bp_common_defines.svh"
`include "bp_pce_l15_if.svh"

module bp_pce
  import bp_common_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_unicore_parrotpiton_cfg
   , parameter `BSG_INV_PARAM(sets_p)
   , parameter `BSG_INV_PARAM(assoc_p)
   , parameter `BSG_INV_PARAM(fill_width_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   , parameter `BSG_INV_PARAM(ctag_width_p)
   , parameter `BSG_INV_PARAM(pce_id_p) // 0 = I$, 1 = D$

   // Should not need to change from default
   , parameter metadata_latency_p = 1
   , parameter req_fifo_els_p = pce_id_p == 0 ? 1 : 8
   , parameter ret_fifo_els_p = pce_id_p == 0 ? 4 : 8
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)
   `declare_bp_pce_l15_if_widths(paddr_width_p, dword_width_gp)

   // Cache parameters
   , localparam bank_width_lp = block_width_p / assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_gp
   , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(assoc_p)
   , localparam block_offset_width_lp = word_offset_width_lp + byte_offset_width_lp
   , localparam index_width_lp = `BSG_SAFE_CLOG2(sets_p)
   , localparam way_width_lp = `BSG_SAFE_CLOG2(assoc_p)
   )
  ( input                                          clk_i
  , input                                          reset_i

  // Cache side
  , input [cache_req_width_lp-1:0]                 cache_req_i
  , input                                          cache_req_v_i
  , output logic                                   cache_req_ready_and_o
  , output logic                                   cache_req_busy_o
  , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i
  , input                                          cache_req_metadata_v_i
  , output logic                                   cache_req_complete_o
  , output logic                                   cache_req_critical_o
  , output logic                                   cache_req_credits_full_o
  , output logic                                   cache_req_credits_empty_o

  // Cache side
  , output logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
  , output logic                                   data_mem_pkt_v_o
  , input                                          data_mem_pkt_yumi_i

  , output logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
  , output logic                                   tag_mem_pkt_v_o
  , input                                          tag_mem_pkt_yumi_i

  , output logic [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
  , output logic                                   stat_mem_pkt_v_o
  , input                                          stat_mem_pkt_yumi_i

  // PCE -> L1.5
  , output logic                                   pce_l15_req_v_o
  , output logic [bp_pce_l15_req_width_lp-1:0]     pce_l15_req_o
  , input                                          pce_l15_req_ready_and_i

  // L1.5 -> PCE
  , input                                          l15_pce_ret_v_i
  , input [bp_l15_pce_ret_width_lp-1:0]            l15_pce_ret_i
  , output logic                                   l15_pce_ret_ready_and_o
  );

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);
  `declare_bp_pce_l15_if(paddr_width_p, dword_width_gp);

  `bp_cast_i(bp_cache_req_s, cache_req);
  `bp_cast_i(bp_cache_req_metadata_s, cache_req_metadata);
  `bp_cast_o(bp_cache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_o(bp_cache_tag_mem_pkt_s, tag_mem_pkt);
  `bp_cast_o(bp_cache_stat_mem_pkt_s, stat_mem_pkt);
  `bp_cast_o(bp_pce_l15_req_s, pce_l15_req);
  `bp_cast_i(bp_l15_pce_ret_s, l15_pce_ret);

  logic cache_req_done, cache_req_v_lo;
  bp_cache_req_s cache_req_lo;
  bsg_two_fifo
   #(.width_p($bits(bp_cache_req_s)))
   cache_req_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(cache_req_v_i)
     ,.data_i(cache_req_cast_i)
     ,.ready_o(cache_req_ready_and_o)

     ,.v_o(cache_req_v_lo)
     ,.data_o(cache_req_lo)
     ,.yumi_i(cache_req_done)
     );

  bp_cache_req_metadata_s cache_req_metadata_lo;
  bsg_two_fifo
   #(.width_p($bits(bp_cache_req_metadata_s)))
   cache_req_metadata_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(cache_req_metadata_v_i)
     ,.data_i(cache_req_metadata_cast_i)
     ,.ready_o(/* Same size as cache_req by construction */)

     ,.v_o(/* Follows cache_req by construction */)
     ,.data_o(cache_req_metadata_lo)
     ,.yumi_i(cache_req_done)
     );

  // Arbitrarily sized for now, enqueue many invalidations?
  bp_l15_pce_ret_s l15_pce_ret_li;
  logic l15_pce_ret_v_li, l15_pce_ret_yumi_lo;
  bsg_fifo_1r1w_small
   #(.width_p($bits(bp_l15_pce_ret_s)), .els_p(ret_fifo_els_p))
   resp_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(l15_pce_ret_cast_i)
    ,.v_i(l15_pce_ret_v_i)
    ,.ready_o(l15_pce_ret_ready_and_o)

    ,.data_o(l15_pce_ret_li)
    ,.v_o(l15_pce_ret_v_li)
    ,.yumi_i(l15_pce_ret_yumi_lo)
    );

  logic [index_width_lp-1:0] index_cnt;
  logic index_up;
  bsg_counter_clear_up
    #(.max_val_p(sets_p-1)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
    index_counter
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i('0)
     ,.up_i(index_up)

     ,.count_o(index_cnt)
     );
  wire index_done = (index_cnt == sets_p-1);

  enum logic [2:0] {e_reset, e_init, e_clear, e_ready, e_store_wait, e_read_wait} state_n, state_r;
  wire is_reset         = (state_r == e_reset);
  wire is_init          = (state_r == e_init);
  wire is_clear         = (state_r == e_clear);
  wire is_ready         = (state_r == e_ready);
  wire is_store_wait    = (state_r == e_store_wait);
  wire is_read_wait     = (state_r == e_read_wait);

  wire load_resp_v_li  = l15_pce_ret_v_li & l15_pce_ret_li.rtntype inside {e_load_ret, e_ifill_ret, e_atomic_ret};
  wire icache_inval_li = l15_pce_ret_v_li & (pce_id_p == 0) & l15_pce_ret_li.inval_icache_inval;
  wire dcache_inval_li = l15_pce_ret_v_li & (pce_id_p == 1) & l15_pce_ret_li.inval_dcache_inval;
  wire icache_clear_li = l15_pce_ret_v_li & (pce_id_p == 0) & l15_pce_ret_li.inval_icache_all_way;
  wire dcache_clear_li = l15_pce_ret_v_li & (pce_id_p == 1) & l15_pce_ret_li.inval_dcache_all_way;
  wire inval_v_li      = icache_inval_li | dcache_inval_li;
  wire clear_v_li      = icache_clear_li | dcache_clear_li;
  wire is_ifill_ret_nc = l15_pce_ret_v_li & (l15_pce_ret_li.rtntype == e_ifill_ret) & l15_pce_ret_li.noncacheable;
  wire is_load_ret_nc  = l15_pce_ret_v_li & (l15_pce_ret_li.rtntype == e_load_ret) & l15_pce_ret_li.noncacheable;
  wire is_ifill_ret    = l15_pce_ret_v_li & (l15_pce_ret_li.rtntype == e_ifill_ret) & ~l15_pce_ret_li.noncacheable;
  wire is_load_ret     = l15_pce_ret_v_li & (l15_pce_ret_li.rtntype == e_load_ret) & ~l15_pce_ret_li.noncacheable;
  wire is_amo_lr_ret = l15_pce_ret_v_li & (l15_pce_ret_li.rtntype == e_atomic_ret) & l15_pce_ret_li.atomic & !l15_pce_ret_li.noncacheable;
  // Fetch + Op atomics also set the noncacheable bit as 1
  wire is_amo_op_ret   = l15_pce_ret_v_li & (l15_pce_ret_li.rtntype == e_atomic_ret) & l15_pce_ret_li.atomic & l15_pce_ret_li.noncacheable;

  wire miss_load_v_r  = cache_req_v_lo & cache_req_lo.msg_type inside {e_miss_load};
  wire miss_store_v_r = cache_req_v_lo & cache_req_lo.msg_type inside {e_miss_store};
  wire miss_v_r       = miss_load_v_r | miss_store_v_r;
  wire uc_load_v_r    = cache_req_v_lo & cache_req_lo.msg_type inside {e_uc_load};
  wire uc_store_v_r   = cache_req_v_lo & cache_req_lo.msg_type inside {e_uc_store} & cache_req_lo.subop inside {e_req_store};
  wire wt_store_v_r   = cache_req_v_lo & cache_req_lo.msg_type inside {e_wt_store};
  wire noret_amo_v_r  = cache_req_v_lo & cache_req_lo.msg_type inside {e_uc_store} & cache_req_lo.subop inside {e_req_amosc, e_req_amoswap, e_req_amoadd, e_req_amoxor, e_req_amoand, e_req_amoor, e_req_amomin, e_req_amomax, e_req_amominu, e_req_amomaxu};
  wire amo_lr_v_r     = cache_req_v_lo & cache_req_lo.msg_type inside {e_uc_amo} & cache_req_lo.subop inside {e_req_amolr};
  wire amo_sc_v_r     = cache_req_v_lo & cache_req_lo.msg_type inside {e_uc_amo} & cache_req_lo.subop inside {e_req_amosc};
  wire amo_op_v_r     = cache_req_v_lo & cache_req_lo.msg_type inside {e_uc_amo} & cache_req_lo.subop inside {e_req_amoswap, e_req_amoadd, e_req_amoxor, e_req_amoand, e_req_amoor, e_req_amomin, e_req_amomax, e_req_amominu, e_req_amomaxu};

  // Don't send complete_o on non-blocking requests
  assign cache_req_complete_o = cache_req_done & ~(uc_store_v_r | noret_amo_v_r | wt_store_v_r);

  // We can't accept any more requests
  assign cache_req_credits_full_o  =  cache_req_v_lo & ~pce_l15_req_ready_and_i;
  // We have finished processing all of our requests
  assign cache_req_credits_empty_o = ~cache_req_v_lo;
  // Force immediate acceptance of invalidations
  assign cache_req_busy_o          = inval_v_li;

  bp_pce_l15_amo_type_e amo_type;
  always_comb
    case (cache_req_lo.subop)
      e_req_amoswap: amo_type = e_amo_op_swap;
      e_req_amoadd : amo_type = e_amo_op_add;
      e_req_amoand : amo_type = e_amo_op_and;
      e_req_amoor  : amo_type = e_amo_op_or;
      e_req_amoxor : amo_type = e_amo_op_xor;
      e_req_amomax : amo_type = e_amo_op_max;
      e_req_amomin : amo_type = e_amo_op_min;
      e_req_amomaxu: amo_type = e_amo_op_maxu;
      e_req_amominu: amo_type = e_amo_op_minu;
      e_req_amolr  : amo_type = e_amo_op_lr;
      e_req_amosc  : amo_type = e_amo_op_sc;
      default      : amo_type = e_amo_op_none;
    endcase

  bp_pce_l15_req_size_e req_size;
  always_comb
    case (cache_req_lo.size)
      e_size_1B : req_size = e_l15_size_1B;
      e_size_2B : req_size = e_l15_size_2B;
      e_size_4B : req_size = e_l15_size_4B;
      e_size_8B : req_size = e_l15_size_8B;
      e_size_16B: req_size = e_l15_size_16B;
      // e_size_32B:
      default: req_size = e_l15_size_32B;
    endcase

  // OpenPiton is big endian whereas BlackParrot is little endian
  logic [dword_width_gp-1:0] req_data;
  always_comb
    case (cache_req_lo.size)
      e_size_1B: req_data = {8{cache_req_lo.data[0+:8]}};
      e_size_2B: req_data = {4{cache_req_lo.data[0+:8], cache_req_lo.data[8+:8]}};
      e_size_4B: req_data = {2{cache_req_lo.data[0+:8], cache_req_lo.data[8+:8]
                               ,cache_req_lo.data[16+:8], cache_req_lo.data[24+:8]
                               }};
      //e_size_8B:
      default: req_data = {cache_req_lo.data[0+:8], cache_req_lo.data[8+:8]
                           ,cache_req_lo.data[16+:8], cache_req_lo.data[24+:8]
                           ,cache_req_lo.data[32+:8], cache_req_lo.data[40+:8]
                           ,cache_req_lo.data[48+:8], cache_req_lo.data[56+:8]
                           };
    endcase

  logic [3:0][63:0] fill_data_le;
  logic [fill_width_p-1:0] fill_data, fill_data_packed;
  always_comb
    begin
      fill_data_le[0] = {<<8{l15_pce_ret_li.data_0}};
      fill_data_le[1] = {<<8{l15_pce_ret_li.data_1}};
      fill_data_le[2] = {<<8{l15_pce_ret_li.data_2}};
      fill_data_le[3] = {<<8{l15_pce_ret_li.data_3}};

      fill_data = fill_data_le;

      case (cache_req_lo.size)
        e_size_1B : fill_data_packed = {fill_width_p/8{fill_data[0+:8]}};
        e_size_2B : fill_data_packed = {fill_width_p/16{fill_data[0+:16]}};
        e_size_4B : fill_data_packed = {fill_width_p/32{fill_data[0+:32]}};
        e_size_8B : fill_data_packed = {fill_width_p/64{fill_data[0+:64]}};
        e_size_16B: fill_data_packed = {fill_width_p/128{fill_data[0+:128]}};
        //e_size_32B:
        default: fill_data_packed = fill_data;
      endcase
    end

  // This is definitely over-provisioned, exponential?
  localparam backoff_cnt_lp = 63;
  logic [`BSG_WIDTH(backoff_cnt_lp)-1:0] count_lo;
  logic cache_lock;
  wire backoff = amo_sc_v_r & data_mem_pkt_yumi_i & (data_mem_pkt_cast_o.data != '0);
  bsg_counter_clear_up
   #(.max_val_p(backoff_cnt_lp)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   sc_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(backoff)
     ,.up_i(cache_lock)
     ,.count_o(count_lo)
     );
  assign cache_lock = (count_lo < backoff_cnt_lp);

  always_comb
    begin
      index_up = '0;

      tag_mem_pkt_cast_o  = '0;
      tag_mem_pkt_v_o     = '0;
      data_mem_pkt_cast_o = '0;
      data_mem_pkt_v_o    = '0;
      stat_mem_pkt_cast_o = '0;
      stat_mem_pkt_v_o    = '0;

      cache_req_done = '0;

      cache_req_critical_o = '0;

      pce_l15_req_cast_o = '0;
      pce_l15_req_v_o = '0;

      l15_pce_ret_yumi_lo = '0;
      state_n = state_r;

      unique case (state_r)
        e_reset:
          begin
            state_n = e_init;
          end
        e_init, e_clear:
          begin
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            tag_mem_pkt_cast_o.index  = index_cnt;
            tag_mem_pkt_v_o = 1'b1;

            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            stat_mem_pkt_cast_o.index  = index_cnt;
            stat_mem_pkt_v_o = 1'b1;

            index_up = tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i;

            cache_req_done = is_clear & (index_done & index_up);

            state_n = (index_done & index_up) ? e_ready : state_r;
          end

        e_ready:
          begin
                pce_l15_req_v_o = cache_req_v_lo;

                pce_l15_req_cast_o.data     = req_data;
                pce_l15_req_cast_o.size     = req_size;
                pce_l15_req_cast_o.amo_op   = amo_type;
                pce_l15_req_cast_o.l1rplway = (pce_id_p == 1)
                                              ? {cache_req_lo.addr[11], cache_req_metadata_lo.hit_or_repl_way}
                                              : cache_req_metadata_lo.hit_or_repl_way;

            if (wt_store_v_r | uc_store_v_r | noret_amo_v_r)
              begin
                pce_l15_req_cast_o.rqtype  = noret_amo_v_r ? e_amo_req : e_store_req;
                pce_l15_req_cast_o.nc      = uc_store_v_r | noret_amo_v_r;
                pce_l15_req_cast_o.address = cache_req_lo.addr;

                state_n = (pce_l15_req_ready_and_i & pce_l15_req_v_o) ? e_store_wait : state_r;
              end
            else if (uc_load_v_r)
              begin
                pce_l15_req_cast_o.rqtype = (pce_id_p == 1) ? e_load_req : e_imiss_req;
                pce_l15_req_cast_o.nc = 1'b1;
                pce_l15_req_cast_o.address = cache_req_lo.addr;

                state_n = (pce_l15_req_ready_and_i & pce_l15_req_v_o) ? e_read_wait : state_r;
              end
            else if (miss_v_r)
              begin
                pce_l15_req_cast_o.rqtype = (pce_id_p == 1) ? e_load_req : e_imiss_req;
                pce_l15_req_cast_o.nc = 1'b0;
                pce_l15_req_cast_o.address = (pce_id_p == 1)
                                             ? {cache_req_lo.addr[paddr_width_p-1:4], 4'b0}
                                             : {cache_req_lo.addr[paddr_width_p-1:5], 5'b0};

                state_n = (pce_l15_req_ready_and_i & pce_l15_req_v_o) ? e_read_wait : state_r;
              end
            else if (amo_lr_v_r | amo_sc_v_r | amo_op_v_r)
              begin
                pce_l15_req_cast_o.rqtype = e_amo_req;
                // Fetch + Op atomics need to have the nc bit set
                pce_l15_req_cast_o.nc = 1'b1;
                pce_l15_req_cast_o.address = cache_req_lo.addr;

                state_n = (pce_l15_req_ready_and_i & pce_l15_req_v_o) ? e_read_wait : state_r;
              end
          end

        e_store_wait:
          begin
            l15_pce_ret_yumi_lo = l15_pce_ret_v_li & (l15_pce_ret_li.rtntype inside {e_st_ack, e_atomic_ret});
            cache_req_done = l15_pce_ret_yumi_lo;

            state_n = cache_req_done ? e_ready : state_r;
          end

        e_read_wait:
          begin
            // OP returns cacheable for lrsc for some reason
            if (l15_pce_ret_li.noncacheable)
              begin
                data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
                data_mem_pkt_cast_o.data = fill_data_packed;
                data_mem_pkt_v_o = is_ifill_ret_nc | is_load_ret_nc | is_amo_op_ret;

                l15_pce_ret_yumi_lo = data_mem_pkt_yumi_i;
              end
            else
              begin
                data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
                data_mem_pkt_cast_o.index = cache_req_lo.addr[block_offset_width_lp+:index_width_lp];
                data_mem_pkt_cast_o.way_id = cache_req_metadata_lo.hit_or_repl_way;
                data_mem_pkt_cast_o.fill_index = 1'b1;
                data_mem_pkt_cast_o.data = fill_data_packed;
                // Checking for return types here since we could also have
                // invalidations coming in at anytime
                data_mem_pkt_v_o = is_ifill_ret | is_load_ret | is_amo_lr_ret;

                tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
                tag_mem_pkt_cast_o.index = cache_req_lo.addr[block_offset_width_lp+:index_width_lp];
                tag_mem_pkt_cast_o.way_id = cache_req_metadata_lo.hit_or_repl_way;
                tag_mem_pkt_cast_o.tag = cache_req_lo.addr[block_offset_width_lp+index_width_lp+:ctag_width_p];
                tag_mem_pkt_cast_o.state = is_ifill_ret ? e_COH_S : e_COH_M;
                tag_mem_pkt_v_o = is_ifill_ret | is_load_ret | is_amo_lr_ret;

                l15_pce_ret_yumi_lo = data_mem_pkt_yumi_i & tag_mem_pkt_yumi_i;
              end

            cache_req_critical_o = data_mem_pkt_v_o;
            cache_req_done = l15_pce_ret_yumi_lo;

            state_n = cache_req_done ? e_ready : state_r;
          end
        default: state_n = e_reset;
      endcase

      // Need to support invalidations no matter what
      // Supporting inval all way and single way for both caches. OpenPiton
      // doesn't support inval all way for dcache and inval specific way for
      // icache
      if (inval_v_li | clear_v_li)
        begin
          tag_mem_pkt_cast_o.index = (pce_id_p == 1)
                                           ? {l15_pce_ret_li.inval_way[1], l15_pce_ret_li.inval_address_15_4[6:0]}
                                           : l15_pce_ret_li.inval_address_15_4[7:1];
          tag_mem_pkt_cast_o.opcode = clear_v_li ? e_cache_tag_mem_set_clear : e_cache_tag_mem_set_state;
          tag_mem_pkt_cast_o.way_id = (pce_id_p == 1)
                                            ? l15_pce_ret_li.inval_way[0]
                                            : l15_pce_ret_li.inval_way;
          tag_mem_pkt_cast_o.state  = e_COH_I;
          tag_mem_pkt_v_o = l15_pce_ret_v_li & ~cache_lock;

          l15_pce_ret_yumi_lo = tag_mem_pkt_yumi_i;
        end
    end

  always_ff @(negedge clk_i) begin
    //if (is_ifill_ret_nc | is_load_ret_nc | is_amo_op_ret)
    //  $display("[NC] TYPE: %s SIZE: %x ADDR: %x DATA: [%x][%x]", cache_req_lo.msg_type.name(), cache_req_lo.size, cache_req_lo.addr, l15_pce_ret_li.data_1, l15_pce_ret_li.data_0);

    if (is_amo_op_ret && cache_req_lo.subop == e_req_amosc)
      $display("[SC] TYPE: %s SIZE: %x ADDR: %x DATA: [%x][%x]", cache_req_lo.msg_type.name(), cache_req_lo.size, cache_req_lo.addr, l15_pce_ret_li.data_1, l15_pce_ret_li.data_0);

    if (is_amo_lr_ret && cache_req_lo.subop == e_req_amolr)
      $display("[LR] TYPE: %s SIZE: %x ADDR: %x DATA: [%x][%x]", cache_req_lo.msg_type.name(), cache_req_lo.size, cache_req_lo.addr, l15_pce_ret_li.data_1, l15_pce_ret_li.data_0);
  end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

endmodule

