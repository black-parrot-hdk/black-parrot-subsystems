
/*
 * This module receives packets from axis bus and stores them in its buffer.
 * Received packets can be read through packet_* signals.
 *
 */

`include "bsg_defines.v"

module ethernet_receiver
#(
      parameter  data_width_p  = 32
      // maximum size of an Ethernet packet
    , parameter  eth_mtu_p  = 2048 // byte
    , parameter  recv_count_p  = (32'b1 << 16 - 1)
    , localparam addr_width_lp = $clog2(eth_mtu_p)
    , localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p/8))
    , localparam packet_size_width_lp = $clog2(eth_mtu_p+1)
)
(
      input logic                             clk_i
    , input logic                             reset_i

    /* Host <- Packet */
      // clear packet
    , input logic                             packet_ack_i
      // packet is ready to read
    , output logic                            packet_avail_o
    , input logic                             packet_rvalid_i
    , input logic  [addr_width_lp-1:0]        packet_raddr_i
      // read data size other than data_width_p is not supported
    , input logic  [size_width_lp-1:0]        packet_rdata_size_i
      // sync read
    , output logic [data_width_p-1:0]         packet_rdata_o
    , output logic [packet_size_width_lp-1:0] packet_rsize_o

    /* Packet <- AXIS */
    , input logic [data_width_p-1:0]          rx_axis_tdata_i
    , input logic [data_width_p/8-1:0]        rx_axis_tkeep_i
    , input logic                             rx_axis_tvalid_i
    , output logic                            rx_axis_tready_o
    , input logic                             rx_axis_tlast_i
    , input logic                             rx_axis_tuser_i

    /* stat */
    , output logic [$clog2(recv_count_p+1)-1:0] receive_count_o
);
  localparam recv_ptr_width_lp = $clog2(eth_mtu_p/(data_width_p/8));

  logic                     packet_avail_lo;
  logic                     packet_ack_li;
  logic [packet_size_width_lp-1:0] packet_rsize_lo;
  logic                     packet_rvalid_li;
  logic [addr_width_lp-1:0] packet_raddr_li;
  logic [data_width_p-1:0]  packet_rdata_lo;

  logic                     packet_send_li;
  logic                     packet_req_lo;

  logic                     packet_wsize_valid_li;
  logic [packet_size_width_lp-1:0] packet_wsize_li;

  logic                     packet_wvalid_li;
  logic [addr_width_lp-1:0] packet_waddr_li;
  logic [data_width_p-1:0]  packet_wdata_li;

  logic recv_ptr_unwind;
  logic recv_ptr_increment;
  logic [recv_ptr_width_lp-1:0] recv_ptr_r;
  logic [packet_size_width_lp-1:0] packet_size_remaining;

  logic receive_complete;
  bsg_flow_counter #(.els_p(recv_count_p))
   receive_count (
    .clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.v_i(receive_complete)
   ,.ready_i(1'b1)
   ,.yumi_i(1'b0)

   ,.count_o(receive_count_o)
  );


if(data_width_p == 64) begin
  always_comb begin
    packet_size_remaining = 'h0;
    case(rx_axis_tkeep_i)
      8'b1111_1111:
        packet_size_remaining = 'h8;
      8'b0111_1111:
        packet_size_remaining = 'h7;
      8'b0011_1111:
        packet_size_remaining = 'h6;
      8'b0001_1111:
        packet_size_remaining = 'h5;
      8'b0000_1111:
        packet_size_remaining = 'h4;
      8'b0000_0111:
        packet_size_remaining = 'h3;
      8'b0000_0011:
        packet_size_remaining = 'h2;
      8'b0000_0001:
        packet_size_remaining = 'h1;
    endcase
  end
end
else if(data_width_p == 32) begin
  always_comb begin
    packet_size_remaining = 'h0;
    case(rx_axis_tkeep_i)
      4'b1111:
        packet_size_remaining = 'h4;
      4'b0111:
        packet_size_remaining = 'h3;
      4'b0011:
        packet_size_remaining = 'h2;
      4'b0001:
        packet_size_remaining = 'h1;
    endcase
  end
end

  bsg_counter_clear_up #( // unit: 'data_width_p/8' byte
      .max_val_p(eth_mtu_p/(data_width_p/8)-1)
     ,.init_val_p(0)
    ) recv_counter (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(recv_ptr_unwind)
     ,.up_i(recv_ptr_increment)
     ,.count_o(recv_ptr_r)
    );

  assign packet_avail_o = packet_avail_lo;

  packet_buffer #(.slot_p(2)
     ,.data_width_p(data_width_p)
     ,.els_p(eth_mtu_p))
    rx_buffer (
      .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_avail_o(packet_avail_lo)
     ,.packet_ack_i(packet_ack_li)
     ,.packet_rvalid_i(packet_rvalid_li)
     ,.packet_raddr_i(packet_raddr_li)
     ,.packet_rdata_o(packet_rdata_lo)
     ,.packet_rsize_o(packet_rsize_lo)

     ,.packet_send_i(packet_send_li)
     ,.packet_req_o(packet_req_lo)
     ,.packet_wsize_valid_i(packet_wsize_valid_li)
     ,.packet_wsize_i(packet_wsize_li)
     ,.packet_wvalid_i(packet_wvalid_li)
     ,.packet_waddr_i(packet_waddr_li)
     ,.packet_wdata_i(packet_wdata_li)
     ,.packet_wdata_size_i($clog2(data_width_p >> 3))
    );

  always_comb begin
    packet_rsize_o = '0;
    packet_ack_li = 1'b0;
    packet_rvalid_li = 1'b0;
    packet_raddr_li = packet_raddr_i;
    packet_rdata_o = packet_rdata_lo;
    if(packet_avail_lo) begin
      packet_rsize_o = packet_rsize_lo;
      packet_ack_li = packet_ack_i;
      packet_rvalid_li = packet_rvalid_i;
    end
  end

  // synopsys translate_off
  always_ff @(posedge clk_i) begin
    if(~reset_i) begin
      assert(~(~packet_avail_lo & packet_rvalid_i))
        else $error("reading data when rx not ready");
      assert(~(~packet_avail_lo & packet_ack_i))
        else $error("receiving packet when rx not ready");
      assert((packet_rvalid_li != 1'b1) ||
        (packet_rdata_size_i == $clog2(data_width_p/8)))
          else $error("ethernet_receiver: unsupported read size");
    end
  end
  // synopsys translate_on

  always_comb begin
    rx_axis_tready_o = 1'b0;
    recv_ptr_unwind = 1'b0;
    recv_ptr_increment = 1'b0;
    packet_send_li = 1'b0;
    packet_wsize_li = '0;
    packet_wsize_valid_li = 1'b0;
    packet_wvalid_li = 1'b0;
    packet_waddr_li = '0;
    packet_wdata_li = '0;
    receive_complete = 1'b0;
    if(packet_req_lo) begin
      rx_axis_tready_o = 1'b1;
      if(rx_axis_tvalid_i) begin
        packet_wvalid_li = 1'b1;
        packet_waddr_li = addr_width_lp'(recv_ptr_r*(data_width_p/8));
        packet_wdata_li = rx_axis_tdata_i;
        if(rx_axis_tlast_i) begin
          recv_ptr_unwind = 1'b1;
          if(~rx_axis_tuser_i) begin
            // end of good frame
            packet_send_li = 1'b1;
            packet_wsize_li = (recv_ptr_r*(data_width_p/8)) + packet_size_remaining;
            packet_wsize_valid_li = 1'b1;
            receive_complete = 1'b1;
          end
        end
        else begin
          recv_ptr_increment = 1'b1;
        end
      end
    end
  end

endmodule
