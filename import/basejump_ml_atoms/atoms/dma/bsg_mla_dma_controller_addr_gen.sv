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

module bsg_mla_dma_controller_addr_gen #( parameter addr_width_p   = 32
                                        , parameter stride_width_p = 8
                                        , parameter length_width_p = 16
                                        )
  ( input  logic                        clk_i
  , input  logic                        reset_i
  , input  logic                        en_i

  , input  logic                        clear_i
  , output logic                        first_o
  , output logic                        last_o
  , output logic                        done_o

  , input  logic [addr_width_p-1:0]     base_addr_r_i
  , input  logic [stride_width_p-1:0]   stride_r_i
  , input  logic [length_width_p-1:0]   length_r_i

  , output logic [addr_width_p-1:0]     addr_o
  , output logic                        v_o
  , input  logic                        yumi_i
  );

  logic [length_width_p-1:0] counter_n, counter_r;

  assign counter_n = counter_r + 1'b1;

  bsg_dff_reset_en #(.width_p(length_width_p))
    counter_reg
      (.clk_i(clk_i)
      ,.reset_i(reset_i | clear_i)
      ,.en_i(yumi_i)
      ,.data_i(counter_n)
      ,.data_o(counter_r)
      );

  assign first_o = (counter_r == '0);
  assign last_o  = (counter_n == length_r_i);
  assign done_o  = (counter_r == length_r_i);

  assign addr_o = base_addr_r_i + (addr_width_p'(counter_r) << stride_r_i);
  assign v_o    = en_i & ~done_o;

endmodule // bsg_mla_dma_controller_addr_gen
