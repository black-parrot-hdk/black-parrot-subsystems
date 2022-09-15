/*

Copyright (c) 2014-2021 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

`include "bsg_defines.v"

`default_nettype none

/*
 * AXI4-Stream asynchronous FIFO
 */
module axis_async_fifo #
(
    // FIFO depth in words
    // KEEP_WIDTH words per cycle if KEEP_ENABLE set
    // Rounded up to nearest power of 2 cycles
    parameter DEPTH = 4096,
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = ((DATA_WIDTH+7)/8),
    // Propagate tlast signal
    parameter LAST_ENABLE = 1,
    // Propagate tid signal
    parameter ID_ENABLE = 0,
    // tid signal width
    parameter ID_WIDTH = 8,
    // Propagate tdest signal
    parameter DEST_ENABLE = 0,
    // tdest signal width
    parameter DEST_WIDTH = 8,
    // Propagate tuser signal
    parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1,
    // number of output pipeline registers
    parameter PIPELINE_OUTPUT = 2,
    // Frame FIFO mode - operate on frames instead of cycles
    // When set, m_axis_tvalid will not be deasserted within a frame
    // Requires LAST_ENABLE set
    parameter FRAME_FIFO = 0,
    // tuser value for bad frame marker
    parameter USER_BAD_FRAME_VALUE = 1'b1,
    // tuser mask for bad frame marker
    parameter USER_BAD_FRAME_MASK = 1'b1,
    // Drop frames larger than FIFO
    // Requires FRAME_FIFO set
    parameter DROP_OVERSIZE_FRAME = FRAME_FIFO,
    // Drop frames marked bad
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_BAD_FRAME = 0,
    // Drop incoming frames when full
    // When set, s_axis_tready is always asserted
    // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    parameter DROP_WHEN_FULL = 0
    // put an async FIFO either on upstream or downstream
    parameter `BSG_INV_PARAM(upstream_not_downstream)
)
(
    /*
     * AXI input
     */
    input  wire                   s_clk,
    input  wire                   s_rst,
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    input  wire [ID_WIDTH-1:0]    s_axis_tid,
    input  wire [DEST_WIDTH-1:0]  s_axis_tdest,
    input  wire [USER_WIDTH-1:0]  s_axis_tuser,

    /*
     * AXI output
     */
    input  wire                   m_clk,
    input  wire                   m_rst,
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  m_axis_tkeep,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    output wire [ID_WIDTH-1:0]    m_axis_tid,
    output wire [DEST_WIDTH-1:0]  m_axis_tdest,
    output wire [USER_WIDTH-1:0]  m_axis_tuser,

    /*
     * Status
     */
    output wire                   s_status_overflow,
    output wire                   s_status_bad_frame,
    output wire                   s_status_good_frame,
    output wire                   m_status_overflow,
    output wire                   m_status_bad_frame,
    output wire                   m_status_good_frame

);

// synopsys translate_off
// check configuration
initial begin
    if (PIPELINE_OUTPUT < 1) begin
        $error("Error: PIPELINE_OUTPUT must be at least 1 (instance %m)");
        $finish;
    end

    if (FRAME_FIFO && !LAST_ENABLE) begin
        $error("Error: FRAME_FIFO set requires LAST_ENABLE set (instance %m)");
        $finish;
    end

    if (DROP_OVERSIZE_FRAME && !FRAME_FIFO) begin
        $error("Error: DROP_OVERSIZE_FRAME set requires FRAME_FIFO set (instance %m)");
        $finish;
    end

    if (DROP_BAD_FRAME && !(FRAME_FIFO && DROP_OVERSIZE_FRAME)) begin
        $error("Error: DROP_BAD_FRAME set requires FRAME_FIFO and DROP_OVERSIZE_FRAME set (instance %m)");
        $finish;
    end

    if (DROP_WHEN_FULL && !(FRAME_FIFO && DROP_OVERSIZE_FRAME)) begin
        $error("Error: DROP_WHEN_FULL set requires FRAME_FIFO and DROP_OVERSIZE_FRAME set (instance %m)");
        $finish;
    end

    if (DROP_BAD_FRAME && (USER_BAD_FRAME_MASK & {USER_WIDTH{1'b1}}) == 0) begin
        $error("Error: Invalid USER_BAD_FRAME_MASK value (instance %m)");
        $finish;
    end
end
initial begin
    if(FRAME_FIFO != 1) begin
        $error("Error: only support FRAME_FIFO == 1 (instance %m)");
        $finish;
    end
    if(LAST_ENABLE != 1) begin
        $error("Error: only support LAST_ENABLE == 1 (instance %m)");
        $finish;
    end
    if(DROP_OVERSIZE_FRAME != 1) begin
        $error("Error: only support DROP_OVERSIZE_FRAME == 1 (instance %m)");
        $finish;
    end
    if(DROP_BAD_FRAME != 1) begin
        $error("Error: only support DROP_BAD_FRAME == 1 (instance %m)");
        $finish;
    end
    if(DROP_WHEN_FULL != 0) begin
        $error("Error: only support DROP_WHEN_FULL == 0 (instance %m)");
        $finish;
    end
end
// synopsys translate_on

localparam KEEP_OFFSET = DATA_WIDTH;
localparam LAST_OFFSET = KEEP_OFFSET + (KEEP_ENABLE ? KEEP_WIDTH : 0);
localparam ID_OFFSET   = LAST_OFFSET + (LAST_ENABLE ? 1          : 0);
localparam DEST_OFFSET = ID_OFFSET   + (ID_ENABLE   ? ID_WIDTH   : 0);
localparam USER_OFFSET = DEST_OFFSET + (DEST_ENABLE ? DEST_WIDTH : 0);
localparam WIDTH       = USER_OFFSET + (USER_ENABLE ? USER_WIDTH : 0);

logic [WIDTH-1:0] store_and_forward_data_li;
logic [WIDTH-1:0] store_and_forward_data_lo;
logic             store_and_forward_yumi_li;
logic             store_and_forward_ready_li;
logic             store_and_forward_v_li;
logic             store_and_forward_last_li;
logic             store_and_forward_ready_lo;
logic             store_and_forward_v_lo;
logic             store_and_forward_last_lo;

//================== AXIS -> Rolly FIFO Interface ==================//

wire              rolly_fifo_in_v     = s_axis_tvalid;
logic [WIDTH-1:0] rolly_fifo_in_data;
wire              rolly_fifo_in_last  = s_axis_tlast;
wire              rolly_fifo_in_error =
        USER_BAD_FRAME_MASK & ~(s_axis_tuser ^ USER_BAD_FRAME_VALUE);
logic             rolly_fifo_in_ready;

assign                  rolly_fifo_in_data[DATA_WIDTH-1:0]            = s_axis_tdata;
if (KEEP_ENABLE) assign rolly_fifo_in_data[KEEP_OFFSET +: KEEP_WIDTH] = s_axis_tkeep;
if (LAST_ENABLE) assign rolly_fifo_in_data[LAST_OFFSET]               = s_axis_tlast;
if (ID_ENABLE)   assign rolly_fifo_in_data[ID_OFFSET   +: ID_WIDTH]   = s_axis_tid;
if (DEST_ENABLE) assign rolly_fifo_in_data[DEST_OFFSET +: DEST_WIDTH] = s_axis_tdest;
if (USER_ENABLE) assign rolly_fifo_in_data[USER_OFFSET +: USER_WIDTH] = s_axis_tuser;

assign            s_axis_tready = rolly_fifo_in_ready;
//==================================================================//

if (upstream_not_downstream == 0) begin: down
  assign store_and_forward_v_li     = rolly_fifo_in_v;
  assign store_and_forward_data_li  = rolly_fifo_in_data;
  assign store_and_forward_last_li  = rolly_fifo_in_last;
  assign store_and_forward_error_li = rolly_fifo_in_error;
  assign rolly_fifo_in_ready  = store_and_forward_ready_lo;
end else begin: up

  logic                  async_fifo_w_full_lo;
  wire                   async_fifo_w_enq_li = rolly_fifo_in_ready & rolly_fifo_in_v;
  // Store the data as well as the control signals (last, error)
  wire  [WIDTH+2-1:0]    async_fifo_w_data_li =
        {rolly_fifo_in_data, rolly_fifo_in_last, rolly_fifo_in_error};

  logic                  async_fifo_r_valid_lo;
  wire                   async_fifo_r_deq_li = store_and_forward_v_li & store_and_forward_ready_lo;
  logic [WIDTH+2-1:0]    async_fifo_r_data_lo;
  bsg_async_fifo #(
      .lg_size_p(3)
     ,.width_p(WIDTH+2)
  ) async_fifo (
      .w_clk_i(s_clk)
     ,.w_reset_i(s_rst)
     ,.w_enq_i(async_fifo_w_enq_li)
     ,.w_data_i(async_fifo_w_data_li)
     ,.w_full_o(async_fifo_w_full_lo)

     ,.r_clk_i(m_clk)
     ,.r_reset_i(m_rst)
     ,.r_deq_i(async_fifo_r_deq_li)
     ,.r_data_o(async_fifo_r_data_lo)
     ,.r_valid_o(async_fifo_r_valid_lo)
  );

  assign store_and_forward_v_li = async_fifo_r_valid_lo;
  assign {store_and_forward_data_li, store_and_forward_last_li, store_and_forward_error_li} =
          async_fifo_r_data_lo;
  assign rolly_fifo_in_ready = ~async_fifo_w_full_lo;
end

logic store_and_forward_clk_li;
logic store_and_forward_reset_li;
logic good_packet_lo;
logic overflow_packet_lo;
logic erroneous_packet_lo;

if (upstream_not_downstream == 0) begin: down
  assign store_and_forward_clk_li   = s_clk;
  assign store_and_forward_reset_li = s_rst;

  assign s_status_overflow = good_packet_lo;
  assign s_status_bad_frame = overflow_packet_lo;
  assign s_status_good_frame = erroneous_packet_lo;

  bsg_launch_sync_sync #(
      .width_p(3)
  ) status_synchronizer (
      .iclk_i(s_clk)
     ,.iclk_reset_i(s_rst)
     ,.oclk_i(m_clk)
     ,.iclk_data_i({s_status_overflow, s_status_bad_frame, s_status_good_frame})
     ,.iclk_data_o() // UNUSED
     ,.oclk_data_o({m_status_overflow, m_status_bad_frame, m_status_good_frame})
  );


end else begin: up
  assign store_and_forward_clk_li   = m_clk;
  assign store_and_forward_reset_li = m_rst;

  assign m_status_overflow = good_packet_lo;
  assign m_status_bad_frame = overflow_packet_lo;
  assign m_status_good_frame = erroneous_packet_lo;

  bsg_launch_sync_sync #(
      .width_p(3)
  ) status_synchronizer (
      .iclk_i(m_clk)
     ,.iclk_reset_i(m_rst)
     ,.oclk_i(s_clk)
     ,.iclk_data_i({m_status_overflow, m_status_bad_frame, m_status_good_frame})
     ,.iclk_data_o() // UNUSED
     ,.oclk_data_o({s_status_overflow, s_status_bad_frame, s_status_good_frame})
  );
end

bsg_fifo_1r1w_rolly #(
    .width_p(WIDTH)
   ,.els_p(DEPTH)
) store_and_forward (
    .clk_i(store_and_forward_clk_li)
   ,.reset_i(store_and_forward_reset_li)

   ,.clr_v_i(1'b0)
   ,.deq_v_i(store_and_forward_yumi_li)
   ,.roll_v_i(1'b0)

   ,.data_i(store_and_forward_data_li)
   ,.v_i(store_and_forward_v_li)
   ,.last_i(store_and_forward_last_li)
   ,.error_i(store_and_forward_error_li)
   ,.ready_o(store_and_forward_ready_lo)

   ,.data_o(store_and_forward_data_lo)
   ,.v_o(store_and_forward_v_lo)
   ,.last_o(store_and_forward_last_lo)
   ,.yumi_i(store_and_forward_yumi_li)

   ,.good_packet_o(good_packet_lo)
   ,.overflow_packet_o(overflow_packet_lo)
   ,.erroneous_packet_o(erroneous_packet_lo)
);

assign store_and_forward_yumi_li = store_and_forward_v_lo & store_and_forward_ready_li;

//================== Rolly FIFO Interface -> AXIS ==================//

logic             rolly_fifo_out_v;
logic [WIDTH-1:0] rolly_fifo_out_data;
logic             rolly_fifo_out_last;
logic             rolly_fifo_out_ready;

assign   m_axis_tdata = rolly_fifo_out_data[DATA_WIDTH-1:0];
if(KEEP_ENABLE)
  assign m_axis_tkeep = rolly_fifo_out_data[KEEP_OFFSET +: KEEP_WIDTH];
else
  assign m_axis_tkeep = {KEEP_WIDTH{1'b1}};
if(LAST_ENABLE)
  assign m_axis_tlast = rolly_fifo_out_data[LAST_OFFSET];
else
  assign m_axis_tlast = 1'b1;
if(ID_ENABLE)
  assign m_axis_tid   = rolly_fifo_out_data[ID_OFFSET +: ID_WIDTH];
else
  assign m_axis_tid   = {ID_WIDTH{1'b0}};
if(DEST_ENABLE)
  assign m_axis_tdest = rolly_fifo_out_data[DEST_OFFSET +: DEST_WIDTH];
else
  assign m_axis_tdest = {DEST_WIDTH{1'b0}};
if(USER_ENABLE)
  assign m_axis_tuser = rolly_fifo_out_data[USER_OFFSET +: USER_WIDTH];
else
  assign m_axis_tuser = {USER_WIDTH{1'b0}};

assign m_axis_tvalid  = rolly_fifo_out_v;
assign rolly_fifo_out_ready = m_axis_tready;
//==================================================================//
//

if(upstream_not_downstream == 0) begin: down

  wire                   async_fifo_w_enq_li  = store_and_forward_yumi_li;
  wire [WIDTH-1:0]       async_fifo_w_data_li = store_and_forward_data_lo;
  logic                  async_fifo_w_full_lo;
  logic                  async_fifo_r_deq_li;
  logic [WIDTH-1:0]      async_fifo_r_data_lo;
  logic                  async_fifo_r_valid_lo;
  assign store_and_forward_ready_li = ~async_fifo_w_full_lo;

  bsg_async_fifo #(
      .lg_size_p(3)
     ,.width_p(WIDTH)
  ) async_fifo (
      .w_clk_i(s_clk)
     ,.w_reset_i(s_rst)
     ,.w_enq_i(async_fifo_w_enq_li)
     ,.w_data_i(async_fifo_w_data_li)
     ,.w_full_o(async_fifo_w_full_lo)

     ,.r_clk_i(m_clk)
     ,.r_reset_i(m_rst)
     ,.r_deq_i(async_fifo_r_deq_li)
     ,.r_data_o(async_fifo_r_data_lo)
     ,.r_valid_o(async_fifo_r_valid_lo)
  );

  assign rolly_fifo_out_v = async_fifo_r_valid_lo;
  assign async_fifo_r_deq_li = rolly_fifo_out_ready & rolly_fifo_out_v;
  assign rolly_fifo_out_data = async_fifo_r_data_lo;
end else begin: up
  assign rolly_fifo_out_v = store_and_forward_v_lo;
  assign store_and_forward_ready_li = rolly_fifo_out_ready;
  assign rolly_fifo_out_data = store_and_forward_data_lo;
end

endmodule
