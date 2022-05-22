
module interrupt_control_unit (

    input  logic    clk_i
  , input  logic    reset_i
  , input  logic    packet_avail_i
  , input  logic    packet_req_i

  , input  logic    tx_interrupt_clear_i

  , input  logic    rx_interrupt_enable_i
  , input  logic    rx_interrupt_enable_v_i
  , input  logic    tx_interrupt_enable_i
  , input  logic    tx_interrupt_enable_v_i

    // High: interrupt pending
  , output logic    rx_interrupt_pending_o
  , output logic    tx_interrupt_pending_o
);

  logic tx_ready_prev_r;
  logic rx_interrupt_enable_r;
  logic tx_interrupt_enable_r;

  bsg_dff_reset_en #(.width_p(1))
    rx_interrupt_enable_reg (
        .clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(rx_interrupt_enable_v_i)
       ,.data_i(rx_interrupt_enable_i)
       ,.data_o(rx_interrupt_enable_r)
    );

  bsg_dff_reset_en #(.width_p(1))
    tx_interrupt_enable_reg (
        .clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(tx_interrupt_enable_v_i)
       ,.data_i(tx_interrupt_enable_i)
       ,.data_o(tx_interrupt_enable_r)
    );



  // reset value is 1 because the init value of packet_req_i is 1
  // and we use 0 -> 1 transition of tx_ready_prev_r
  // as the interrupt setting event
  bsg_dff_reset #(.width_p(1), .reset_val_p(1))
    tx_ready_prev_reg (
        .clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.data_i(packet_req_i)
       ,.data_o(tx_ready_prev_r)
    );

  // set tx interupt when packet_req_i goes from 0 -> 1
  wire tx_interrupt_set_li = (tx_ready_prev_r == 0) & packet_req_i;

  logic tx_interrupt_pending_r_lo;

  bsg_dff_reset_set_clear #(.width_p(1))
    tx_interrupt_pending_reg (
        .clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.set_i(tx_interrupt_set_li)
       ,.clear_i(tx_interrupt_clear_i)
       ,.data_o(tx_interrupt_pending_r_lo)
    );

  // We don't really have an RX interrupt pending reg. The clear pending op
  // will just go directly to the receive side of the Ethernet module and
  // remove one received packet in the RX buffer. If after that the buffer happens
  // to become empty, the RX pending bit will goes to 0, otherwise it keeps being
  // 1.
  assign rx_interrupt_pending_o = packet_avail_i & rx_interrupt_enable_r;
  assign tx_interrupt_pending_o = tx_interrupt_pending_r_lo & tx_interrupt_enable_r;

endmodule
