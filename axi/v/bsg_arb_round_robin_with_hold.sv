`include "bsg_defines.v"

module bsg_arb_round_robin_with_hold #(`BSG_INV_PARAM(width_p))
(
    input clk_i
  , input reset_i
  , input [1:0] reqs_i
  , output [1:0] grants_o
  , input complete_i
);

  wire valid = |reqs_i;
  logic select_lo;
  logic [1:0] reqs_r;
  logic [1:0] reqs_li;
  logic en_li;


  bsg_dff_reset_set_clear
   #(.width_p(1), .clear_over_set_p(1))
   select_dff
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(valid)
    ,.clear_i(complete_i)
    ,.data_o(select_lo)
    );

  bsg_dff_reset_en
   #(.width_p(2))
   prev_dff
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(en_li)
     ,.data_i(reqs_i)
     ,.data_o(reqs_r)
     );

  bsg_arb_round_robin
   #(.width_p(2))
   rr
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.reqs_i(reqs_li)
    ,.grants_o(grants_o)
    ,.yumi_i(complete_i)
    );

  assign en_li = ~complete_i & ~select_lo & valid;
  assign reqs_li = select_lo ? reqs_r : reqs_i;

endmodule
`BSG_ABSTRACT_MODULE(bsg_arb_round_robin_with_hold)
