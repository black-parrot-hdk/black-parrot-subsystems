// BSD 3-Clause License
//
// Copyright (c) 2023, Bespoke Silicon Group
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
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

module bsg_mla_valid_yumi_1_to_n #( parameter out_ch_p = -1
                                  )
  ( input  logic                clk_i
  , input  logic                reset_i

  , input  logic                v_i
  , output logic                yumi_o

  , output logic [out_ch_p-1:0] v_o
  , input  logic [out_ch_p-1:0] yumi_i
  );

  logic [out_ch_p-1:0] yumi_r;
  wire  [out_ch_p-1:0] yumi_n = (yumi_r | yumi_i) & {out_ch_p{v_i}};

  bsg_dff_reset #(.width_p(out_ch_p))
    yumi_reg
      (.clk_i(clk_i)
      ,.reset_i(reset_i | yumi_o)
      ,.data_i(yumi_n)
      ,.data_o(yumi_r)
      );

  assign v_o = (~yumi_r) & {out_ch_p{v_i}};
  assign yumi_o = &yumi_n;

endmodule // bsg_mla_valid_yumi_1_to_n
