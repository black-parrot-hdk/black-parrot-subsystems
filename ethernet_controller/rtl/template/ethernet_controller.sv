
`include "bsg_defines.v"

module ethernet_controller #
(
      parameter  data_width_p  = 32
    , localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p/8))
    , localparam addr_width_lp = 14
)
(
      input  logic                              clk_i
    , input  logic                              reset_i
    , input  logic                              clk250_i
    , input  logic                              reset_clk250_i
    , output logic                              reset_clk125_o

    , input  logic [addr_width_lp-1:0]          addr_i
    , input  logic                              write_en_i
    , input  logic                              read_en_i
    , input  logic [size_width_lp-1:0]          op_size_i
    , input  logic [data_width_p-1:0]           write_data_i
    , output logic [data_width_p-1:0]           read_data_o // sync read

    , output logic                              rx_interrupt_pending_o
    , output logic                              tx_interrupt_pending_o

    , input  logic                              rgmii_rx_clk_i
    , input  logic [3:0]                        rgmii_rxd_i
    , input  logic                              rgmii_rx_ctl_i
    , output logic                              rgmii_tx_clk_o
    , output logic [3:0]                        rgmii_txd_o
    , output logic                              rgmii_tx_ctl_o
);

  localparam eth_mtu_lp = 2048; // byte
  localparam packet_size_width_lp = $clog2(eth_mtu_lp+1);
  localparam packet_addr_width_lp = $clog2(eth_mtu_lp);

  logic packet_send_lo;
  logic packet_avail_lo;
  logic packet_ack_lo;
  logic packet_req_lo;

  logic                             packet_wsize_valid_lo;
  logic [packet_size_width_lp-1:0]  packet_wsize_lo;

  logic [packet_addr_width_lp-1:0]  packet_waddr_lo;
  logic [size_width_lp-1:0]         packet_wdata_size_lo;
  logic [data_width_p-1:0]          packet_wdata_lo;
  logic                             packet_wvalid_lo;

  logic [packet_addr_width_lp-1:0]  packet_raddr_lo;
  logic [size_width_lp-1:0]         packet_rdata_size_lo;
  logic [data_width_p-1:0]          packet_rdata_lo;
  logic                             packet_rvalid_lo;

  logic [packet_size_width_lp-1:0]  packet_rsize_lo;

  logic       tx_error_underflow_lo;
  logic       tx_fifo_overflow_lo;
  logic       tx_fifo_bad_frame_lo;
  logic       tx_fifo_good_frame_lo;
  logic       rx_error_bad_frame_lo;
  logic       rx_error_bad_fcs_lo;
  logic       rx_fifo_overflow_lo;
  logic       rx_fifo_bad_frame_lo;
  logic       rx_fifo_good_frame_lo;
  logic [1:0] speed_lo;

  logic tx_interrupt_clear_lo;
  logic rx_interrupt_enable_lo, rx_interrupt_enable_v_lo;
  logic tx_interrupt_enable_lo, tx_interrupt_enable_v_lo;
  logic rx_interrupt_pending_lo, tx_interrupt_pending_lo;


  logic [data_width_p-1:0]   tx_axis_tdata_lo;
  logic [data_width_p/8-1:0] tx_axis_tkeep_lo;
  logic                      tx_axis_tvalid_lo;
  logic                      tx_axis_tlast_lo;
  logic                      tx_axis_tready_li;
  logic                      tx_axis_tuser_lo;

  logic [data_width_p-1:0]   rx_axis_tdata_li;
  logic [data_width_p/8-1:0] rx_axis_tkeep_li;
  logic                      rx_axis_tvalid_li;
  logic                      rx_axis_tready_lo;
  logic                      rx_axis_tlast_li;
  logic                      rx_axis_tuser_li;


  wire [15:0] debug_info_li = {
    tx_error_underflow_lo
   ,tx_fifo_overflow_lo
   ,tx_fifo_bad_frame_lo
   ,tx_fifo_good_frame_lo
   ,rx_error_bad_frame_lo
   ,rx_error_bad_fcs_lo
   ,rx_fifo_overflow_lo
   ,rx_fifo_bad_frame_lo
   ,rx_fifo_good_frame_lo
   ,speed_lo
   };

  logic io_decode_error_lo;

  ethernet_memory_map #(
    .eth_mtu_p(eth_mtu_lp)
   ,.data_width_p(data_width_p)
  ) memory_map (
    .clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.addr_i(addr_i)
   ,.write_en_i(write_en_i)
   ,.read_en_i(read_en_i)
   ,.op_size_i(op_size_i)
   ,.write_data_i(write_data_i)
   ,.read_data_o(read_data_o)

   ,.debug_info_i(debug_info_li)

   ,.packet_send_o(packet_send_lo)
   ,.packet_req_i(packet_req_lo)
   ,.packet_wsize_valid_o(packet_wsize_valid_lo)
   ,.packet_wsize_o(packet_wsize_lo)
   ,.packet_wvalid_o(packet_wvalid_lo)
   ,.packet_waddr_o(packet_waddr_lo)
   ,.packet_wdata_o(packet_wdata_lo)
   ,.packet_wdata_size_o(packet_wdata_size_lo)

   ,.packet_ack_o(packet_ack_lo)
   ,.packet_avail_i(packet_avail_lo)
   ,.packet_rvalid_o(packet_rvalid_lo)
   ,.packet_raddr_o(packet_raddr_lo)
   ,.packet_rdata_size_o(packet_rdata_size_lo)
   ,.packet_rdata_i(packet_rdata_lo)
   ,.packet_rsize_i(packet_rsize_lo)

   ,.tx_interrupt_clear_o(tx_interrupt_clear_lo)

   ,.rx_interrupt_pending_i(rx_interrupt_pending_lo)
   ,.tx_interrupt_pending_i(tx_interrupt_pending_lo)
   ,.rx_interrupt_enable_o(rx_interrupt_enable_lo)
   ,.rx_interrupt_enable_v_o(rx_interrupt_enable_v_lo)
   ,.tx_interrupt_enable_o(tx_interrupt_enable_lo)
   ,.tx_interrupt_enable_v_o(tx_interrupt_enable_v_lo)

   ,.io_decode_error_o(io_decode_error_lo)
  );


  ethernet_sender #(
       .data_width_p(data_width_p)
      ,.eth_mtu_p(eth_mtu_lp))
   sender (
       .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.packet_send_i(packet_send_lo)
      ,.packet_req_o(packet_req_lo)
      ,.packet_wsize_valid_i(packet_wsize_valid_lo)
      ,.packet_wsize_i(packet_wsize_lo)
      ,.packet_wvalid_i(packet_wvalid_lo)
      ,.packet_waddr_i(packet_waddr_lo)
      ,.packet_wdata_i(packet_wdata_lo)
      ,.packet_wdata_size_i(packet_wdata_size_lo)

      ,.tx_axis_tdata_o(tx_axis_tdata_lo)
      ,.tx_axis_tkeep_o(tx_axis_tkeep_lo)
      ,.tx_axis_tvalid_o(tx_axis_tvalid_lo)
      ,.tx_axis_tlast_o(tx_axis_tlast_lo)
      ,.tx_axis_tready_i(tx_axis_tready_li)
      ,.tx_axis_tuser_o(tx_axis_tuser_lo)

      ,.send_count_o(/* UNUSED */)
  );

  ethernet_receiver #(
      .data_width_p(data_width_p)
     ,.eth_mtu_p(eth_mtu_lp))
   receiver (
      .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_ack_i(packet_ack_lo)
     ,.packet_avail_o(packet_avail_lo)
     ,.packet_rvalid_i(packet_rvalid_lo)
     ,.packet_raddr_i(packet_raddr_lo)
     ,.packet_rdata_size_i(packet_rdata_size_lo)
     ,.packet_rdata_o(packet_rdata_lo)
     ,.packet_rsize_o(packet_rsize_lo)

     ,.rx_axis_tdata_i(rx_axis_tdata_li)
     ,.rx_axis_tkeep_i(rx_axis_tkeep_li)
     ,.rx_axis_tvalid_i(rx_axis_tvalid_li)
     ,.rx_axis_tready_o(rx_axis_tready_lo)
     ,.rx_axis_tlast_i(rx_axis_tlast_li)
     ,.rx_axis_tuser_i(rx_axis_tuser_li)

     ,.receive_count_o(/* UNUSED */)
  );

  eth_mac_1g_rgmii_fifo #(.AXIS_DATA_WIDTH(data_width_p))
      mac (
      .clk250(clk250_i)
     ,.clk250_rst(reset_clk250_i)
     ,.gtx_rst(reset_clk125_o)
     ,.logic_clk(clk_i)
     ,.logic_rst(reset_i)

     ,.tx_axis_tdata(tx_axis_tdata_lo)
     ,.tx_axis_tkeep(tx_axis_tkeep_lo)
     ,.tx_axis_tvalid(tx_axis_tvalid_lo)
     ,.tx_axis_tready(tx_axis_tready_li)
     ,.tx_axis_tlast(tx_axis_tlast_lo)
     ,.tx_axis_tuser(tx_axis_tuser_lo)

     ,.rx_axis_tdata(rx_axis_tdata_li)
     ,.rx_axis_tkeep(rx_axis_tkeep_li)
     ,.rx_axis_tvalid(rx_axis_tvalid_li)
     ,.rx_axis_tready(rx_axis_tready_lo)
     ,.rx_axis_tlast(rx_axis_tlast_li)
     ,.rx_axis_tuser(rx_axis_tuser_li)

     ,.rgmii_rx_clk(rgmii_rx_clk_i)
     ,.rgmii_rxd(rgmii_rxd_i)
     ,.rgmii_rx_ctl(rgmii_rx_ctl_i)
     ,.rgmii_tx_clk(rgmii_tx_clk_o)
     ,.rgmii_txd(rgmii_txd_o)
     ,.rgmii_tx_ctl(rgmii_tx_ctl_o)

     ,.tx_error_underflow(tx_error_underflow_lo)
     ,.tx_fifo_overflow(tx_fifo_overflow_lo)
     ,.tx_fifo_bad_frame(tx_fifo_bad_frame_lo)
     ,.tx_fifo_good_frame(tx_fifo_good_frame_lo)
     ,.rx_error_bad_frame(rx_error_bad_frame_lo)
     ,.rx_error_bad_fcs(rx_error_bad_fcs_lo)
     ,.rx_fifo_overflow(rx_fifo_overflow_lo)
     ,.rx_fifo_bad_frame(rx_fifo_bad_frame_lo)
     ,.rx_fifo_good_frame(rx_fifo_good_frame_lo)
     ,.speed(speed_lo)

     ,.ifg_delay(8'd12)
  );

  interrupt_control_unit interrupt_control_unit (
    .clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.packet_avail_i(packet_avail_lo)
   ,.packet_req_i(packet_req_lo)

   ,.tx_interrupt_clear_i(tx_interrupt_clear_lo)

   ,.rx_interrupt_enable_i(rx_interrupt_enable_lo)
   ,.rx_interrupt_enable_v_i(rx_interrupt_enable_v_lo)
   ,.tx_interrupt_enable_i(tx_interrupt_enable_lo)
   ,.tx_interrupt_enable_v_i(tx_interrupt_enable_v_lo)

   ,.rx_interrupt_pending_o(rx_interrupt_pending_lo)
   ,.tx_interrupt_pending_o(tx_interrupt_pending_lo)
   // TODO: Add rx_interrupt_o
   // TODO: Add tx_interrupt_o
   );

  assign rx_interrupt_pending_o = rx_interrupt_pending_lo;
  assign tx_interrupt_pending_o = tx_interrupt_pending_lo;

  // synopsys translate_off
  always_ff @(negedge clk_i) begin
    if(~reset_i) begin
      assert(io_decode_error_lo == 0) else
        $error("ethernet_controller.sv: io decode error\n");
    end
  end
  // synopsys translate_on


endmodule
