/*
 * Name:
 *   bp_axi_pump.sv
 *
 * Description:
 *   This module implements AXI transaction counting per the spec (IHI0022H_c A3.4.1)
 *   In cycle 0, the transaction details are captured.
 *   In cycle 1+, each transfer can occur
 *
 */

`include "bsg_defines.sv"

module bp_axi_pump
  import bsg_axi_pkg::*;
 #(parameter axi_addr_width_p = 64
  ,parameter axi_data_width_p = 64
  ,localparam axi_mask_width_lp = (axi_data_width_p/8)
  ,localparam lg_axi_mask_width_lp = `BSG_SAFE_CLOG2(axi_mask_width_lp)
  )
 (//==================== GLOBAL SIGNALS =======================
  input                                        clk_i
  , input                                      reset_i

  , input                                      v_i
  , output logic                               ready_and_o
  , input [axi_addr_width_p-1:0]               axaddr_i
  , input [1:0]                                axburst_i
  , input [7:0]                                axlen_i
  , input [2:0]                                axsize_i

  , output logic                               v_o
  , input                                      send_i
  , output logic [axi_addr_width_p-1:0]        addr_o
  , output logic [axi_mask_width_lp-1:0]       mask_o
  , output logic [2:0]                         size_o
  , output logic [7:0]                         len_o
  , output logic                               first_o
  , output logic                               last_o
  );

  // FSM states
  // e_ready: accept new transaction and attempt to send first transfer details
  // e_send: send first or later transfer details
  typedef enum logic {
    e_ready
    ,e_send
  } state_e;
  state_e state_r, state_n;

  // Sequential logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

  // basic transaction indicator signals
  wire send = (v_o & send_i);
  wire send_first = send & first_o;
  wire send_last = send & last_o;

  // first_o tracking
  // register stores not(first_o)
  // register resets to 0, sets when sending first beat, clears when sending last
  // clear has priority over set to handle single beat transaction (first == last)
  logic firstn_r;
  bsg_dff_reset_set_clear
    #(.width_p(1)
      ,.clear_over_set_p(1)
      )
    firstn_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(send_first)
      ,.clear_i(send_last)
      ,.data_o(firstn_r)
      );
  assign first_o = ~firstn_r;

  // register for transaction properties
  // captured once per transaction in e_ready
  // has bypass that patches inputs to outputs when capturing
  logic [axi_addr_width_p-1:0] axaddr_r;
  logic [1:0] axburst_r;
  logic [7:0] axlen_r;
  logic [2:0] axsize_r;
  bsg_dff_reset_en_bypass
    #(.width_p(axi_addr_width_p+2+8+3))
    transaction_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(ready_and_o)
      ,.data_i({axsize_i, axlen_i, axburst_i, axaddr_i})
      ,.data_o({axsize_r, axlen_r, axburst_r, axaddr_r})
      );

  // transfer counter (max val is 255, per AXI spec where number of transfers = axlen+1)
  // clears to zero on reset and when sending last transfer
  // counts up every non-last send
  logic [7:0] count_r;
  bsg_counter_clear_up
    #(.max_val_p(255)
      ,.init_val_p(0)
      ,.disable_overflow_warning_p(1)
      )
    len_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(send_last)
      ,.up_i(send & ~last_o)
      ,.count_o(count_r)
      );

  // register for per-transfer address
  // captures axaddr_i when accepting new transaction that doesn't send
  // else captures address for next transfer
  logic [axi_addr_width_p-1:0] address_n, address_r;
  bsg_dff_reset_en
    #(.width_p(axi_addr_width_p))
    address_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(ready_and_o | send)
      ,.data_i(address_n)
      ,.data_o(address_r)
      );
  // in e_ready use input address else use registered address
  wire [axi_addr_width_p-1:0] address_li = ready_and_o ? axaddr_i : address_r;

  wire [6:0] number_bytes = (7'b1 << axsize_r);
  wire is_incr = (axburst_r == 2'b01);
  wire is_wrap = (axburst_r == 2'b10);
  wire [axi_addr_width_p-1:0] aligned_addr = (address_li >> axsize_r) << axsize_r;
  wire is_aligned = (aligned_addr == address_li);

  wire [8:0] burst_length = 9'(axburst_r) + 'b1;
  // WRAP mode requires computing wrap boundaries, but restricts axlen to 1, 3, 7, 15
  // this computation can be transformed to a simple lookup instead of a dynamic
  // log2 computation as we only care about it for the limited cases of WRAP mode
  logic [2:0] lg_burst_length;
  always_comb begin
    case (axlen_r)
      'd1: begin
        lg_burst_length = 3'd1;
      end
      'd3: begin
        lg_burst_length = 3'd2;
      end
      'd7: begin
        lg_burst_length = 3'd3;
      end
      'd15: begin
        lg_burst_length = 3'd4;
      end
      default: begin
        lg_burst_length = 3'd0;
      end
    endcase
  end

  // max dtsize = 128B * 16 bursts
  // dtsize = number_bytes * burst_length = burst_length << log2(number_bytes)
  // and log2(number_bytes) = axsize
  // equivalently, dtsize = 1 << lg_burst_length << axsize
  wire [12:0] dtsize = 13'(burst_length) << axsize_r;

  // compute lower_wrap_boundary and upper_wrap_boundary
  // lower_wrap_boundary = int(addr/dtsize) * dtsize
  // use the dtsize equivalence above to compute lower_wrap_boundary with only shifts
  wire [axi_addr_width_p-1:0] lower_wrap_boundary = (axaddr_r >> lg_burst_length >> axsize_r) << lg_burst_length << axsize_r;
  wire [axi_addr_width_p-1:0] upper_wrap_boundary = lower_wrap_boundary + axi_addr_width_p'(dtsize);

  wire [axi_addr_width_p-1:0] aligned_addr_incr = aligned_addr + axi_addr_width_p'(number_bytes);
  wire do_wrap = (aligned_addr_incr >= upper_wrap_boundary);

  // compute lower_byte_lane and upper_byte_lane and mask_o
  // data_bus_bytes == number of 8-bit byte lanes in the bus == axi_mask_width_lp
  // thus x * data_bus_bytes == x << log2(data_bus_bytes) == x << lg_axi_mask_width_lp
  // and x / data_bus_bytes == x >> log2(data_bus_bytes) == x >> lg_axi_mask_width_lp
  // let mask_address = (int(addr/data_bus_bytes) * data_bus_bytes)
  //                  = (addr >> lg_axi_mask_width_lp) << lg_axi_mask_width_lp
  // lower_byte_lane = addr - mask_address
  // upper_byte_lane = aligned ? lower_byte_lane + number_bytes - 1
  //                           : aligned address + number_bytes - 1 - mask_address
  wire [axi_addr_width_p-1:0] mask_address = ((address_li >> lg_axi_mask_width_lp) << lg_axi_mask_width_lp);
  logic [`BSG_SAFE_CLOG2(axi_mask_width_lp)-1:0] lower_byte_lane, upper_byte_lane;
  assign lower_byte_lane = address_li - mask_address;
  assign upper_byte_lane = is_aligned
                           ? lower_byte_lane + number_bytes - 'd1
                           : aligned_addr_incr - mask_address - 'd1;
  // mask = '1 << low bit & ~('1 << high bit)
  // high bit is one greater than the upper_byte_lane index (since its zero-based)
  assign mask_o = ({axi_mask_width_lp{1'b1}} << lower_byte_lane)
                  & ~({axi_mask_width_lp{1'b1}} << (upper_byte_lane+'d1));


  always_comb begin
    state_n = state_r;

    // accept transactions only in e_ready
    ready_and_o = (state_r == e_ready);

    // default outputs - assume single transfer transaction
    v_o = 1'b0;
    addr_o = axaddr_i;
    size_o = axsize_i;
    len_o = axlen_i;
    last_o = (axlen_i == 8'b0);

    // register control
    address_n = address_li;

    // state machine
    case (state_r)
      // ready for new transaction, capture inputs and attempt to send first transfer
      e_ready: begin
        state_n = (v_i & ~send_last) ? e_send : state_r;
        v_o = v_i;
        addr_o = axaddr_i;
        size_o = axsize_i;
        len_o = axlen_i;
        last_o = (axlen_i == 8'b0);

        if (send_i) begin
          // FIXED mode uses same address every transfer
          address_n = address_li;
          // INCR mode uses input address first transfer then aligned + number_bytes
          if (is_incr) begin
            address_n = aligned_addr_incr;
          end
          // WRAP is like INCR, but wraps to lower_wrap_boundary when passing upper_wrap_boundary
          // and start address is guaranteed to be aligned
          else if (is_wrap) begin
            address_n = do_wrap ? lower_wrap_boundary : aligned_addr_incr;
          end
        end else begin
          address_n = address_li;
        end
      end
      // providing addresses for every transfer in transaction
      e_send: begin
        v_o = 1'b1;
        addr_o = address_r;
        size_o = axsize_r;
        len_o = axlen_r;
        last_o = (axlen_r == count_r);

        state_n = (send_last) ? e_ready : state_r;

        // FIXED mode uses same address every transfer
        address_n = address_li;
        // INCR mode uses input address first transfer then aligned + number_bytes
        if (is_incr) begin
          address_n = aligned_addr_incr;
        end
        // WRAP is like INCR, but wraps to lower_wrap_boundary when passing upper_wrap_boundary
        // and start address is guaranteed to be aligned
        else if (is_wrap) begin
          address_n = do_wrap ? lower_wrap_boundary : aligned_addr_incr;
        end
      end
      default: begin
      end
    endcase
  end

endmodule

