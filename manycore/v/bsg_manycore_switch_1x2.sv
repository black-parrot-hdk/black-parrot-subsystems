
`include "bsg_manycore_defines.vh"

module bsg_manycore_switch_1x2
 import bsg_manycore_pkg::*;
 #(parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(split_addr_p)

   , localparam fwd_link_sif_width_lp =
       `bsg_ready_and_link_sif_width(`bsg_manycore_packet_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p))
   , localparam rev_link_sif_width_lp =
       `bsg_ready_and_link_sif_width(`bsg_manycore_return_packet_width(x_cord_width_p, y_cord_width_p, data_width_p))
   )
  (input                                           clk_i
   , input                                         reset_i

   , input [1:0][fwd_link_sif_width_lp-1:0]        fwd_link_sif_i
   , output logic [1:0][rev_link_sif_width_lp-1:0] rev_link_sif_o
   , output logic [1:0][fwd_link_sif_width_lp-1:0] fwd_link_sif_o
   , input [1:0][rev_link_sif_width_lp-1:0]        rev_link_sif_i

   , output logic [fwd_link_sif_width_lp-1:0]      multi_fwd_link_sif_o
   , input [fwd_link_sif_width_lp-1:0]             multi_fwd_link_sif_i
   , output logic [rev_link_sif_width_lp-1:0]      multi_rev_link_sif_o
   , input [rev_link_sif_width_lp-1:0]             multi_rev_link_sif_i
   );

  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  bsg_manycore_fwd_link_sif_s [1:0] fwd_link_sif_cast_i, fwd_link_sif_cast_o;
  bsg_manycore_rev_link_sif_s [1:0] rev_link_sif_cast_i, rev_link_sif_cast_o;
  bsg_manycore_fwd_link_sif_s multi_fwd_link_sif_cast_i, multi_fwd_link_sif_cast_o;
  bsg_manycore_rev_link_sif_s multi_rev_link_sif_cast_i, multi_rev_link_sif_cast_o;

  assign fwd_link_sif_cast_i = fwd_link_sif_i;
  assign multi_rev_link_sif_cast_i = multi_rev_link_sif_i;
  assign rev_link_sif_o = rev_link_sif_cast_o;
  assign multi_fwd_link_sif_o = multi_fwd_link_sif_cast_o;
  assign multi_fwd_link_sif_cast_i = multi_fwd_link_sif_i;
  assign rev_link_sif_cast_i = rev_link_sif_i;
  assign multi_rev_link_sif_o = multi_rev_link_sif_cast_o;
  assign fwd_link_sif_o = fwd_link_sif_cast_o;

  //////////////////////////////////////////////////
  //  TX
  //////////////////////////////////////////////////
  enum logic [1:0] {e_sready, e_send0, e_send1} send_state_n, send_state_r;
  wire is_sready = (send_state_r == e_sready);
  wire is_send0  = (send_state_r == e_send0);
  wire is_send1  = (send_state_r == e_send1);

  assign fwd_link_sif_cast_o[0].data             = multi_fwd_link_sif_cast_i.data;
  assign fwd_link_sif_cast_o[0].v                = multi_fwd_link_sif_cast_i.v & is_send0;
  assign fwd_link_sif_cast_o[1].data             = multi_fwd_link_sif_cast_i.data;
  assign fwd_link_sif_cast_o[1].v                = multi_fwd_link_sif_cast_i.v & is_send1;
  assign multi_fwd_link_sif_cast_o.ready_and_rev =
    (is_send0 & fwd_link_sif_cast_i[0].ready_and_rev)
    | (is_send1 & fwd_link_sif_cast_i[1].ready_and_rev);

  bsg_manycore_return_packet_s multi_rev_data_lo;
  logic multi_rev_tag_lo, multi_rev_v_lo, multi_rev_yumi_li;
  bsg_round_robin_n_to_1
   #(.width_p($bits(bsg_manycore_return_packet_s))
     ,.num_in_p(2)
     ,.strict_p(0)
     )
   rev_rr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({rev_link_sif_cast_i[1].data, rev_link_sif_cast_i[0].data})
     ,.v_i({rev_link_sif_cast_i[1].v, rev_link_sif_cast_i[0].v})
     ,.yumi_o()

     ,.data_o(multi_rev_data_lo)
     ,.tag_o(multi_rev_tag_lo)
     ,.v_o(multi_rev_v_lo)
     ,.yumi_i(multi_rev_yumi_li)
     );

  assign multi_rev_link_sif_cast_o.data = multi_rev_data_lo;
  assign multi_rev_link_sif_cast_o.v = multi_rev_v_lo;
  assign multi_rev_yumi_li = multi_rev_v_lo;

  assign rev_link_sif_cast_o[0].ready_and_rev = multi_rev_link_sif_cast_i.ready_and_rev & is_send0;
  assign rev_link_sif_cast_o[1].ready_and_rev = multi_rev_link_sif_cast_i.ready_and_rev & is_send1;

  // Arbitrary for now
  localparam outstanding_sends_lp = 127;
  logic [`BSG_WIDTH(outstanding_sends_lp)-1:0] send_cnt_lo;
  bsg_counter_up_down
   #(.max_val_p(outstanding_sends_lp), .init_val_p(0), .max_step_p(1))
   sfc
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.up_i(multi_fwd_link_sif_cast_o.ready_and_rev & multi_fwd_link_sif_cast_i.v)
     // Credit-based
     ,.down_i(multi_rev_link_sif_cast_i.ready_and_rev)

     ,.count_o(send_cnt_lo)
     );

  bsg_manycore_packet_s fwd_packet;
  assign fwd_packet = multi_fwd_link_sif_cast_i.data;
  wire [1:0] fwd_part_sel = fwd_packet.payload.load_info_s.load_info.part_sel;
  wire [addr_width_p-1:0] fwd_epa = (fwd_packet.addr << 2) | fwd_part_sel;
  wire fwd_select = (fwd_epa >= split_addr_p);
  wire send0 = multi_fwd_link_sif_cast_i.v & !fwd_select;
  wire send1 = multi_fwd_link_sif_cast_i.v &  fwd_select;
  wire send_drained = (send_cnt_lo == '0) & ~send0 & ~send1;
  always_comb
    unique casez (send_state_r)
      e_sready : send_state_n = send0   ? e_send0 : send1 ? e_send1 : e_sready;
      e_send0  : send_state_n = send_drained ? e_sready : e_send0;
      e_send1  : send_state_n = send_drained ? e_sready : e_send1;
      default  : send_state_n = e_sready;
    endcase

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      send_state_r <= e_sready;
    else
      send_state_r <= send_state_n;

  //////////////////////////////////////////////////
  //  RX
  //////////////////////////////////////////////////
  enum logic [1:0] {e_rready, e_recv0, e_recv1} recv_state_n, recv_state_r;
  wire is_rready = (recv_state_r == e_rready);
  wire is_recv0  = (recv_state_r == e_recv0);
  wire is_recv1  = (recv_state_r == e_recv1);

  bsg_manycore_packet_s multi_fwd_data_lo;
  logic multi_fwd_tag_lo, multi_fwd_v_lo, multi_fwd_yumi_li;
  bsg_round_robin_n_to_1
   #(.width_p($bits(bsg_manycore_packet_s))
     ,.num_in_p(2)
     ,.strict_p(0)
     )
   fwd_rr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({fwd_link_sif_cast_i[1].data, fwd_link_sif_cast_i[0].data})
     ,.v_i({fwd_link_sif_cast_i[1].v, fwd_link_sif_cast_i[0].v})
     ,.yumi_o({fwd_link_sif_cast_o[1].ready_and_rev, fwd_link_sif_cast_o[0].ready_and_rev})

     ,.data_o(multi_fwd_data_lo)
     ,.tag_o(multi_fwd_tag_lo)
     ,.v_o(multi_fwd_v_lo)
     ,.yumi_i(multi_fwd_yumi_li)
     );

  assign multi_fwd_link_sif_cast_o.data = multi_fwd_data_lo;
  assign multi_fwd_link_sif_cast_o.v = multi_fwd_v_lo & (is_rready | (is_recv0 & !multi_fwd_tag_lo) | (is_recv1 & multi_fwd_tag_lo));
  assign multi_fwd_yumi_li = multi_fwd_link_sif_cast_i.ready_and_rev & multi_fwd_link_sif_cast_o.v;

  assign rev_link_sif_cast_o[0].data = multi_rev_link_sif_cast_i.data;
  assign rev_link_sif_cast_o[0].v    = multi_rev_link_sif_cast_i.v & is_recv0;
  assign rev_link_sif_cast_o[1].data = multi_rev_link_sif_cast_i.data;
  assign rev_link_sif_cast_o[1].v    = multi_rev_link_sif_cast_i.v & is_recv1;
  assign multi_rev_link_sif_cast_o.ready_and_rev =
    (is_recv0 & rev_link_sif_cast_i[0].ready_and_rev)
    | (is_recv1 & rev_link_sif_cast_i[1].ready_and_rev);

  // Arbitrary for now
  localparam outstanding_recvs_lp = 127;
  logic [`BSG_WIDTH(outstanding_recvs_lp)-1:0] recv_cnt_lo;
  bsg_counter_up_down
   #(.max_val_p(outstanding_recvs_lp), .init_val_p(0), .max_step_p(1))
   rfc
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.up_i(multi_fwd_link_sif_cast_o.v)
     ,.down_i(multi_rev_link_sif_cast_o.ready_and_rev & multi_rev_link_sif_cast_i.v)

     ,.count_o(recv_cnt_lo)
     );

  wire accept0 = multi_fwd_yumi_li & ~multi_fwd_tag_lo;
  wire accept1 = multi_fwd_yumi_li &  multi_fwd_tag_lo;
  wire recv_drained = (recv_cnt_lo == '0) & ~accept0 & ~accept1;
  always_comb
    unique casez (recv_state_r)
      e_rready : recv_state_n = accept0 ? e_recv0 : accept1 ? e_recv1 : e_rready;
      e_recv0  : recv_state_n = recv_drained ? e_rready : e_recv0;
      e_recv1  : recv_state_n = recv_drained ? e_rready : e_recv1;
      default  : recv_state_n = e_rready;
    endcase

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      recv_state_r <= e_rready;
    else
      recv_state_r <= recv_state_n;

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_switch_1x2)

