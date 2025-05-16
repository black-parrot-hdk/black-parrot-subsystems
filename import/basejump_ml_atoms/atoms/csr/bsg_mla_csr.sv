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
// 3. Redistributions in binary form must reproduce the above copyright notice,
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

module bsg_mla_csr #( parameter core_width_p = -1
                    , parameter mem_width_p  = core_width_p
                    )
  ( input  logic                    clk_i
  , input  logic                    reset_i

  , input  logic [mem_width_p-1:0]  mem_data_i
  , input  logic                    mem_wen_i
  , output logic [mem_width_p-1:0]  mem_data_o

  , input  logic [core_width_p-1:0] core_data_i
  , input  logic                    core_wen_i
  , output logic [core_width_p-1:0] core_data_o
  );

  bsg_dff_reset_en #(.width_p(core_width_p))
    dff
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(mem_wen_i | core_wen_i)
      ,.data_i(mem_wen_i ? mem_data_i[0+:core_width_p] : core_data_i)
      ,.data_o(core_data_o)
      );

  assign mem_data_o = { {mem_width_p-core_width_p {1'b0}} , core_data_o };

endmodule // bsg_mla_csr
