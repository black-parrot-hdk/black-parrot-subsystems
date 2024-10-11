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

module bsg_mla_fifo_1r1w_small_alloc #( parameter width_p = -1
                                      , parameter els_p = -1

                                      , localparam els_width_lp = `BSG_WIDTH(els_p)
                                      )
  ( input  logic                clk_i
  , input  logic                reset_i

  , output logic                alloc_v_o
  , input  logic                alloc_yumi_i

  , input  logic [width_p-1:0]  data_i
  , input  logic                v_i

  , output logic [width_p-1:0]  data_o
  , output logic                v_o
  , input  logic                yumi_i

  , output logic                empty_o
  );

  logic [els_width_lp-1:0] credits_r;

  assign alloc_v_o = |credits_r;
  assign empty_o = (credits_r == els_p);

  bsg_counter_up_down #(.max_val_p(els_p)
                       ,.init_val_p(els_p)
                       ,.max_step_p(1))
    credit_counter
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.up_i(yumi_i)
      ,.down_i(alloc_yumi_i)

      ,.count_o(credits_r)
      );

  bsg_fifo_1r1w_small #(.width_p(width_p)
                       ,.els_p(els_p))
    fifo
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.data_i(data_i)
      ,.v_i(v_i)
      ,.ready_param_o(/* unused */)

      ,.data_o(data_o)
      ,.v_o(v_o)
      ,.yumi_i(yumi_i)
      );

endmodule // bsg_mla_fifo_1r1w_small_alloc
