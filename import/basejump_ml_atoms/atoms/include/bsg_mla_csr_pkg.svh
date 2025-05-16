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

`ifndef __BSG_MLA_CSR_PKG__
`define __BSG_MLA_CSR_PKG__

package bsg_mla_csr_pkg;

    `define bsg_mla_csr_init(num_csrs_mp, mem_width_mp)             \
        logic [mem_width_mp-1:0] csr_mem_data_li;                   \
        logic [num_csrs_mp-1:0][mem_width_mp-1:0] csr_mem_data_lo;  \
        logic [num_csrs_mp-1:0] csr_mem_wen_li;

    `define bsg_mla_csr_create(name, id_mp, width_mp, mem_width_mp) \
        logic [width_mp-1:0] csr_core_``name``_n;                   \
        logic [width_mp-1:0] csr_core_``name``_r;                   \
        logic csr_core_``name``_wen;                                \
        bsg_mla_csr #                                               \
            (.core_width_p(width_mp)                                \
            ,.mem_width_p(mem_width_mp))                            \
        name``_csr                                                  \
            (.clk_i(clk_i)                                          \
            ,.reset_i(reset_i)                                      \
            ,.mem_data_i(csr_mem_data_li)                           \
            ,.mem_wen_i(csr_mem_wen_li[id_mp])                      \
            ,.mem_data_o(csr_mem_data_lo[id_mp])                    \
            ,.core_data_i(csr_core_``name``_n)                      \
            ,.core_wen_i(csr_core_``name``_wen)                     \
            ,.core_data_o(csr_core_``name``_r)                      \
            );

endpackage // bsg_mla_csr_pkg

`endif // __BSG_MLA_CSR_PKG__
