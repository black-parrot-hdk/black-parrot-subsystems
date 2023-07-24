/*
 * Name:
 *   bp_me_axi_pump.sv
 *
 * Description:
 *   This module implements AXI transaction counting per the spec (IHI0022H_c A3.4.1)
 *   In cycle 0, the transaction details are captured.
 *   In cycle 1+, each transfer can occur
 *
 */

`include "bsg_defines.v"

module bp_me_axi_pump
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

  wire accept = (v_i & ready_and_o);
  wire send = (v_o & send_i);
  wire send_last = send & last_o;

  // register for transaction properties and given address
  logic [axi_addr_width_p-1:0] axaddr;
  logic [1:0] axburst;
  logic [7:0] axlen;
  logic [2:0] axsize;
  bsg_dff_reset_en
    #(.width_p(axi_addr_width_p+2+8+3))
    input_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(accept)
      ,.data_i({axsize_i, axlen_i, axburst_i, axaddr_i})
      ,.data_o({axsize, axlen, axburst, axaddr})
      );

  // transfer counter (max val is 255, per AXI spec where number of transfers = axlen+1)
  // clears to zero when capturing a new transaction
  // counts up every send
  logic [7:0] count_r;
  bsg_counter_clear_up
    #(.max_val_p(255)
      ,.init_val_p(0)
      ,.disable_overflow_warning_p(1)
      )
    len_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(accept)
      ,.up_i(send)
      ,.count_o(count_r)
      );

  // register for per-transfer address
  // captures axaddr_i when accepting new transaction
  // and then holds correct address for every transfer
  logic address_en;
  logic [axi_addr_width_p-1:0] address_n, address_r;
  bsg_dff_reset_en
    #(.width_p(axi_addr_width_p))
    address_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(address_en)
      ,.data_i(address_n)
      ,.data_o(address_r)
      );

  wire [6:0] number_bytes = (7'b1 << axsize);
  wire is_incr = (axburst == 2'b01);
  wire is_wrap = (axburst == 2'b10);
  wire [axi_addr_width_p-1:0] aligned_addr = (address_r >> axsize) << axsize;
  wire is_aligned = (aligned_addr == address_r);

  wire [8:0] burst_length = axburst + 9'b1;
  // WRAP mode requires computing wrap boundaries, but restricts axlen to 1, 3, 7, 15
  // this computation can be transformed to a simple lookup instead of a dynamic
  // log2 computation as we only care about it for the limited cases of WRAP mode
  logic [2:0] lg_burst_length;
  always_comb begin
    case (axlen)
      'd1: begin
        lg_burst_length = 'd1;
      end
      'd3: begin
        lg_burst_length = 'd2;
      end
      'd7: begin
        lg_burst_length = 'd3;
      end
      'd15: begin
        lg_burst_length = 'd4;
      end
      default: begin
        lg_burst_length = 'd0;
      end
    endcase
  end

  // max dtsize = 128B * 16 bursts
  // dtsize = number_bytes * burst_length = burst_length << log2(number_bytes)
  // and log2(number_bytes) = axsize
  // equivalently, dtsize = 1 << lg_burst_length << axsize
  wire [12:0] dtsize = burst_length << axsize;

  // compute lower_wrap_boundary and upper_wrap_boundary
  // lower_wrap_boundary = int(addr/dtsize) * dtsize
  // use the dtsize equivalence above to compute lower_wrap_boundary with only shifts
  wire [axi_addr_width_p-1:0] lower_wrap_boundary = (axaddr >> lg_burst_length >> axsize) << lg_burst_length << axsize;
  wire [axi_addr_width_p-1:0] upper_wrap_boundary = lower_wrap_boundary + dtsize;

  wire [axi_addr_width_p-1:0] aligned_addr_incr = aligned_addr + number_bytes;
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
  wire [axi_addr_width_p-1:0] mask_address = ((address_r >> lg_axi_mask_width_lp) << lg_axi_mask_width_lp);
  logic [`BSG_SAFE_CLOG2(axi_mask_width_lp)-1:0] lower_byte_lane, upper_byte_lane;
  assign lower_byte_lane = address_r - mask_address;
  assign upper_byte_lane = is_aligned
                           ? lower_byte_lane + number_bytes - 'd1
                           : aligned_addr_incr - mask_address - 'd1;
  // mask = '1 << low bit & ~('1 << high bit)
  // high bit is one greater than the upper_byte_lane index (since its zero-based)
  assign mask_o = ({axi_mask_width_lp{1'b1}} << lower_byte_lane)
                  & ~({axi_mask_width_lp{1'b1}} << (upper_byte_lane+'d1));


  typedef enum logic {
    e_ready
    ,e_send
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
    // input
    ready_and_o = 1'b0;
    // output
    addr_o = address_r;
    v_o = 1'b0;
    first_o = (count_r == '0);
    last_o = (axlen == count_r);
    size_o = axsize;
    len_o = axlen;
    // register control
    address_en = 1'b0;
    address_n = '0;
    // state machine
    case (state_r)
      // ready for new transaction, capture inputs
      e_ready: begin
        ready_and_o = 1'b1;
        state_n = accept ? e_send : state_r;
        address_en = accept;
        address_n = axaddr_i;
      end
      // providing addresses for every transfer in transaction
      e_send: begin
        v_o = 1'b1;
        state_n = (send_last) ? e_ready : state_r;
        address_en = send;

        // FIXED mode uses same address every transfer
        address_n = address_r;
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

