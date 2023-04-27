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
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
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
    parameter DROP_WHEN_FULL = 0,
    // If 1, put a bsg_async_fifo at input side
    // If 0, put a bsg_async_fifo at output side
    parameter upstream_async_fifo_p
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

localparam KEEP_OFFSET = DATA_WIDTH;
localparam LAST_OFFSET = KEEP_OFFSET + (KEEP_ENABLE ? KEEP_WIDTH : 0);
localparam ID_OFFSET   = LAST_OFFSET + (LAST_ENABLE ? 1          : 0);
localparam DEST_OFFSET = ID_OFFSET   + (ID_ENABLE   ? ID_WIDTH   : 0);
localparam USER_OFFSET = DEST_OFFSET + (DEST_ENABLE ? DEST_WIDTH : 0);
localparam WIDTH       = USER_OFFSET + (USER_ENABLE ? USER_WIDTH : 0);

// axis_fifo
logic fifo_clk;
logic fifo_rst;
logic [DATA_WIDTH-1:0] fifo_m_axis_tdata;
logic [KEEP_WIDTH-1:0] fifo_m_axis_tkeep;
logic                  fifo_m_axis_tvalid;
logic                  fifo_m_axis_tready;
logic                  fifo_m_axis_tlast;
logic [ID_WIDTH-1:0]   fifo_m_axis_tid;
logic [DEST_WIDTH-1:0] fifo_m_axis_tdest;
logic [USER_WIDTH-1:0] fifo_m_axis_tuser;

logic [DATA_WIDTH-1:0] fifo_s_axis_tdata;
logic [KEEP_WIDTH-1:0] fifo_s_axis_tkeep;
logic                  fifo_s_axis_tvalid;
logic                  fifo_s_axis_tready;
logic                  fifo_s_axis_tlast;
logic [ID_WIDTH-1:0]   fifo_s_axis_tid;
logic [DEST_WIDTH-1:0] fifo_s_axis_tdest;
logic [USER_WIDTH-1:0] fifo_s_axis_tuser;

// Status
logic fifo_status_overflow;
logic fifo_status_bad_frame;
logic fifo_status_good_frame;
logic fifo_status_overflow_synced;
logic fifo_status_bad_frame_synced;
logic fifo_status_good_frame_synced;

// bsg_async_fifo
logic             w_enq_li;
logic [WIDTH-1:0] w_data_li;
logic             w_full_lo;
logic             r_deq_li;
logic [WIDTH-1:0] r_data_lo;
logic             r_valid_lo;

// bsg_launch_sync_sync
logic iclk_li;
logic iclk_reset_li;
logic oclk_li;
logic oclk_reset_li;

