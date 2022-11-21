
`include "bsg_defines.v"

module bsg_mem_1r1w_sync_wrapper #(parameter `BSG_INV_PARAM(width_p)
                           , parameter `BSG_INV_PARAM(els_p)
                           , parameter read_write_same_addr_p=0 // specifically write_then_read_p
                           , parameter latch_last_read_p=0
                           , parameter addr_width_lp=`BSG_SAFE_CLOG2(els_p)
                           , parameter harden_p=0
                           , parameter disable_collision_warning_p=0
                           , parameter enable_clock_gating_p=0
                           , parameter verbose_if_synth_p=1
                           )
   (input   clk_i
    , input reset_i

    , input                     w_v_i
    , input [addr_width_lp-1:0] w_addr_i
    , input [`BSG_SAFE_MINUS(width_p, 1):0]       w_data_i

    // currently unused
    , input                      r_v_i
    , input [addr_width_lp-1:0]  r_addr_i

    , output logic [`BSG_SAFE_MINUS(width_p, 1):0] r_data_o
    );

    // Without this, sometimes vivado will fail to infer BRAM for us
    (* KEEP_HIERARCHY = "TRUE" *)
    bsg_mem_1r1w_sync #(
       .width_p(width_p)
      ,.els_p(els_p)
      ,.read_write_same_addr_p(read_write_same_addr_p)
      ,.latch_last_read_p(latch_last_read_p)
      ,.harden_p(harden_p)
      ,.disable_collision_warning_p(disable_collision_warning_p)
      ,.enable_clock_gating_p(enable_clock_gating_p)
      ,.verbose_if_synth_p(verbose_if_synth_p)
    ) mem (.*);

endmodule

`BSG_ABSTRACT_MODULE(bsg_mem_1r1w_sync_wrapper)
