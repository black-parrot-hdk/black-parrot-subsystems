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
`include "bsg_mla_csr_pkg.svh"

module bsg_mla_dma_controller_core
import bsg_mla_csr_pkg::*; #( parameter p_addr_width_p     = -1
                            , parameter p_data_width_p     = -1

                            , parameter c_addr_width_p     = -1
                            , parameter c_mask_width_p     = -1

                            , parameter csr_length_width_p = 16
                            , parameter csr_stride_width_p = 8
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

  , output logic [c_addr_width_p-1:0]   rd_addr_o
  , output logic                        rd_v_o
  , input  logic                        rd_yumi_i

  , output logic [c_addr_width_p-1:0]   wr_addr_o
  , output logic [c_mask_width_p-1:0]   wr_mask_o
  , output logic                        wr_v_o
  , input  logic                        wr_yumi_i

  , input  logic                        wr_fence_i

  , output logic                        interrupt_o
  , output logic                        prefetch_mode_o
  );

  typedef enum logic [2:0] {
      eSTA = 3'd0,
      eCTL = 3'd1,
      eINT = 3'd2,
      eRBA = 3'd3,
      eWBA = 3'd4,
      eMS0 = 3'd5,
      eME0 = 3'd6,
      eLS0 = 3'd7
  } bsg_mla_dma_controller_core_csrs_e;

  typedef enum logic [1:0] {
      eIDLE = 2'b00,
      eBUSY = 2'b01,
      eDONE = 2'b11
  } bsg_mla_dma_controller_core_state_e;

  typedef struct packed {
      logic prefetch;
      logic sg_en;
      logic burst_en;
      logic fixed_wa;
      logic fixed_ra;
      logic int_mode;
      logic _reserve_;
  } bsg_mla_dma_controller_core_control_s;

    localparam num_csrs_lp                  = 8;
    localparam csr_addr_width_lp            = $clog2(num_csrs_lp);

    localparam csr_sta_width_lp             = $bits(bsg_mla_dma_controller_core_state_e);
    localparam csr_ctl_width_lp             = $bits(bsg_mla_dma_controller_core_control_s);
    localparam csr_base_addr_width_lp       = c_addr_width_p;
    localparam csr_mask_width_lp            = c_mask_width_p;
    localparam csr_length_stride_width_lp   = 2*csr_stride_width_p + csr_length_width_p;

    localparam p_addr_lsb_lp = $clog2(p_data_width_p / 8);

    localparam min_p_addr_width_lp = csr_addr_width_lp + p_addr_lsb_lp;

    localparam min_p_data_width_lp = `BSG_MAX( csr_sta_width_lp,
                                     `BSG_MAX( csr_ctl_width_lp,
                                     `BSG_MAX( 1, // interrupt
                                     `BSG_MAX( csr_base_addr_width_lp,
                                     `BSG_MAX( csr_mask_width_lp,
                                     `BSG_MAX( csr_length_stride_width_lp,
                                      0 ))))));

    if (p_data_width_p % 8 != 0)
        $fatal(1, "p_data_width_p must be a multiple of 8");

    if (p_data_width_p < min_p_data_width_lp)
        $fatal(1, "p_data_width_p must be larger than %d", min_p_data_width_lp);

    if (p_addr_width_p < min_p_addr_width_lp)
        $fatal(1, "p_addr_width_p must be larger than %d", min_p_addr_width_lp);

    `bsg_mla_csr_init( num_csrs_lp , p_data_width_p );
        // Defines two logics:
        //      1. csr_mem_data_li [data_width]
        //      2. csr_mem_data_lo [num_csrs][data_width]
        //      3. csr_mem_wen_li  [num_csrs]

    `bsg_mla_csr_create( sta , eSTA , csr_sta_width_lp           , p_data_width_p );
    `bsg_mla_csr_create( ctl , eCTL , csr_ctl_width_lp           , p_data_width_p );
    `bsg_mla_csr_create( int , eINT , 1                          , p_data_width_p );
    `bsg_mla_csr_create( rba , eRBA , csr_base_addr_width_lp     , p_data_width_p );
    `bsg_mla_csr_create( wba , eWBA , csr_base_addr_width_lp     , p_data_width_p );
    `bsg_mla_csr_create( ms0 , eMS0 , csr_mask_width_lp          , p_data_width_p );
    `bsg_mla_csr_create( me0 , eME0 , csr_mask_width_lp          , p_data_width_p );
    `bsg_mla_csr_create( ls0 , eLS0 , csr_length_stride_width_lp , p_data_width_p );
        // Create the CSR registers and connects to the csr_mem_* logics created before and creates
        // 3 new logics for each CSR:
        //      1. csr_core_``name``_n
        //      2. csr_core_``name``_r
        //      3. csr_core_``name``_wen

    assign csr_mem_data_li = p_data_i;

    // assign csr_core_sta_wen = 1'b0;
    assign csr_core_ctl_wen = 1'b0;
    // assign csr_core_int_wen = 1'b0;
    assign csr_core_rba_wen = 1'b0;
    assign csr_core_wba_wen = 1'b0;
    assign csr_core_ms0_wen = 1'b0;
    assign csr_core_me0_wen = 1'b0;
    assign csr_core_ls0_wen = 1'b0;

    bsg_mla_dma_controller_core_state_e csr_core_sta_n_cast, csr_core_sta_r_cast;
    assign csr_core_sta_r_cast = bsg_mla_dma_controller_core_state_e'(csr_core_sta_r);
    assign csr_core_sta_n = csr_core_sta_n_cast;

    bsg_mla_dma_controller_core_control_s csr_core_ctl_r_cast;
    assign csr_core_ctl_r_cast = bsg_mla_dma_controller_core_control_s'(csr_core_ctl_r);

    logic [csr_length_width_p-1:0] length_r;
    logic [csr_stride_width_p-1:0] wr_stride_r, rd_stride_r;
    assign {length_r, wr_stride_r, rd_stride_r} = csr_core_ls0_r;

    wire is_idle = (csr_core_sta_r_cast == eIDLE);
    wire is_busy = (csr_core_sta_r_cast == eBUSY);
    wire is_done = (csr_core_sta_r_cast == eDONE);

    wire start_set_n = csr_mem_wen_li[eCTL] &  p_data_i[0];
    wire clear_int_n = csr_mem_wen_li[eINT] & ~p_data_i[0];

    wire [csr_addr_width_lp-1:0] csr_addr_li = p_addr_i[p_addr_lsb_lp+:csr_addr_width_lp];

    always_comb begin
        csr_mem_wen_li = '0;
        if (p_w_i & p_yumi_o) begin
            csr_mem_wen_li = 1'b1 << csr_addr_li;
        end
    end

    logic rd_done_lo, wr_done_lo, wr_first_lo, wr_last_lo;

    always_comb begin
        csr_core_sta_n_cast = csr_core_sta_r_cast;
        csr_core_sta_wen = 1'b0;
        csr_core_int_n = csr_core_int_r;
        csr_core_int_wen = 1'b0;
        if (is_idle & start_set_n) begin
            csr_core_sta_n_cast = eBUSY;
            csr_core_sta_wen = 1'b1;
        end
        else if (is_busy & rd_done_lo & ((wr_done_lo & wr_fence_i) | csr_core_ctl_r_cast.prefetch)) begin
            csr_core_sta_n_cast = eDONE;
            csr_core_sta_wen = 1'b1;
            csr_core_int_n = 1'b1;
            csr_core_int_wen = 1'b1;
        end
        else if (is_done & clear_int_n) begin
            csr_core_sta_n_cast = eIDLE;
            csr_core_sta_wen = 1'b1;
            csr_core_int_n = 1'b0;
            csr_core_int_wen = 1'b1;
        end
    end

    assign p_yumi_o = p_v_i & (~p_w_i | ~is_busy);

    bsg_mla_dff_with_v #
        (.width_p(p_data_width_p))
    csr_rd_reg
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.data_i(csr_mem_data_lo[csr_addr_li])
        ,.v_i(~p_w_i & p_yumi_o)

        ,.data_o(p_data_o)
        ,.v_o(p_v_o)
        );

    bsg_mla_dma_controller_addr_gen #
        (.addr_width_p(c_addr_width_p)
        ,.stride_width_p(csr_stride_width_p)
        ,.length_width_p(csr_length_width_p))
    rd_addr_gen
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.en_i(is_busy)

        ,.clear_i(clear_int_n)
        ,.first_o(/* dc */)
        ,.last_o(/* dc */)
        ,.done_o(rd_done_lo)

        ,.base_addr_r_i(csr_core_rba_r)
        ,.stride_r_i(rd_stride_r & {csr_stride_width_p{~csr_core_ctl_r_cast.fixed_ra}})
        ,.length_r_i(length_r)

        ,.addr_o(rd_addr_o)
        ,.v_o(rd_v_o)
        ,.yumi_i(rd_yumi_i)
        );

    bsg_mla_dma_controller_addr_gen #
        (.addr_width_p(c_addr_width_p)
        ,.stride_width_p(csr_stride_width_p)
        ,.length_width_p(csr_length_width_p))
    wr_addr_gen
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.en_i(is_busy & ~csr_core_ctl_r_cast.prefetch)

        ,.clear_i(clear_int_n)
        ,.first_o(wr_first_lo)
        ,.last_o(wr_last_lo)
        ,.done_o(wr_done_lo)

        ,.base_addr_r_i(csr_core_wba_r)
        ,.stride_r_i(wr_stride_r & {csr_stride_width_p{~csr_core_ctl_r_cast.fixed_wa}})
        ,.length_r_i(length_r)

        ,.addr_o(wr_addr_o)
        ,.v_o(wr_v_o)
        ,.yumi_i(wr_yumi_i)
        );

    always_comb begin
        if (wr_first_lo) begin
            wr_mask_o = csr_core_ms0_r;
        end else if (wr_last_lo) begin
            wr_mask_o = csr_core_me0_r;
        end else begin
            wr_mask_o = '1;
        end
    end

    assign interrupt_o     = csr_core_int_r & csr_core_ctl_r_cast.int_mode;
    assign prefetch_mode_o = csr_core_ctl_r_cast.prefetch;

endmodule // bsg_mla_dma_controller_core
