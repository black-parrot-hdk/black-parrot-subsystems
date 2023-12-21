
`include "bsg_manycore_defines.svh"
`include "bsg_tag.svh"
`include "bp_common_defines.svh"

module bsg_hammerblade
 import bsg_noc_pkg::*;
 import bsg_manycore_pkg::*;
 import bsg_tag_pkg::*;
 import bp_common_pkg::*;
 import bsg_manycore_network_cfg_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_unicore_hammerblade_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(scratchpad_els_p)

   , parameter `BSG_INV_PARAM(num_tiles_x_p)
   , parameter `BSG_INV_PARAM(num_tiles_y_p)
   , parameter `BSG_INV_PARAM(pod_x_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_y_cord_width_p)
   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(ruche_factor_X_p)

   , parameter `BSG_INV_PARAM(num_subarray_x_p)
   , parameter `BSG_INV_PARAM(num_subarray_y_p)
   , localparam x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
   , localparam y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)

   , parameter `BSG_INV_PARAM(dmem_size_p)
   , parameter `BSG_INV_PARAM(icache_entries_p)
   , parameter `BSG_INV_PARAM(icache_tag_width_p)
   , parameter `BSG_INV_PARAM(icache_block_size_in_words_p)

   , parameter `BSG_INV_PARAM(vcache_addr_width_p)
   , parameter `BSG_INV_PARAM(vcache_data_width_p)
   , parameter `BSG_INV_PARAM(vcache_ways_p)
   , parameter `BSG_INV_PARAM(vcache_sets_p)
   , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(vcache_size_p)
   , parameter `BSG_INV_PARAM(vcache_dma_data_width_p)
   , parameter `BSG_INV_PARAM(vcache_word_tracking_p)
   , parameter `BSG_INV_PARAM(ipoly_hashing_p)

   , parameter `BSG_INV_PARAM(barrier_ruche_factor_X_p)

   , parameter `BSG_INV_PARAM(wh_ruche_factor_p)
   , parameter `BSG_INV_PARAM(wh_cid_width_p)
   , parameter `BSG_INV_PARAM(wh_flit_width_p)
   , parameter `BSG_INV_PARAM(wh_cord_width_p)
   , parameter `BSG_INV_PARAM(wh_len_width_p)

   , parameter `BSG_INV_PARAM(num_pods_y_p)
   , parameter `BSG_INV_PARAM(num_pods_x_p)

   , parameter `BSG_INV_PARAM(reset_depth_p)

   , parameter `BSG_INV_PARAM(rev_use_credits_p)
   , parameter `BSG_INV_PARAM(rev_fifo_els_p)

   , parameter `BSG_INV_PARAM(bsg_manycore_network_cfg_p)

   , localparam manycore_link_sif_width_lp =
       `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
   , localparam wh_link_sif_width_lp = `bsg_ready_and_link_sif_width(wh_flit_width_p)
   )
  (input                                                                                             clk_i
   , input                                                                                           reset_i
   , input                                                                                           rt_clk_i

   , input [manycore_link_sif_width_lp-1:0]                                                          io_link_sif_i
   , output logic [manycore_link_sif_width_lp-1:0]                                                   io_link_sif_o

   , input [S:N][E:W][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0]                               wh_link_sif_i
   , output logic [S:N][E:W][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0]                        wh_link_sif_o

   , input bsg_tag_s                                                                                 pod_tags_i
   );

  // instantiate manycore
  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] ver_link_sif_li, ver_link_sif_lo;
  bsg_manycore_link_sif_s [E:W][num_tiles_y_p-1:0] hor_link_sif_li, hor_link_sif_lo;
  bsg_manycore_ruche_x_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] ruche_link_li, ruche_link_lo;
  wh_link_sif_s [E:W][S:N][wh_ruche_factor_p-1:0] wh_link_sif_li, wh_link_sif_lo;

  if (bsg_manycore_network_cfg_p == e_network_half_ruche_x)
    begin : ruche
      bsg_manycore_pod_ruche_array
       #(.num_tiles_x_p(num_tiles_x_p)
         ,.num_tiles_y_p(num_tiles_y_p)
         ,.pod_x_cord_width_p(pod_x_cord_width_p)
         ,.pod_y_cord_width_p(pod_y_cord_width_p)
         ,.x_cord_width_p(x_cord_width_p)
         ,.y_cord_width_p(y_cord_width_p)
         ,.addr_width_p(addr_width_p)
         ,.data_width_p(data_width_p)
         ,.ruche_factor_X_p(ruche_factor_X_p)
         ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)
         ,.num_subarray_x_p(num_subarray_x_p)
         ,.num_subarray_y_p(num_subarray_y_p)

         ,.dmem_size_p(dmem_size_p)
         ,.icache_entries_p(icache_entries_p)
         ,.icache_tag_width_p(icache_tag_width_p)
         ,.icache_block_size_in_words_p(icache_block_size_in_words_p)

         ,.vcache_addr_width_p(vcache_addr_width_p)
         ,.vcache_data_width_p(vcache_data_width_p)
         ,.vcache_ways_p(vcache_ways_p)
         ,.vcache_sets_p(vcache_sets_p)
         ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
         ,.vcache_size_p(vcache_size_p)
         ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
         ,.vcache_word_tracking_p(vcache_word_tracking_p)

         ,.wh_ruche_factor_p(wh_ruche_factor_p)
         ,.wh_cid_width_p(wh_cid_width_p)
         ,.wh_flit_width_p(wh_flit_width_p)
         ,.wh_cord_width_p(wh_cord_width_p)
         ,.wh_len_width_p(wh_len_width_p)

         ,.num_pods_y_p(num_pods_y_p)
         ,.num_pods_x_p(num_pods_x_p)

         ,.reset_depth_p(reset_depth_p)
         )
       manycore
        (.clk_i(clk_i)

         ,.ver_link_sif_i(ver_link_sif_li)
         ,.ver_link_sif_o(ver_link_sif_lo)

         ,.wh_link_sif_i(wh_link_sif_li)
         ,.wh_link_sif_o(wh_link_sif_lo)

         ,.hor_link_sif_i(hor_link_sif_li)
         ,.hor_link_sif_o(hor_link_sif_lo)

         ,.ruche_link_i(ruche_link_li)
         ,.ruche_link_o(ruche_link_lo)

         ,.pod_tags_i(pod_tags_i)
         );
    end
  else
    begin : mesh
      bsg_manycore_pod_mesh_array
       #(.num_tiles_x_p(num_tiles_x_p)
         ,.num_tiles_y_p(num_tiles_y_p)
         ,.pod_x_cord_width_p(pod_x_cord_width_p)
         ,.pod_y_cord_width_p(pod_y_cord_width_p)
         ,.x_cord_width_p(x_cord_width_p)
         ,.y_cord_width_p(y_cord_width_p)
         ,.addr_width_p(addr_width_p)
         ,.data_width_p(data_width_p)
         ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)
         ,.num_subarray_x_p(num_subarray_x_p)
         ,.num_subarray_y_p(num_subarray_y_p)

         ,.dmem_size_p(dmem_size_p)
         ,.icache_entries_p(icache_entries_p)
         ,.icache_tag_width_p(icache_tag_width_p)
         ,.icache_block_size_in_words_p(icache_block_size_in_words_p)

         ,.vcache_addr_width_p(vcache_addr_width_p)
         ,.vcache_data_width_p(vcache_data_width_p)
         ,.vcache_ways_p(vcache_ways_p)
         ,.vcache_sets_p(vcache_sets_p)
         ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
         ,.vcache_size_p(vcache_size_p)
         ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
         ,.vcache_word_tracking_p(vcache_word_tracking_p)
         ,.ipoly_hashing_p(ipoly_hashing_p)

         ,.wh_ruche_factor_p(wh_ruche_factor_p)
         ,.wh_cid_width_p(wh_cid_width_p)
         ,.wh_flit_width_p(wh_flit_width_p)
         ,.wh_cord_width_p(wh_cord_width_p)
         ,.wh_len_width_p(wh_len_width_p)

         ,.num_pods_y_p(num_pods_y_p)
         ,.num_pods_x_p(num_pods_x_p)

         ,.reset_depth_p(reset_depth_p)
         )
       manycore
        (.clk_i(clk_i)

         ,.ver_link_sif_i(ver_link_sif_li)
         ,.ver_link_sif_o(ver_link_sif_lo)

         ,.wh_link_sif_i(wh_link_sif_li)
         ,.wh_link_sif_o(wh_link_sif_lo)

         ,.hor_link_sif_i(hor_link_sif_li)
         ,.hor_link_sif_o(hor_link_sif_lo)

         ,.pod_tags_i(pod_tags_i)
         );
    end

  // IO ROUTER
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0][S:P] io_link_sif_li;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0][S:P] io_link_sif_lo;

  for (genvar x = 0; x < num_tiles_x_p; x++)
    begin : io_rtr_x
      bsg_manycore_mesh_node
       #(.x_cord_width_p(x_cord_width_p)
         ,.y_cord_width_p(y_cord_width_p)
         ,.addr_width_p(addr_width_p)
         ,.data_width_p(data_width_p)
         ,.stub_p(4'b0100) // stub north
         ,.rev_use_credits_p(rev_use_credits_p)
         ,.rev_fifo_els_p(rev_fifo_els_p)
         )
       io_rtr
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
 
         ,.links_sif_i(io_link_sif_li[x][S:W])
         ,.links_sif_o(io_link_sif_lo[x][S:W])
 
         ,.proc_link_sif_i(io_link_sif_li[x][P])
         ,.proc_link_sif_o(io_link_sif_lo[x][P])
 
         ,.global_x_i(x_cord_width_p'(num_tiles_x_p+x))
         ,.global_y_i(y_cord_width_p'(0))
         );

      // connect to pod array
      assign ver_link_sif_li[N][x] = io_link_sif_lo[x][S];
      assign io_link_sif_li[x][S] = ver_link_sif_lo[N][x];

      // connect between io rtr
      if (x < num_tiles_x_p-1)
        begin
          assign io_link_sif_li[x][E] = io_link_sif_lo[x+1][W];
          assign io_link_sif_li[x+1][W] = io_link_sif_lo[x][E];
        end
  end

  // IO P tie off all but first (host)
  for (genvar i = 1; i < num_tiles_x_p; i++)
    begin : io_p_tieoff
      bsg_manycore_link_sif_tieoff
       #(.addr_width_p(addr_width_p)
         ,.data_width_p(data_width_p)
         ,.x_cord_width_p(x_cord_width_p)
         ,.y_cord_width_p(y_cord_width_p)
         )
       rtr
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.link_sif_i(io_link_sif_lo[i][P])
         ,.link_sif_o(io_link_sif_li[i][P])
         );
    end

  // IO west end tieoff
  bsg_manycore_link_sif_tieoff
   #(.addr_width_p(addr_width_p)
     ,.data_width_p(data_width_p)
     ,.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     )
   io_w_tieoff
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.link_sif_i(io_link_sif_lo[0][W])
     ,.link_sif_o(io_link_sif_li[0][W])
     );

  // IO east end tieoff
  bsg_manycore_link_sif_tieoff
   #(.addr_width_p(addr_width_p)
     ,.data_width_p(data_width_p)
     ,.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     )
   io_e_tieoff
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.link_sif_i(io_link_sif_lo[num_tiles_x_p-1][E])
     ,.link_sif_o(io_link_sif_li[num_tiles_x_p-1][E])
     );

  // IO N tie off
  for (genvar i = 0; i < num_tiles_x_p; i++)
    begin : io_n_tieoff
      bsg_manycore_link_sif_tieoff
       #(.addr_width_p(addr_width_p)
         ,.data_width_p(data_width_p)
         ,.x_cord_width_p(x_cord_width_p)
         ,.y_cord_width_p(y_cord_width_p)
         )
       tieoff
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.link_sif_i(io_link_sif_lo[i][N])
         ,.link_sif_o(io_link_sif_li[i][N])
         );
    end

  // HOR TIEOFF (local link)
  for (genvar i = W; i <= E; i++)
    begin : mc_e_w
      for (genvar k = 0; k < num_tiles_y_p; k++)
        begin : col
          bsg_manycore_link_sif_tieoff
           #(.addr_width_p(addr_width_p)
             ,.data_width_p(data_width_p)
             ,.x_cord_width_p(x_cord_width_p)
             ,.y_cord_width_p(y_cord_width_p)
             )
           tieoff
            (.clk_i(clk_i)
             ,.reset_i(reset_i)
             ,.link_sif_i(hor_link_sif_lo[i][k])
             ,.link_sif_o(hor_link_sif_li[i][k])
             );
        end
    end


  // RUCHE LINK TIEOFF (west)
  for (genvar j = 0; j < num_pods_y_p; j++) begin
    for (genvar k = 0; k < num_tiles_y_p; k++) begin
      // if ruche factor is even, tieoff with '1
      // if ruche factor is odd,  tieoff with '0
      assign ruche_link_li[W][j][k] = (ruche_factor_X_p % 2 == 0) ? '1 : '0;
    end
  end

  // RUCHE LINK TIEOFF (east)
  for (genvar j = 0; j < num_pods_y_p; j++) begin
    for (genvar k = 0; k < num_tiles_y_p; k++) begin
      // always tieoff with '0;
      assign ruche_link_li[E][j][k] = '0;
    end
  end

  logic [3:0][x_cord_width_p-1:0] bp_global_x_li;
  logic [0:0][y_cord_width_p-1:0] bp_global_y_li;
  bsg_manycore_link_sif_s [S:N][3:0] bp_ver_link_sif_li;
  bsg_manycore_link_sif_s [S:N][3:0] bp_ver_link_sif_lo;
  bsg_manycore_link_sif_s [E:W][0:0] bp_hor_link_sif_li;
  bsg_manycore_link_sif_s [E:W][0:0] bp_hor_link_sif_lo;
  bsg_manycore_tile_blackparrot_mesh
   #(.bp_params_p(bp_params_p)
     ,.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.pod_x_cord_width_p(pod_x_cord_width_p)
     ,.pod_y_cord_width_p(pod_y_cord_width_p)
     ,.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
     ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
     ,.vcache_size_p(vcache_size_p)
     ,.vcache_sets_p(vcache_sets_p)
     ,.num_tiles_x_p(num_tiles_x_p)
     ,.num_tiles_y_p(num_tiles_y_p)
     ,.ipoly_hashing_p(ipoly_hashing_p)
     ,.scratchpad_els_p(scratchpad_els_p)
     ,.rev_use_credits_p(rev_use_credits_p)
     ,.rev_fifo_els_p(rev_fifo_els_p)
     )
   blackparrot_mesh
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)

     ,.global_x_i(bp_global_x_li)
     ,.global_y_i(bp_global_y_li)

     ,.hor_link_sif_i(bp_hor_link_sif_li)
     ,.hor_link_sif_o(bp_hor_link_sif_lo)

     ,.ver_link_sif_i(bp_ver_link_sif_li)
     ,.ver_link_sif_o(bp_ver_link_sif_lo)
     );

  if (num_tiles_x_p > 2)
    begin : no_stub
      assign bp_ver_link_sif_li[N][0+:4] = ver_link_sif_lo[S][0+:4];
      assign ver_link_sif_li[S][0+:4] = bp_ver_link_sif_lo[N][0+:4];

      assign bp_ver_link_sif_li[S] = '0;
      assign bp_hor_link_sif_li = '0;

      assign bp_global_x_li[0] = (1 << x_subcord_width_lp) | (0);
      assign bp_global_x_li[1] = (1 << x_subcord_width_lp) | (1);
      assign bp_global_x_li[2] = (1 << x_subcord_width_lp) | (2);
      assign bp_global_x_li[3] = (1 << x_subcord_width_lp) | (3);

      assign bp_global_y_li[0] = (3 << y_subcord_width_lp) | (0);
    end
  else
    begin : stub
      assign bp_ver_link_sif_li[N][0+:2] = ver_link_sif_lo[S][0+:2];
      assign bp_ver_link_sif_li[N][2+:2] = '0;
      assign ver_link_sif_li[S][0+:2] = bp_ver_link_sif_lo[N][0+:2];

      assign bp_ver_link_sif_li[S] = '0;
      assign bp_hor_link_sif_li = '0;

      assign bp_global_x_li[0] = (1 << x_subcord_width_lp) | (0);
      assign bp_global_x_li[1] = (1 << x_subcord_width_lp) | (1);
      assign bp_global_x_li[2] = (2 << x_subcord_width_lp) | (0);
      assign bp_global_x_li[3] = (2 << x_subcord_width_lp) | (1);

      assign bp_global_y_li[0] = (3 << y_subcord_width_lp) | (0);
    end

  assign io_link_sif_o = io_link_sif_lo[0][P];
  assign io_link_sif_li[0][P] = io_link_sif_i;
  assign wh_link_sif_o = wh_link_sif_lo;
  assign wh_link_sif_li = wh_link_sif_i;


endmodule

`BSG_ABSTRACT_MODULE(bsg_hammerblade)

