
`include "bsg_defines.v"

module mac_with_buffer #
(
      parameter  eth_mtu_p            = 2048 // byte
    , parameter  data_width_p         = 32
    , localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p/8))
    , localparam addr_width_lp        = $clog2(eth_mtu_p)
    , localparam packet_size_width_lp = $clog2(eth_mtu_p+1)
)
(
      input  logic        clk_i
    , input  logic        reset_i
    , input  logic        clk250_i
    , input  logic        reset_clk250_i
    , output logic        reset_clk125_o

    // Write side
    , input  logic                            packet_send_i
    , output logic                            packet_req_o
    , input  logic                            packet_wsize_valid_i
    , input  logic [packet_size_width_lp-1:0] packet_wsize_i
    , input  logic                            packet_wvalid_i
    , input  logic [addr_width_lp-1:0]        packet_waddr_i
    , input  logic [data_width_p-1:0]         packet_wdata_i
    , input  logic [size_width_lp-1:0]        packet_wdata_size_i

    // Read side
    , input  logic                            packet_ack_i
    , output logic                            packet_avail_o
    , input  logic                            packet_rvalid_i
    , input  logic [addr_width_lp-1:0]        packet_raddr_i
    , input  logic [size_width_lp-1:0]        packet_rdata_size_i
    , output logic [data_width_p-1:0]         packet_rdata_o
    , output logic [packet_size_width_lp-1:0] packet_rsize_o

    , input  logic        rgmii_rx_clk_i
    , input  logic [3:0]  rgmii_rxd_i
    , input  logic        rgmii_rx_ctl_i
    , output logic        rgmii_tx_clk_o
    , output logic [3:0]  rgmii_txd_o
    , output logic        rgmii_tx_ctl_o

    /* Status */
    , output logic        tx_error_underflow_o
    , output logic        tx_fifo_overflow_o
    , output logic        tx_fifo_bad_frame_o
    , output logic        tx_fifo_good_frame_o
    , output logic        rx_error_bad_frame_o
    , output logic        rx_error_bad_fcs_o
    , output logic        rx_fifo_overflow_o
    , output logic        rx_fifo_bad_frame_o
    , output logic        rx_fifo_good_frame_o

    , output logic [15:0] send_count_o
    , output logic [15:0] receive_count_o

    , output logic [1:0]  speed_o
);


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

    ethernet_sender #(
         .data_width_p(data_width_p)
        ,.eth_mtu_p(eth_mtu_p))
     sender (
         .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.packet_send_i
        ,.packet_req_o

        ,.packet_wsize_valid_i
        ,.packet_wsize_i
        ,.packet_wvalid_i
        ,.packet_waddr_i
        ,.packet_wdata_i
        ,.packet_wdata_size_i

        ,.tx_axis_tdata_o(tx_axis_tdata_lo)
        ,.tx_axis_tkeep_o(tx_axis_tkeep_lo)
        ,.tx_axis_tvalid_o(tx_axis_tvalid_lo)
        ,.tx_axis_tlast_o(tx_axis_tlast_lo)
        ,.tx_axis_tready_i(tx_axis_tready_li)
        ,.tx_axis_tuser_o(tx_axis_tuser_lo)

        ,.send_count_o(send_count_o)
    );

    ethernet_receiver #(
        .data_width_p(data_width_p)
       ,.eth_mtu_p(eth_mtu_p))
     receiver (
        .clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.packet_ack_i
       ,.packet_avail_o
       ,.packet_rvalid_i
       ,.packet_raddr_i
       ,.packet_rdata_size_i
       ,.packet_rdata_o
       ,.packet_rsize_o

       ,.rx_axis_tdata_i(rx_axis_tdata_li)
       ,.rx_axis_tkeep_i(rx_axis_tkeep_li)
       ,.rx_axis_tvalid_i(rx_axis_tvalid_li)
       ,.rx_axis_tready_o(rx_axis_tready_lo)
       ,.rx_axis_tlast_i(rx_axis_tlast_li)
       ,.rx_axis_tuser_i(rx_axis_tuser_li)

       ,.receive_count_o(receive_count_o)
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

       ,.tx_error_underflow(tx_error_underflow_o)
       ,.tx_fifo_overflow(tx_fifo_overflow_o)
       ,.tx_fifo_bad_frame(tx_fifo_bad_frame_o)
       ,.tx_fifo_good_frame(tx_fifo_good_frame_o)
       ,.rx_error_bad_frame(rx_error_bad_frame_o)
       ,.rx_error_bad_fcs(rx_error_bad_fcs_o)
       ,.rx_fifo_overflow(rx_fifo_overflow_o)
       ,.rx_fifo_bad_frame(rx_fifo_bad_frame_o)
       ,.rx_fifo_good_frame(rx_fifo_good_frame_o)
       ,.speed(speed_o)

       ,.ifg_delay(8'd12)
    );
endmodule