if(upstream_async_fifo_p) begin: up

  // fifo clock, reset
  assign fifo_clk = m_clk;
  assign fifo_rst = m_rst;
  // bsg_launch_sync_sync clock, reset
  assign iclk_li = m_clk;
  assign iclk_reset_li = m_rst;
  assign oclk_li = s_clk;
  assign oclk_reset_li = s_rst;

  // AXIS input -> bsg_async_fifo
  assign                  w_data_li[DATA_WIDTH-1:0]            = s_axis_tdata;
  if (KEEP_ENABLE) assign w_data_li[KEEP_OFFSET +: KEEP_WIDTH] = s_axis_tkeep;
  if (LAST_ENABLE) assign w_data_li[LAST_OFFSET]               = s_axis_tlast;
  if (ID_ENABLE)   assign w_data_li[ID_OFFSET   +: ID_WIDTH]   = s_axis_tid;
  if (DEST_ENABLE) assign w_data_li[DEST_OFFSET +: DEST_WIDTH] = s_axis_tdest;
  if (USER_ENABLE) assign w_data_li[USER_OFFSET +: USER_WIDTH] = s_axis_tuser;

  assign w_enq_li = s_axis_tvalid & s_axis_tready;
  assign s_axis_tready = ~w_full_lo;

  // bsg_async_fifo -> axis_fifo
  assign fifo_s_axis_tvalid = r_valid_lo;
  assign r_deq_li = fifo_s_axis_tvalid & fifo_s_axis_tready;

  assign   fifo_s_axis_tdata  = r_data_lo[DATA_WIDTH-1:0];
  if(KEEP_ENABLE)
    assign fifo_s_axis_tkeep = r_data_lo[KEEP_OFFSET +: KEEP_WIDTH];
  else
    assign fifo_s_axis_tkeep = {KEEP_WIDTH{1'b1}};
  if(LAST_ENABLE)
    assign fifo_s_axis_tlast = r_data_lo[LAST_OFFSET];
  else
    assign fifo_s_axis_tlast = 1'b1;
  if(ID_ENABLE)
    assign fifo_s_axis_tid = r_data_lo[ID_OFFSET +: ID_WIDTH];
  else
    assign fifo_s_axis_tid = {ID_WIDTH{1'b0}};
  if(DEST_ENABLE)
    assign fifo_s_axis_tdest = r_data_lo[DEST_OFFSET +: DEST_WIDTH];
  else
    assign fifo_s_axis_tdest = {DEST_WIDTH{1'b0}};
  if(USER_ENABLE)
    assign fifo_s_axis_tuser = r_data_lo[USER_OFFSET +: USER_WIDTH];
  else
    assign fifo_s_axis_tuser = {USER_WIDTH{1'b0}};

  // axis_fifo -> AXIS output
  assign m_axis_tdata  = fifo_m_axis_tdata;
  assign m_axis_tkeep  = fifo_m_axis_tkeep;
  assign m_axis_tvalid = fifo_m_axis_tvalid;
  assign m_axis_tlast  = fifo_m_axis_tlast;
  assign m_axis_tid    = fifo_m_axis_tid;
  assign m_axis_tdest  = fifo_m_axis_tdest;
  assign m_axis_tuser  = fifo_m_axis_tuser;
  assign fifo_m_axis_tready = m_axis_tready;
  // Status
  assign s_status_overflow   = fifo_status_overflow_synced;
  assign s_status_bad_frame  = fifo_status_bad_frame_synced;
  assign s_status_good_frame = fifo_status_good_frame_synced;
  assign m_status_overflow   = fifo_status_overflow;
  assign m_status_bad_frame  = fifo_status_bad_frame;
  assign m_status_good_frame = fifo_status_good_frame;

end else begin: down

  // fifo clock, reset
  assign fifo_clk = s_clk;
  assign fifo_rst = s_rst;
  // bsg_launch_sync_sync clock, reset
  assign iclk_li = s_clk;
  assign iclk_reset_li = s_rst;
  assign oclk_li = m_clk;
  assign oclk_reset_li = m_rst;

  // AXIS input -> axis_fifo

  assign fifo_s_axis_tdata  = s_axis_tdata;
  assign fifo_s_axis_tkeep  = s_axis_tkeep;
  assign fifo_s_axis_tvalid = s_axis_tvalid;
  assign fifo_s_axis_tlast  = s_axis_tlast;
  assign fifo_s_axis_tid    = s_axis_tid;
  assign fifo_s_axis_tdest  = s_axis_tdest;
  assign fifo_s_axis_tuser  = s_axis_tuser;
  assign s_axis_tready = fifo_s_axis_tready;

  // axis_fifo -> bsg_async_fifo

  assign                  w_data_li[DATA_WIDTH-1:0]            = fifo_m_axis_tdata;
  if (KEEP_ENABLE) assign w_data_li[KEEP_OFFSET +: KEEP_WIDTH] = fifo_m_axis_tkeep;
  if (LAST_ENABLE) assign w_data_li[LAST_OFFSET]               = fifo_m_axis_tlast;
  if (ID_ENABLE)   assign w_data_li[ID_OFFSET   +: ID_WIDTH]   = fifo_m_axis_tid;
  if (DEST_ENABLE) assign w_data_li[DEST_OFFSET +: DEST_WIDTH] = fifo_m_axis_tdest;
  if (USER_ENABLE) assign w_data_li[USER_OFFSET +: USER_WIDTH] = fifo_m_axis_tuser;
  assign w_enq_li = fifo_m_axis_tvalid & fifo_m_axis_tready;
  assign fifo_m_axis_tready = ~w_full_lo;

  // bsg_async_fifo -> AXIS output
  assign r_deq_li = m_axis_tvalid & m_axis_tready;
  assign m_axis_tvalid = r_valid_lo;

  assign     m_axis_tdata = r_data_lo[DATA_WIDTH-1:0];
  if(KEEP_ENABLE)
    assign m_axis_tkeep = r_data_lo[KEEP_OFFSET +: KEEP_WIDTH];
  else
    assign m_axis_tkeep = {KEEP_WIDTH{1'b1}};
  if(LAST_ENABLE)
    assign m_axis_tlast = r_data_lo[LAST_OFFSET];
  else
    assign m_axis_tlast = 1'b1;
  if(ID_ENABLE)
    assign m_axis_tid   = r_data_lo[ID_OFFSET +: ID_WIDTH];
  else
    assign m_axis_tid   = {ID_WIDTH{1'b0}};
  if(DEST_ENABLE)
    assign m_axis_tdest = r_data_lo[DEST_OFFSET +: DEST_WIDTH];
  else
    assign m_axis_tdest = {DEST_WIDTH{1'b0}};
  if(USER_ENABLE)
    assign m_axis_tuser = r_data_lo[USER_OFFSET +: USER_WIDTH];
  else
    assign m_axis_tuser = {USER_WIDTH{1'b0}};

  // Status
  assign s_status_overflow   = fifo_status_overflow;
  assign s_status_bad_frame  = fifo_status_bad_frame;
  assign s_status_good_frame = fifo_status_good_frame;
  assign m_status_overflow   = fifo_status_overflow_synced;
  assign m_status_bad_frame  = fifo_status_bad_frame_synced;
  assign m_status_good_frame = fifo_status_good_frame_synced;

end

bsg_async_fifo #(
   .lg_size_p(3)
  ,.width_p(WIDTH)
) cdc (
   .w_clk_i(s_clk)
  ,.w_reset_i(s_rst)
  ,.w_enq_i(w_enq_li)
  ,.w_data_i(w_data_li)
  ,.w_full_o(w_full_lo)
  ,.r_clk_i(m_clk)
  ,.r_reset_i(m_rst)
  ,.r_deq_i(r_deq_li)
  ,.r_data_o(r_data_lo)
  ,.r_valid_o(r_valid_lo)
);

axis_fifo #(
   .DEPTH(DEPTH)
  ,.DATA_WIDTH(DATA_WIDTH)
  ,.KEEP_ENABLE(KEEP_ENABLE)
  ,.KEEP_WIDTH(KEEP_WIDTH)
  ,.LAST_ENABLE(LAST_ENABLE)
  ,.ID_ENABLE(ID_ENABLE)
  ,.ID_WIDTH(ID_WIDTH)
  ,.DEST_ENABLE(DEST_ENABLE)
  ,.DEST_WIDTH(DEST_WIDTH)
  ,.USER_ENABLE(USER_ENABLE)
  ,.USER_WIDTH(USER_WIDTH)
  ,.PIPELINE_OUTPUT(PIPELINE_OUTPUT)
  ,.FRAME_FIFO(FRAME_FIFO)
  ,.USER_BAD_FRAME_VALUE(USER_BAD_FRAME_VALUE)
  ,.USER_BAD_FRAME_MASK(USER_BAD_FRAME_MASK)
  ,.DROP_OVERSIZE_FRAME(DROP_OVERSIZE_FRAME)
  ,.DROP_BAD_FRAME(DROP_BAD_FRAME)
  ,.DROP_WHEN_FULL(DROP_WHEN_FULL)
) fifo (
   .clk(fifo_clk)
  ,.rst(fifo_rst)

  ,.s_axis_tdata (fifo_s_axis_tdata)
  ,.s_axis_tkeep (fifo_s_axis_tkeep)
  ,.s_axis_tvalid(fifo_s_axis_tvalid)
  ,.s_axis_tready(fifo_s_axis_tready)
  ,.s_axis_tlast (fifo_s_axis_tlast)
  ,.s_axis_tid   (fifo_s_axis_tid)
  ,.s_axis_tdest (fifo_s_axis_tdest)
  ,.s_axis_tuser (fifo_s_axis_tuser)

  ,.m_axis_tdata (fifo_m_axis_tdata)
  ,.m_axis_tkeep (fifo_m_axis_tkeep)
  ,.m_axis_tvalid(fifo_m_axis_tvalid)
  ,.m_axis_tready(fifo_m_axis_tready)
  ,.m_axis_tlast (fifo_m_axis_tlast)
  ,.m_axis_tid   (fifo_m_axis_tid)
  ,.m_axis_tdest (fifo_m_axis_tdest)
  ,.m_axis_tuser (fifo_m_axis_tuser)

  ,.status_overflow  (fifo_status_overflow)
  ,.status_bad_frame (fifo_status_bad_frame)
  ,.status_good_frame(fifo_status_good_frame)
);
logic overflow_sync1_reg, overflow_sync3_reg, overflow_sync4_reg;
logic bad_frame_sync1_reg, bad_frame_sync3_reg, bad_frame_sync4_reg;
logic good_frame_sync1_reg, good_frame_sync3_reg, good_frame_sync4_reg;

wire  overflow_sync1_next   = overflow_sync1_reg   ^ fifo_status_overflow;
wire  bad_frame_sync1_next  = bad_frame_sync1_reg  ^ fifo_status_bad_frame;
wire  good_frame_sync1_next = good_frame_sync1_reg ^ fifo_status_good_frame;

assign fifo_status_overflow_synced   = overflow_sync3_reg ^ overflow_sync4_reg;
assign fifo_status_bad_frame_synced  = bad_frame_sync3_reg ^ bad_frame_sync4_reg;
assign fifo_status_good_frame_synced = good_frame_sync3_reg ^ good_frame_sync4_reg;

bsg_dff_reset #(
   .width_p(3)
) status (
   .clk_i(oclk_li)
  ,.reset_i(oclk_reset_li)
  ,.data_i({overflow_sync3_reg, bad_frame_sync3_reg, good_frame_sync3_reg})
  ,.data_o({overflow_sync4_reg, bad_frame_sync4_reg, good_frame_sync4_reg})
);

bsg_launch_sync_sync #(
  .width_p(3),
  .use_negedge_for_launch_p(0),
  .use_async_reset_p(0)
) status_synchronizer (
  .iclk_i(iclk_li),
  .iclk_reset_i(iclk_reset_li),
  .oclk_i(oclk_li),
  .iclk_data_i({overflow_sync1_next, bad_frame_sync1_next, good_frame_sync1_next}),
  .iclk_data_o({overflow_sync1_reg, bad_frame_sync1_reg, good_frame_sync1_reg}),
  .oclk_data_o({overflow_sync3_reg, bad_frame_sync3_reg, good_frame_sync3_reg})
);

endmodule
