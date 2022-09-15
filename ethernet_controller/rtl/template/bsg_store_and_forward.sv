/*

Copyright (c) 2013-2021 Alex Forencich

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


`include "bsg_defines.v"

`default_nettype none

module bsg_store_and_forward #(
    parameter  `BSG_INV_PARAM(lg_size_p)
  , parameter  `BSG_INV_PARAM(width_p)
)
(
    input                       clk_i
  , input                       reset_i

  , input [width_p-1:0]         data_i
  , input                       v_i
  , input                       last_i
  // error_i: only assert when last_i is high
  , input                       error_i
  , output logic                ready_and_o

  , output logic [width_p-1:0]  data_o
  , output logic                v_o
  , output logic                last_o
  , input                       ready_and_i
);


logic [lg_size_p+1-1:0] wr_ptr_r, wr_ptr_n;
logic [lg_size_p+1-1:0] wr_ptr_cur_r, wr_ptr_cur_n;
logic [lg_size_p+1-1:0] rd_ptr_r, rd_ptr_n;

bsg_dff_reset #(
    .width_p(lg_size_p + 1)
) wr_ptr_reg (
    .clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(wr_ptr_n)
   ,.data_o(wr_ptr_r)
);

bsg_dff_reset #(
    .width_p(lg_size_p + 1)
) wr_ptr_cur_reg (
    .clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(wr_ptr_cur_n)
   ,.data_o(wr_ptr_cur_r)
);

bsg_dff_reset #(
    .width_p(lg_size_p + 1)
) rd_ptr_reg (
    .clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(rd_ptr_n)
   ,.data_o(rd_ptr_r)
);

// full when all but the first MSB are the same
wire full_cur = (wr_ptr_cur_r == (rd_ptr_r ^ {1'b1, {lg_size_p{1'b0}}}));
// overflow within packet
wire full_wr = (wr_ptr_r == (wr_ptr_cur_r ^ {1'b1, {lg_size_p{1'b0}}}));
wire empty = (wr_ptr_r == rd_ptr_r);

logic                 mem_w_v_li;
wire  [lg_size_p-1:0] mem_w_addr_li = wr_ptr_cur_reg[lg_size_p-1:0];
wire  [width_p+1-1:0] mem_w_data_li = {data_i, last_i};
logic                 mem_r_v_li;
wire  [lg_size_p-1:0] mem_r_addr_li = rd_ptr_r;
logic [width_p+1-1:0] mem_r_data_lo;

logic                 mem_r_data_fifo_ready_lo;
logic [width_p+1-1:0] mem_r_data_fifo_data_li;
logic                 mem_r_data_fifo_v_li;

bsg_mem_1r1w_sync #(
    .width_p(width_p+1)
   ,.els_p((1 << lg_size_p))
) mem (
    .clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.w_v_i(mem_w_v_li)
   ,.w_addr_i(mem_w_addr_li)
   ,.w_data_i(mem_w_data_li)
   ,.r_v_i(mem_r_v_li)
   ,.r_addr_i(mem_r_addr_li)
   ,.r_data_o(mem_r_data_lo)
);

logic mem_r_v_r;
bsg_dff_reset #(
    .width_p(1)
) read_en_dff (
    .clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(mem_r_v_li)
   ,.data_o(mem_r_v_r)
);

bsg_dff_en_bypass #(
    .width_p(width_p+1)
) dff_bypass (
    .clk_i(clk_i)
   ,.en_i(mem_r_v_r)
   ,.data_i(mem_r_data_lo)
   ,.data_o(mem_r_data_fifo_data_li)
);
/*
wire                  mem_r_v_li;
wire  [lg_size_p-1:0] mem_r_addr_li = rd_ptr_r;
logic [width_p-1:0]   mem_r_data_lo;
*/

logic mem_r_data_valid_r;
logic mem_r_data_valid_set_li;
assign mem_r_v_li = mem_r_data_valid_set_li;
assign rd_ptr_n = mem_r_v_li ? rd_ptr_r + 1 : rd_ptr_r;
/** Stage 1 **/
// ready when one of the stages is available
assign mem_r_data_valid_set_li = ~empty & (~mem_r_data_valid_r | mem_r_data_fifo_ready_lo);
wire mem_r_data_clear_li = mem_r_data_fifo_v_li & mem_r_data_fifo_ready_lo;
bsg_dff_reset_set_clear #(
    .width_p(1)
   ,.clear_over_set_p(0)
) mem_r_data_valid_reg (
    .clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.set_i(mem_r_data_valid_set_li)
   ,.clear_i(mem_r_data_clear_li)
   ,.data_o(mem_r_data_valid_r)
);

/** Stage 2 **/
assign mem_r_data_fifo_v_li = mem_r_data_valid_r;
logic [width_p+1-1:0] mem_r_data_fifo_data_lo;
bsg_fifo_1r1w_small #(
    .width_p(width_p+1)
   ,.els_p(2)
) mem_r_data_fifo (
    .clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.v_i(mem_r_data_fifo_v_li)
   ,.ready_o(mem_r_data_fifo_ready_lo)
   ,.data_i(mem_r_data_fifo_data_li)

   ,.v_o(v_o)
   ,.data_o(mem_r_data_fifo_data_lo)
   ,.yumi_i(v_o & ready_and_i)
);

assign {data_o, last_o} = mem_r_data_fifo_data_lo;

assign ready_and_o = (!full_cur || full_wr);

// Write logic
always_comb begin
    wr_ptr_cur_n = wr_ptr_cur_r;
    wr_ptr_n = wr_ptr_r;
    mem_w_v_li = 1'b0;
    if (ready_and_o && v_i) begin
        // transfer in
        if (full_wr) begin
            // packet overflow: drop frame
            if (last_i) begin
                // end of frame, reset write pointer
                wr_ptr_cur_n = wr_ptr_r;
//                overflow_reg <= 1'b1;
            end
        end else begin
            // store it
            mem_w_v_li = 1'b1;
//            mem[wr_ptr_cur_reg[ADDR_WIDTH-1:0]] <= s_axis;
            wr_ptr_cur_n = wr_ptr_cur_r + 1;
            if (last_i) begin
                // end of frame
                if (last_i && error_i) begin
                    // bad packet: reset write pointer
                    wr_ptr_cur_n = wr_ptr_r;
//                    bad_frame_reg <= 1'b1;
                end else begin
                    // good packet: update write pointer
                    wr_ptr_n = wr_ptr_cur_r + 1;
//                    good_frame_reg <= s_axis_tlast;
                end
            end
        end
    end
/*
    if (rst) begin
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_cur_reg <= {ADDR_WIDTH+1{1'b0}};

        overflow_reg <= 1'b0;
        bad_frame_reg <= 1'b0;
        good_frame_reg <= 1'b0;
    end
*/
end


endmodule

