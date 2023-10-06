
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_manycore_bridge
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_x_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_y_cord_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(scratchpad_els_p)

   , localparam pod_cord_width_lp = pod_x_cord_width_p + pod_y_cord_width_p
   , localparam cord_width_lp = x_cord_width_p + y_cord_width_p
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [mem_fwd_header_width_lp-1:0]            mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]               mem_fwd_data_i
   , input                                          mem_fwd_v_i
   , output logic                                   mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]     mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_rev_data_o
   , output logic                                   mem_rev_v_o
   , input                                          mem_rev_ready_and_i

   , output logic [pod_cord_width_lp-1:0]           dram_pod_o
   , output logic [addr_width_p-1:0]                dram_offset_o
   , output logic [cord_width_lp-1:0]               my_cord_o
   , output logic [cord_width_lp-1:0]               host_cord_o
   );

  localparam mc_bridge_reg_dram_offset_gp = (dev_addr_width_gp)'('h0_0000);
  localparam mc_bridge_reg_dram_pod_gp    = (dev_addr_width_gp)'('h0_0008);
  localparam mc_bridge_reg_my_cord_gp     = (dev_addr_width_gp)'('h0_0010);
  localparam mc_bridge_reg_host_cord_gp   = (dev_addr_width_gp)'('h0_0018);
  localparam mc_bridge_scratchpad_gp      = (dev_addr_width_gp)'('h0_1000);

  logic scratchpad_r_v_li, scratchpad_w_v_li;
  logic host_cord_r_v_li, host_cord_w_v_li;
  logic my_cord_r_v_li, my_cord_w_v_li;
  logic dram_pod_r_v_li, dram_pod_w_v_li;
  logic dram_offset_r_v_li, dram_offset_w_v_li;
  logic [dev_addr_width_gp-1:0] addr_lo;
  logic [dword_width_gp-1:0] data_lo;
  logic [4:0][dword_width_gp-1:0] data_li;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.els_p(5)
     ,.reg_data_width_p(dword_width_gp)
     ,.reg_addr_width_p(dev_addr_width_gp)
     ,.base_addr_p({mc_bridge_scratchpad_gp, mc_bridge_reg_host_cord_gp, mc_bridge_reg_my_cord_gp, mc_bridge_reg_dram_pod_gp, mc_bridge_reg_dram_offset_gp})
     )
   register
    (.*
     ,.r_v_o({scratchpad_r_v_li, host_cord_r_v_li, my_cord_r_v_li, dram_pod_r_v_li, dram_offset_r_v_li})
     ,.w_v_o({scratchpad_w_v_li, host_cord_w_v_li, my_cord_w_v_li, dram_pod_w_v_li, dram_offset_w_v_li})
     ,.addr_o(addr_lo)
     ,.size_o()
     ,.data_o(data_lo)
     ,.data_i(data_li)
     );

  logic [data_width_p-1:0] dram_offset_r;
  logic [pod_cord_width_lp-1:0] dram_pod_r;
  logic [cord_width_lp-1:0] my_cord_r;
  logic [cord_width_lp-1:0] host_cord_r;
  always_ff @(posedge clk_i)
    if (reset_i)
      begin
        dram_offset_r <= '0;
        dram_pod_r <= '0;
        my_cord_r <= '0;
        host_cord_r <= '0;
      end
    else
      begin
        dram_offset_r <= dram_offset_w_v_li ? data_lo : dram_offset_r;
        dram_pod_r <= dram_pod_w_v_li ? data_lo : dram_pod_r;
        my_cord_r <= my_cord_w_v_li ? data_lo : my_cord_r;
        host_cord_r <= host_cord_w_v_li ? data_lo : host_cord_r;
      end

  // We only support 32b loads/stores currently
  logic [data_width_p-1:0] scratchpad_data_lo;
  wire [data_width_p-1:0] scratchpad_data_li = data_lo;
  wire [`BSG_SAFE_CLOG2(scratchpad_els_p)-1:0] scratchpad_addr_li = (addr_lo >> `BSG_SAFE_CLOG2(data_width_p>>3));
  bsg_mem_1rw_sync
   #(.width_p(data_width_p), .els_p(scratchpad_els_p))
   scratchpad
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(scratchpad_r_v_li | scratchpad_w_v_li)
     ,.w_i(scratchpad_w_v_li)
     ,.data_i(scratchpad_data_li)
     ,.addr_i(scratchpad_addr_li)

     ,.data_o(scratchpad_data_lo)
     );

  assign data_li[0] = dram_offset_r;
  assign data_li[1] = dram_pod_r;
  assign data_li[2] = my_cord_r;
  assign data_li[3] = host_cord_r;
  assign data_li[4] = scratchpad_data_lo;

  assign dram_offset_o = dram_offset_r;
  assign dram_pod_o = dram_pod_r;
  assign host_cord_o = host_cord_r;
  assign my_cord_o = my_cord_r;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_manycore_bridge)

