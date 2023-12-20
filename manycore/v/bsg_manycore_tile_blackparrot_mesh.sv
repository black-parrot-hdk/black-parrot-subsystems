
`include "bp_common_defines.svh"
`include "bsg_manycore_defines.svh"

module bsg_manycore_tile_blackparrot_mesh
 import bsg_manycore_pkg::*;
 import bp_common_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_x_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_y_cord_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(icache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(num_vcache_rows_p)
   , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(vcache_size_p)
   , parameter `BSG_INV_PARAM(vcache_sets_p)
   , parameter `BSG_INV_PARAM(num_tiles_x_p)
   , parameter `BSG_INV_PARAM(num_tiles_y_p)
   , parameter `BSG_INV_PARAM(scratchpad_els_p)
   , parameter `BSG_INV_PARAM(rev_use_credits_p)
   , parameter `BSG_INV_PARAM(int rev_fifo_els_p[4:0])

   , localparam num_blackparrot_p = 1 // Only 1 supported
   , localparam veritical_not_horizontal_p = 0 // In a horizontal now
   , localparam num_x_links_lp = 4 * num_blackparrot_p
   , localparam num_y_links_lp = num_blackparrot_p
   , localparam link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
   )
  (input                                                     clk_i
   , input                                                   rt_clk_i
   , input                                                   reset_i

   , input [num_x_links_lp-1:0][x_cord_width_p-1:0]          global_x_i
   , input [num_y_links_lp-1:0][y_cord_width_p-1:0]          global_y_i

   , input  [E:W][num_y_links_lp-1:0][link_sif_width_lp-1:0] hor_link_sif_i
   , output [E:W][num_y_links_lp-1:0][link_sif_width_lp-1:0] hor_link_sif_o

   , input  [S:N][num_x_links_lp-1:0][link_sif_width_lp-1:0] ver_link_sif_i
   , output [S:N][num_x_links_lp-1:0][link_sif_width_lp-1:0] ver_link_sif_o
   );

   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_link_sif_s [3:0][S:W] rtr_link_sif_li, rtr_link_sif_lo;
  bsg_manycore_link_sif_s [3:0] bp_link_sif_li, bp_link_sif_lo;
  bsg_manycore_tile_blackparrot
   #(.bp_params_p(bp_params_p)
     ,.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.pod_x_cord_width_p(pod_x_cord_width_p)
     ,.pod_y_cord_width_p(pod_y_cord_width_p)
     ,.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
     ,.num_vcache_rows_p(num_vcache_rows_p)
     ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
     ,.vcache_size_p(vcache_size_p)
     ,.vcache_sets_p(vcache_sets_p)
     ,.num_tiles_x_p(num_tiles_x_p)
     ,.num_tiles_y_p(num_tiles_y_p)
     ,.scratchpad_els_p(scratchpad_els_p)
     )
   blackparrot
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)

     ,.global_x_i(global_x_i)
     ,.global_y_i({4{global_y_i}})

     ,.link_sif_i(bp_link_sif_li)
     ,.link_sif_o(bp_link_sif_lo)
     );

  for (genvar x = 0; x < num_x_links_lp; x++)
    begin : rtr
      bsg_manycore_mesh_node
       #(.x_cord_width_p(x_cord_width_p)
         ,.y_cord_width_p(y_cord_width_p)
         ,.addr_width_p(addr_width_p)
         ,.data_width_p(data_width_p)
         ,.stub_p(4'b0000)
         ,.rev_use_credits_p(rev_use_credits_p)
         ,.rev_fifo_els_p(rev_fifo_els_p)
         )
       bp_rtr
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.links_sif_i(rtr_link_sif_li[x][S:W])
         ,.links_sif_o(rtr_link_sif_lo[x][S:W])

         ,.proc_link_sif_i(bp_link_sif_lo[x])
         ,.proc_link_sif_o(bp_link_sif_li[x])

         ,.global_x_i(global_x_i[x])
         ,.global_y_i(global_y_i[0])
         );

      // connect to pod array
      assign ver_link_sif_o[N][x] = rtr_link_sif_lo[x][N];
      assign rtr_link_sif_li[x][N] = ver_link_sif_i[N][x];

      assign ver_link_sif_o[S][x] = rtr_link_sif_lo[x][S];
      assign rtr_link_sif_li[x][S] = ver_link_sif_i[S][x];

      // connect between io rtr
      if (x < num_x_links_lp-1)
        begin
          assign rtr_link_sif_li[x][E] = rtr_link_sif_lo[x+1][W];
          assign rtr_link_sif_li[x+1][W] = rtr_link_sif_lo[x][E];
        end
    end

  assign hor_link_sif_o[E] = rtr_link_sif_lo[num_x_links_lp-1][E];
  assign rtr_link_sif_li[num_x_links_lp-1][E] = hor_link_sif_i[E];

  assign hor_link_sif_o[W] = rtr_link_sif_lo[0][W];
  assign rtr_link_sif_li[0][W] = hor_link_sif_i[W];

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_tile_blackparrot_mesh)

