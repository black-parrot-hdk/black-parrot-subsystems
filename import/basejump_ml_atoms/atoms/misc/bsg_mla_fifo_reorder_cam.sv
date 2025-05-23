// BSD 3-Clause License
//
// Copyright (c) 2023, Bespoke Silicon Group
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

`include "bsg_mla_defines.svh"

module bsg_mla_fifo_reorder_cam #( parameter width_p = -1
                                 , parameter addr_width_p = -1
                                 , parameter els_p = -1

                                 , localparam id_width_lp = `BSG_SAFE_CLOG2(els_p)
                                 )
  ( input  logic                    clk_i
  , input  logic                    reset_i

  , input  logic [addr_width_p-1:0] alloc_addr_i
  , output logic                    alloc_v_o
  , input  logic                    alloc_yumi_i

  , input  logic [addr_width_p-1:0] addr_i
  , input  logic [width_p-1:0]      data_i
  , input  logic                    v_i

  , output logic [width_p-1:0]      data_o
  , output logic                    v_o
  , input  logic                    yumi_i
  );

  logic [els_p-1:0] cam_w_en_n, cam_w_en_r;
  logic [id_width_lp-1:0] fifo_alloc_id_lo, cam_id_lo;

  assign cam_w_en_n = {cam_w_en_r[els_p-2:0], cam_w_en_r[els_p-1]};   // rotate left

  bsg_dff_reset_en #(.width_p(els_p)
                    ,.reset_val_p(1))
    cam_w_en_reg
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(alloc_yumi_i)
      ,.data_i(cam_w_en_n)
      ,.data_o(cam_w_en_r)
      );

  bsg_cam_1r1w_unmanaged #(.els_p(els_p)
                          ,.tag_width_p(addr_width_p)
                          ,.data_width_p(id_width_lp))
    cam
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.w_tag_i(alloc_addr_i)
      ,.w_data_i(fifo_alloc_id_lo)
      ,.w_v_i(cam_w_en_r & {els_p{alloc_yumi_i}})
      ,.w_set_not_clear_i(1'b1)
      ,.w_empty_o()

      ,.r_v_i(v_i)
      ,.r_tag_i(addr_i)
      ,.r_data_o(cam_id_lo)
      ,.r_v_o()
      );

  bsg_fifo_reorder #(.width_p(width_p)
                    ,.els_p(els_p))
    reorder_fifo
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.fifo_alloc_id_o(fifo_alloc_id_lo)
      ,.fifo_alloc_v_o(alloc_v_o)
      ,.fifo_alloc_yumi_i(alloc_yumi_i)

      ,.write_id_i(cam_id_lo)
      ,.write_data_i(data_i)
      ,.write_v_i(v_i)

      ,.fifo_deq_data_o(data_o)
      ,.fifo_deq_id_o()
      ,.fifo_deq_v_o(v_o)
      ,.fifo_deq_yumi_i(yumi_i)

      ,.empty_o()
      );

endmodule // bsg_mla_fifo_reorder_cam
