/*
 * Name:
 *   bp_me_axi_to_fifo.sv
 *
 * Description:
 *   This module converts an AXI4 subordinate interface to a fifo interface. The independent
 *   read and write channels are serialized to the output fifo interface and responses are expected
 *   to return in-order. Requests larger than 64b are output as independent 64b requests on
 *   the fifo interface, with this module handling the aggregation of responses for AXI.
 *
 * Constraints and Assumptions:
 *   - data width must be 64-bits
 *   - address must be naturally aligned to request size (axsize)
 *   - 8, 16, and 32-bit requests must have axlen equal to 0
 *   - requests with axsize of 64-bits may have axlen greater than 0
 *
 */

`include "bsg_defines.v"

module bp_me_axi_to_fifo
 import bsg_axi_pkg::*;
 #(parameter s_axi_data_width_p = 64
  , parameter s_axi_addr_width_p = 64
  , parameter s_axi_id_width_p = 1
  , localparam s_axi_mask_width_lp = s_axi_data_width_p>>3
  )
  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   //==================== FIFO Interface =======================
   , output logic [s_axi_data_width_p-1:0]      data_o
   , output logic [s_axi_addr_width_p-1:0]      addr_o
   , output logic                               v_o
   , output logic                               w_o
   , output logic [s_axi_mask_width_lp-1:0]     wmask_o
   , output logic [2:0]                         size_o
   , input                                      ready_and_i

   , input [s_axi_data_width_p-1:0]             data_i
   , input                                      v_i
   , input                                      w_i
   , output logic                               ready_and_o


   //====================== AXI-4 =========================
   , input [s_axi_addr_width_p-1:0]             s_axi_awaddr_i
   , input                                      s_axi_awvalid_i
   , output logic                               s_axi_awready_o
   , input [s_axi_id_width_p-1:0]               s_axi_awid_i
   , input                                      s_axi_awlock_i
   , input [3:0]                                s_axi_awcache_i
   , input [2:0]                                s_axi_awprot_i
   , input [7:0]                                s_axi_awlen_i
   , input [2:0]                                s_axi_awsize_i
   , input [1:0]                                s_axi_awburst_i
   , input [3:0]                                s_axi_awqos_i
   , input [3:0]                                s_axi_awregion_i

   , input [s_axi_data_width_p-1:0]             s_axi_wdata_i
   , input                                      s_axi_wvalid_i
   , output logic                               s_axi_wready_o
   , input                                      s_axi_wlast_i
   , input [s_axi_mask_width_lp-1:0]            s_axi_wstrb_i

   , output logic                               s_axi_bvalid_o
   , input                                      s_axi_bready_i
   , output logic [s_axi_id_width_p-1:0]        s_axi_bid_o
   , output logic [1:0]                         s_axi_bresp_o

   , input [s_axi_addr_width_p-1:0]             s_axi_araddr_i
   , input                                      s_axi_arvalid_i
   , output logic                               s_axi_arready_o
   , input [s_axi_id_width_p-1:0]               s_axi_arid_i
   , input                                      s_axi_arlock_i
   , input [3:0]                                s_axi_arcache_i
   , input [2:0]                                s_axi_arprot_i
   , input [7:0]                                s_axi_arlen_i
   , input [2:0]                                s_axi_arsize_i
   , input [1:0]                                s_axi_arburst_i
   , input [3:0]                                s_axi_arqos_i
   , input [3:0]                                s_axi_arregion_i

   , output logic [s_axi_data_width_p-1:0]      s_axi_rdata_o
   , output logic                               s_axi_rvalid_o
   , input                                      s_axi_rready_i
   , output logic [s_axi_id_width_p-1:0]        s_axi_rid_o
   , output logic                               s_axi_rlast_o
   , output logic [1:0]                         s_axi_rresp_o
   );

  // AW channel pump and ID fifo
  logic [s_axi_addr_width_p-1:0] awpump_addr_lo;
  logic [s_axi_mask_width_lp-1:0] awpump_mask_lo;
  logic [2:0] awpump_size_lo;
  logic [7:0] awpump_len_lo;
  logic awpump_first_lo, awpump_last_lo;
  logic awpump_v_li, awpump_ready_and_lo, awpump_v_lo, awpump_send_li;

  logic awid_v_li, awid_ready_and_lo;
  logic [s_axi_id_width_p-1:0] awid_li;
  logic awid_v_lo, awid_yumi_li;

  // handshake only if both AW Pump and AW ID FIFO can accept
  assign awpump_v_li = s_axi_awvalid_i & awid_ready_and_lo;
  assign awid_v_li = s_axi_awvalid_i & awpump_ready_and_lo;
  assign s_axi_awready_o = awpump_ready_and_lo & awid_ready_and_lo;

  assign awpump_send_li = v_o & w_o & ready_and_i;

  bp_me_axi_pump
    #(.axi_addr_width_p(s_axi_addr_width_p)
      ,.axi_data_width_p(s_axi_data_width_p)
      )
    aw_pump
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(awpump_v_li)
      ,.ready_and_o(awpump_ready_and_lo)
      ,.axaddr_i(s_axi_awaddr_i)
      ,.axburst_i(s_axi_awburst_i)
      ,.axlen_i(s_axi_awlen_i)
      ,.axsize_i(s_axi_awsize_i)
      ,.v_o(awpump_v_lo)
      ,.send_i(awpump_send_li)
      ,.addr_o(awpump_addr_lo)
      ,.mask_o(awpump_mask_lo)
      ,.size_o(awpump_size_lo)
      ,.len_o(awpump_len_lo)
      ,.first_o(awpump_first_lo)
      ,.last_o(awpump_last_lo)
      );

  // one ID per AXI transaction
  // capture when pump accepts inputs, dequeue on write response
  bsg_two_fifo
    #(.width_p(s_axi_id_width_p))
    awid_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_awid_i})
      ,.v_i(awid_v_li)
      ,.ready_o(awid_ready_and_lo)
      ,.data_o({awid_li})
      ,.v_o(awid_v_lo)
      ,.yumi_i(awid_yumi_li)
      );

  // W channel fifo
  logic wvalid_lo, wyumi_li;
  bsg_two_fifo
    #(.width_p(s_axi_data_width_p+s_axi_mask_width_lp))
    w_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_wstrb_i, s_axi_wdata_i})
      ,.v_i(s_axi_wvalid_i)
      ,.ready_o(s_axi_wready_o)
      ,.data_o({wmask_o, data_o})
      ,.v_o(wvalid_lo)
      ,.yumi_i(wyumi_li)
      );

  // AR channel pump and ID fifo
  logic [s_axi_addr_width_p-1:0] arpump_addr_lo;
  logic [s_axi_mask_width_lp-1:0] arpump_mask_lo;
  logic [2:0] arpump_size_lo;
  logic [7:0] arpump_len_lo;
  logic arpump_first_lo, arpump_last_lo;
  logic arpump_v_li, arpump_ready_and_lo, arpump_v_lo, arpump_send_li;

  logic arid_v_li, arid_ready_and_lo;
  logic [s_axi_id_width_p-1:0] arid_li;
  logic arid_v_lo, arid_yumi_li;

  // handshake only if both AR Pump and AR ID FIFO can accept
  assign arpump_v_li = s_axi_arvalid_i & arid_ready_and_lo;
  assign arid_v_li = s_axi_arvalid_i & arpump_ready_and_lo;
  assign s_axi_arready_o = arpump_ready_and_lo & arid_ready_and_lo;

  assign arpump_send_li = v_o & ~w_o & ready_and_i;

  bp_me_axi_pump
    #(.axi_addr_width_p(s_axi_addr_width_p)
      ,.axi_data_width_p(s_axi_data_width_p)
      )
    ar_pump
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(arpump_v_li)
      ,.ready_and_o(arpump_ready_and_lo)
      ,.axaddr_i(s_axi_araddr_i)
      ,.axburst_i(s_axi_arburst_i)
      ,.axlen_i(s_axi_arlen_i)
      ,.axsize_i(s_axi_arsize_i)
      ,.v_o(arpump_v_lo)
      ,.send_i(arpump_send_li)
      ,.addr_o(arpump_addr_lo)
      ,.mask_o(arpump_mask_lo)
      ,.size_o(arpump_size_lo)
      ,.len_o(arpump_len_lo)
      ,.first_o(arpump_first_lo)
      ,.last_o(arpump_last_lo)
      );

  // one ID per AXI transaction
  // capture when pump accepts inputs, dequeue on last read response
  bsg_two_fifo
    #(.width_p(s_axi_id_width_p))
    arid_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i({s_axi_arid_i})
      ,.v_i(arid_v_li)
      ,.ready_o(arid_ready_and_lo)
      ,.data_o({arid_li})
      ,.v_o(arid_v_lo)
      ,.yumi_i(arid_yumi_li)
      );

  // response fifo
  // every read and write sent will enqueue a response here
  logic response_v_lo, response_yumi_li, response_w_lo;
  logic [s_axi_data_width_p-1:0] response_data_lo;
  bsg_two_fifo
    #(.width_p(s_axi_data_width_p+1))
    response_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from FIFO interface
      ,.v_i(v_i)
      ,.ready_o(ready_and_o)
      ,.data_i({w_i, data_i})
      // to AXI
      ,.v_o(response_v_lo)
      ,.yumi_i(response_yumi_li)
      ,.data_o({response_w_lo, response_data_lo})
      );

  // down counter for response tracking
  // set to axlen when handling multi-transfer message
  // done when count == 0 & send
  logic [7:0] transfer_count, transfer_count_val;
  logic transfer_count_set, transfer_count_down;
  bsg_counter_set_down
    #(.width_p(8)
      ,.init_val_p(0)
      ,.set_and_down_exclusive_p(0) // can set and down same cycle
      )
    transfer_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(transfer_count_set)
      ,.val_i(transfer_count_val)
      ,.down_i(transfer_count_down)
      ,.count_r_o(transfer_count)
      );
  wire last_transfer = (transfer_count == 0);

  // B channel (write) response
  // send only one response for the entire write transaction
  wire bsend = s_axi_bvalid_o & s_axi_bready_i;
  assign s_axi_bvalid_o = response_v_lo & response_w_lo & last_transfer & awid_v_lo;
  assign s_axi_bresp_o = e_axi_resp_okay;
  assign s_axi_bid_o = awid_li;
  assign awid_yumi_li = bsend & last_transfer;
  assign wyumi_li = awpump_send_li;

  // R channel (read) response
  // send one response on AXI for every read issued to FIFO
  wire rsend = s_axi_rvalid_o & s_axi_rready_i;
  assign s_axi_rvalid_o = response_v_lo & ~response_w_lo & arid_v_lo;
  assign s_axi_rresp_o = e_axi_resp_okay;
  assign s_axi_rdata_o = response_data_lo;
  assign s_axi_rlast_o = last_transfer;
  assign s_axi_rid_o = arid_li;
  assign arid_yumi_li = rsend & last_transfer;

  wire first_write = awpump_send_li & awpump_first_lo;
  wire last_write = awpump_send_li & awpump_last_lo;
  wire first_read = arpump_send_li & arpump_first_lo;
  wire last_read = arpump_send_li & arpump_last_lo;
  wire last_response_send = bsend | (rsend & last_transfer);

  // transfer count control
  // decrements every time response is consumed, except if count is 0
  assign transfer_count_down = response_yumi_li & ~last_transfer;
  assign transfer_count_set = (first_write | first_read);
  assign transfer_count_val = arpump_v_lo ? arpump_len_lo : awpump_len_lo;

  // consume response beats as follows:
  // for reads, every time R channel sends
  // for writes, when B channel sends on last response or unconditionally before that
  assign response_yumi_li = rsend | bsend | (response_v_lo & response_w_lo & ~last_transfer);

  // FSM for sending on fifo interface
  typedef enum logic [1:0] {
    e_ready
    ,e_write
    ,e_read
    ,e_wait
  } state_e;
  state_e state_r, state_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

  always_comb begin
    state_n = state_r;

    v_o = 1'b0;
    addr_o = '0;
    size_o = '0;
    w_o = 1'b0;

    case (state_r)
      // send first read or write transfer
      // if multi-transfer transaction, go to e_read or e_write
      // else block until last response sends
      e_ready: begin
        // priority to reads
        v_o = (awpump_v_lo & wvalid_lo) | arpump_v_lo;
        addr_o = arpump_v_lo ? arpump_addr_lo : awpump_addr_lo;
        size_o = arpump_v_lo ? arpump_size_lo : awpump_size_lo;
        w_o = awpump_v_lo & wvalid_lo & ~arpump_v_lo;

        if (arpump_send_li & ~arpump_last_lo) begin
          state_n = e_read;
        end
        else if (awpump_send_li & ~awpump_last_lo) begin
          state_n = e_write;
        end
        else if (last_write | last_read) begin
          state_n = e_wait;
        end
      end
      // handle multi-transfer writes
      e_write: begin
        v_o = awpump_v_lo & wvalid_lo;
        addr_o = awpump_addr_lo;
        size_o = awpump_size_lo;
        w_o = 1'b1;
        state_n = last_write ? e_wait : state_r;
      end
      // handle multi-transfer reads
      e_read: begin
        v_o = arpump_v_lo;
        addr_o = arpump_addr_lo;
        size_o = arpump_size_lo;
        w_o = 1'b0;
        state_n = last_read ? e_wait : state_r;
      end
      // block until transaction complete
      e_wait: begin
        state_n = last_response_send
                  ? e_ready
                  : state_r;
      end
      default: begin
      end
    endcase
  end

endmodule

