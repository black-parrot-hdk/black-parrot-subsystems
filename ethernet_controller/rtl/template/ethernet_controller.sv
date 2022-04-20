
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

  // synopsys translate_off
  always_ff @(negedge clk_i) begin
    if(~reset_i) begin
      assert(io_decode_error_lo == 0) else
        $error("ethernet_controller.sv: io decode error\n");
    end
  end
  // synopsys translate_on


  mac_with_buffer #(
    .eth_mtu_p(eth_mtu_lp)
   ,.data_width_p(data_width_p)
  ) eth (
    .clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.clk250_i(clk250_i)
   ,.reset_clk250_i(reset_clk250_i)
   ,.reset_clk125_o(reset_clk125_o)

   ,.packet_send_i(packet_send_lo)
   ,.packet_req_o(packet_req_lo)
   ,.packet_wsize_valid_i(packet_wsize_valid_lo)
   ,.packet_wsize_i(packet_wsize_lo)
   ,.packet_wvalid_i(packet_wvalid_lo)
   ,.packet_waddr_i(packet_waddr_lo)
   ,.packet_wdata_i(packet_wdata_lo)
   ,.packet_wdata_size_i(packet_wdata_size_lo)

   ,.packet_ack_i(packet_ack_lo)
   ,.packet_avail_o(packet_avail_lo)
   ,.packet_rvalid_i(packet_rvalid_lo)
   ,.packet_raddr_i(packet_raddr_lo)
   ,.packet_rdata_size_i(packet_rdata_size_lo)
   ,.packet_rdata_o(packet_rdata_lo)
   ,.packet_rsize_o(packet_rsize_lo)

   ,.rgmii_rx_clk_i(rgmii_rx_clk_i)
   ,.rgmii_rxd_i(rgmii_rxd_i)
   ,.rgmii_rx_ctl_i(rgmii_rx_ctl_i)
   ,.rgmii_tx_clk_o(rgmii_tx_clk_o)
   ,.rgmii_txd_o(rgmii_txd_o)
   ,.rgmii_tx_ctl_o(rgmii_tx_ctl_o)

   ,.tx_error_underflow_o(tx_error_underflow_lo)
   ,.tx_fifo_overflow_o(tx_fifo_overflow_lo)
   ,.tx_fifo_bad_frame_o(tx_fifo_bad_frame_lo)
   ,.tx_fifo_good_frame_o(tx_fifo_good_frame_lo)
   ,.rx_error_bad_frame_o(rx_error_bad_frame_lo)
   ,.rx_error_bad_fcs_o(rx_error_bad_fcs_lo)
   ,.rx_fifo_overflow_o(rx_fifo_overflow_lo)
   ,.rx_fifo_bad_frame_o(rx_fifo_bad_frame_lo)
   ,.rx_fifo_good_frame_o(rx_fifo_good_frame_lo)

   ,.send_count_o(/* UNUSED */)
   ,.receive_count_o(/* UNUSED */)

   ,.speed_o(speed_lo)
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

endmodule
