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

module bsg_mla_dma_controller #( parameter p_addr_width_p       = 32
                               , parameter p_data_width_p       = 32

                               , parameter c_addr_width_p       = 32
                               , parameter c_data_width_p       = 32
                               , parameter c_mask_width_p       = c_data_width_p / 8

                               , parameter csr_length_width_p   = 16
                               , parameter csr_stride_width_p   = 8

                               , parameter out_of_order_p       = 0
                               , parameter st_fwd_fifo_els_p    = 16
                               , parameter max_outstanding_wr_p = st_fwd_fifo_els_p
                               )
  ( input  logic                        clk_i
  , input  logic                        reset_i

  , input  logic [p_addr_width_p-1:0]   p_addr_i
  , input  logic [p_data_width_p-1:0]   p_data_i
  , input  logic                        p_w_i
  , input  logic                        p_v_i
  , output logic                        p_yumi_o

  , output logic [p_data_width_p-1:0]   p_data_o
  , output logic                        p_v_o

  , output logic [c_addr_width_p-1:0]   c_rd_addr_o
  , output logic                        c_rd_v_o
  , input  logic                        c_rd_yumi_i

  , input  logic [c_addr_width_p-1:0]   c_rd_addr_i // can leave Z if out_of_order_p == 0
  , input  logic [c_data_width_p-1:0]   c_rd_data_i
  , input  logic                        c_rd_v_i

  , output logic [c_addr_width_p-1:0]   c_wr_addr_o
  , output logic [c_data_width_p-1:0]   c_wr_data_o
  , output logic [c_mask_width_p-1:0]   c_wr_mask_o
  , output logic                        c_wr_v_o
  , input  logic                        c_wr_yumi_i

  , input  logic                        c_wr_ack_i

  , output logic                        interrupt_o
  );

  localparam outstanding_wr_width_lp = `BSG_WIDTH(max_outstanding_wr_p);

  logic rd_v_lo, wr_v_lo;
  logic st_fwd_alloc_v_lo, st_fwd_v_lo;
  logic prefetch_mode_lo;

  logic [outstanding_wr_width_lp-1:0] outstanding_wr_n, outstanding_wr_r;

  assign outstanding_wr_n = outstanding_wr_r + c_wr_yumi_i - c_wr_ack_i;

  wire max_outstanding_wr_n = (outstanding_wr_r == max_outstanding_wr_p);
  wire no_outstanding_wr_n  = (outstanding_wr_n == '0);

  assign c_rd_v_o = rd_v_lo & st_fwd_alloc_v_lo;
  assign c_wr_v_o = wr_v_lo & st_fwd_v_lo & ~max_outstanding_wr_n;

  bsg_mla_dma_controller_core #(.p_addr_width_p(p_addr_width_p)
                               ,.p_data_width_p(p_data_width_p)
                               ,.c_addr_width_p(c_addr_width_p)
                               ,.c_mask_width_p(c_mask_width_p)
                               ,.csr_length_width_p(csr_length_width_p)
                               ,.csr_stride_width_p(csr_stride_width_p))
    core
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.p_addr_i(p_addr_i)
      ,.p_data_i(p_data_i)
      ,.p_w_i(p_w_i)
      ,.p_v_i(p_v_i)
      ,.p_yumi_o(p_yumi_o)

      ,.p_data_o(p_data_o)
      ,.p_v_o(p_v_o)

      ,.rd_addr_o(c_rd_addr_o)
      ,.rd_v_o(rd_v_lo)
      ,.rd_yumi_i(c_rd_yumi_i)

      ,.wr_addr_o(c_wr_addr_o)
      ,.wr_mask_o(c_wr_mask_o)
      ,.wr_v_o(wr_v_lo)
      ,.wr_yumi_i(c_wr_yumi_i)

      ,.wr_fence_i(no_outstanding_wr_n)

      ,.interrupt_o(interrupt_o)
      ,.prefetch_mode_o(prefetch_mode_lo)
      );

  bsg_dff_reset #(.width_p(outstanding_wr_width_lp))
    outstanding_wr_reg
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(outstanding_wr_n)
      ,.data_o(outstanding_wr_r)
      );

  if (out_of_order_p)
    begin: ooo
      bsg_mla_fifo_reorder_cam #(.width_p(c_data_width_p)
                                ,.addr_width_p(c_addr_width_p)
                                ,.els_p(st_fwd_fifo_els_p))
        st_fwd_fifo
          (.clk_i(clk_i)
          ,.reset_i(reset_i)

          ,.alloc_addr_i(c_rd_addr_o)
          ,.alloc_v_o(st_fwd_alloc_v_lo)
          ,.alloc_yumi_i(c_rd_yumi_i)

          ,.addr_i(c_rd_addr_i)
          ,.data_i(c_rd_data_i)
          ,.v_i(c_rd_v_i)

          ,.data_o(c_wr_data_o)
          ,.v_o(st_fwd_v_lo)
          ,.yumi_i(c_wr_yumi_i | (st_fwd_v_lo & prefetch_mode_lo))
          );
    end: ooo
  else
    begin: ino
      bsg_mla_fifo_1r1w_small_alloc #(.width_p(c_data_width_p)
                                     ,.els_p(st_fwd_fifo_els_p))
        st_fwd_fifo
          (.clk_i(clk_i)
          ,.reset_i(reset_i)

          ,.alloc_v_o(st_fwd_alloc_v_lo)
          ,.alloc_yumi_i(c_rd_yumi_i)

          ,.empty_o()
          ,.data_i(c_rd_data_i)
          ,.v_i(c_rd_v_i)

          ,.data_o(c_wr_data_o)
          ,.v_o(st_fwd_v_lo)
          ,.yumi_i(c_wr_yumi_i | (st_fwd_v_lo & prefetch_mode_lo))
          );
    end: ino

endmodule // bsg_mla_dma_controller
