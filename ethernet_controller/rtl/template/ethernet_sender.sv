
/*
 * This module receives packets from packet_* signals and stores them
 * in its buffer. Received packets are then sent to axis bus.
 *
 */

`include "bsg_defines.v"

module ethernet_sender #
(
      parameter  data_width_p   = 32
      // maximum size of an Ethernet packet
    , parameter  eth_mtu_p     = 2048 // byte
    , parameter  send_count_p  = (32'b1 << 16 - 1)
    , localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p/8))
    , localparam addr_width_lp = $clog2(eth_mtu_p)
    , localparam packet_size_width_lp = $clog2(eth_mtu_p+1)
)
(
      input  logic                                 clk_i
    , input  logic                                 reset_i

      // send out packet
    , input  logic                                 packet_send_i
      // space available for packet
    , output logic                                 packet_req_o

    /* Host -> Packet */
    , input  logic                                 packet_wsize_valid_i
    , input  logic [packet_size_width_lp-1:0]      packet_wsize_i
    , input  logic                                 packet_wvalid_i
    , input  logic [addr_width_lp-1:0]             packet_waddr_i
    , input  logic [data_width_p-1:0]              packet_wdata_i
    , input  logic [size_width_lp-1:0]             packet_wdata_size_i

    /* Packet -> AXIS */
    , output logic [data_width_p-1:0]              tx_axis_tdata_o
    , output logic [data_width_p/8-1:0]            tx_axis_tkeep_o
    , output logic                                 tx_axis_tvalid_o
    , output logic                                 tx_axis_tlast_o
    , input  logic                                 tx_axis_tready_i
    , output logic                                 tx_axis_tuser_o

    , output logic [$clog2(send_count_p+1)-1:0]    send_count_o
);
  localparam send_ptr_width_lp        = $clog2(eth_mtu_p/(data_width_p/8));
  localparam send_ptr_offset_width_lp = $clog2(data_width_p/8);

  logic [send_ptr_width_lp - 1:0]    send_ptr_r;

  logic [data_width_p/8-1:0]       tx_axis_tkeep_li;
  logic                            tx_axis_tlast_li;
  logic                            tx_axis_tuser_li;

  logic                            packet_avail_lo;
  logic                            packet_ack_li;
  logic [packet_size_width_lp-1:0] packet_rsize_lo;
  logic                            packet_rvalid_li;
  logic [addr_width_lp-1:0]        packet_raddr_li;
  logic [data_width_p-1:0]         packet_rdata_lo;

  logic send_ptr_increment;


  logic [send_ptr_width_lp - 1:0]         send_ptr_end;
  logic [send_ptr_offset_width_lp - 1 :0] send_remaining;
  logic last_send_f;

  logic packet_req_lo;

  logic packet_wsize_valid_li;
  logic packet_wvalid_li;
  logic packet_send_li;

  logic send_complete;
  bsg_flow_counter #(.els_p(send_count_p))
   send_count (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(send_complete)
     ,.ready_i(1'b1)
     ,.yumi_i(1'b0)
     ,.count_o(send_count_o)
  );

  packet_buffer #(.slot_p(2)
     ,.data_width_p(data_width_p)
     ,.els_p(eth_mtu_p))
    tx_buffer (
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
     ,.packet_wsize_i(packet_wsize_i)
     ,.packet_wvalid_i(packet_wvalid_li)
     ,.packet_waddr_i(packet_waddr_i)
     ,.packet_wdata_i(packet_wdata_i)
     ,.packet_wdata_size_i(packet_wdata_size_i)
    );


  // used for aligning the control signals with the sycn read value
  bsg_dff_reset_en #(
      .width_p(data_width_p/8+2)
    ) tx_dff (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(packet_rvalid_li)
     ,.data_i({tx_axis_tkeep_li, tx_axis_tlast_li, tx_axis_tuser_li})
     ,.data_o({tx_axis_tkeep_o, tx_axis_tlast_o, tx_axis_tuser_o})
    );
  logic packet_rvalid_lo, packet_rready_li;
  bsg_dff_reset_set_clear #(.width_p(1)
    ) packet_rvalid_reg (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(packet_rvalid_li)
     ,.clear_i(packet_rready_li)
     ,.data_o(packet_rvalid_lo)
    );
  assign packet_rready_li = tx_axis_tready_i;
  assign tx_axis_tvalid_o = packet_rvalid_lo;

  logic send_ptr_unwind;
  bsg_counter_clear_up #( // unit: 'data_width_p/8' byte
      .max_val_p(eth_mtu_p/(data_width_p/8)-1)
     ,.init_val_p(0)
    ) send_counter (
      .clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(send_ptr_unwind)
     ,.up_i(send_ptr_increment)
     ,.count_o(send_ptr_r)
    );

  assign tx_axis_tdata_o = packet_rdata_lo;
  assign packet_raddr_li = (addr_width_lp)'(send_ptr_r*(data_width_p/8));

  assign send_ptr_end = (send_ptr_width_lp)'((packet_rsize_lo - 1) >> $clog2(data_width_p/8));
  assign send_remaining = packet_rsize_lo[$clog2(data_width_p/8)-1:0];
  assign last_send_f = (send_ptr_r == send_ptr_end);
  wire packet_rdata_sending = ~(packet_rvalid_lo & ~packet_rready_li);
  always_comb begin
    send_ptr_increment = 1'b0;
    send_ptr_unwind = 1'b0;
    packet_rvalid_li = 1'b0;
    packet_ack_li = 1'b0;
    send_complete = 1'b0;
    if(packet_avail_lo) begin
      if(packet_rdata_sending) begin
        packet_rvalid_li = 1'b1;
        if(~last_send_f) begin
          send_ptr_increment = 1'b1;
        end
        else begin
          send_ptr_unwind = 1'b1;
          packet_ack_li = 1'b1; // switch to next packet
          send_complete = 1'b1;
        end
      end
    end
  end
  assign tx_axis_tlast_li = last_send_f;
  assign tx_axis_tuser_li = 1'b0;

if(data_width_p == 64) begin
  always_comb begin
    if(!last_send_f)
      tx_axis_tkeep_li = '1;
    else begin
      tx_axis_tkeep_li = '0;
      case(send_remaining)
        3'd0:
          tx_axis_tkeep_li = 8'b1111_1111;
        3'd1:
          tx_axis_tkeep_li = 8'b0000_0001;
        3'd2:
          tx_axis_tkeep_li = 8'b0000_0011;
        3'd3:
          tx_axis_tkeep_li = 8'b0000_0111;
        3'd4:
          tx_axis_tkeep_li = 8'b0000_1111;
        3'd5:
          tx_axis_tkeep_li = 8'b0001_1111;
        3'd6:
          tx_axis_tkeep_li = 8'b0011_1111;
        3'd7:
          tx_axis_tkeep_li = 8'b0111_1111;
      endcase
    end
  end
end
else if(data_width_p == 32)begin
  always_comb begin
    if(!last_send_f)
      tx_axis_tkeep_li = '1;
    else begin
      tx_axis_tkeep_li = '0;
      case(send_remaining)
        2'd0:
          tx_axis_tkeep_li = 4'b1111;
        2'd1:
          tx_axis_tkeep_li = 4'b0001;
        2'd2:
          tx_axis_tkeep_li = 4'b0011;
        2'd3:
          tx_axis_tkeep_li = 4'b0111;
      endcase
    end
  end
end


  assign packet_req_o = packet_req_lo;
  always_comb begin
    packet_wsize_valid_li = 1'b0;
    packet_wvalid_li = 1'b0;
    packet_send_li = 1'b0;
    if(packet_req_lo) begin
      packet_wsize_valid_li = packet_wsize_valid_i;
      packet_wvalid_li = packet_wvalid_i;
      packet_send_li = packet_send_i;
    end
  end

  // synopsys translate_off
  always_ff @(posedge clk_i) begin
    if(reset_i == 1'b0) begin
      assert(~(~packet_req_lo & packet_wsize_valid_i))
        else $error("writing size when tx not ready");
      assert(~(~packet_req_lo & packet_wvalid_i))
        else $error("writing data when tx not ready");
      assert(~(~packet_req_lo & packet_send_i))
        else $error("sending packet when tx not ready");
      assert(data_width_p == 32 || data_width_p == 64)
        else $error("unsupported data_width_p");
    end

  end
  // synopsys translate_on

endmodule
