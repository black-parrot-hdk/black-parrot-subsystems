
// This module wraps a BP core with AXI interfaces. For an example usage
//   see https://github.com/black-parrot-hdk/zynq-parrot

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_axi_top
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_axi_pkg::*;
 // see bp_common/src/include/bp_common_aviary_pkgdef.svh for a list of configurations that you can try!
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // AXI4-LITE PARAMS
   , parameter `BSG_INV_PARAM(m_axil_addr_width_p)
   , parameter `BSG_INV_PARAM(m_axil_data_width_p)
   , localparam m_axil_mask_width_lp = m_axil_data_width_p>>3

   , parameter `BSG_INV_PARAM(s_axil_addr_width_p)
   , parameter `BSG_INV_PARAM(s_axil_data_width_p)
   , localparam s_axil_mask_width_lp = s_axil_data_width_p>>3

   , parameter `BSG_INV_PARAM(axi_addr_width_p)
   , parameter `BSG_INV_PARAM(axi_data_width_p)
   , parameter `BSG_INV_PARAM(axi_id_width_p)
   , parameter `BSG_INV_PARAM(axi_len_width_p)
   , parameter `BSG_INV_PARAM(axi_size_width_p)
   , localparam axi_mask_width_lp = axi_data_width_p>>3

   // for async operation of bp and AXI; will then need to provide valid aclk_i
   // otherwise, clk_i will be used for both BlackParrot and AXI busses
   , parameter `BSG_INV_PARAM(axi_async_p)
   , parameter `BSG_INV_PARAM(async_fifo_size_p)

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                       clk_i
   , input                                     reset_i
   , input                                     aclk_i
   , input                                     areset_i
   , input                                     rt_clk_i

   //======================== Outgoing I/O ========================
   , output logic [m_axil_addr_width_p-1:0]    m_axil_awaddr_o
   , output [2:0]                              m_axil_awprot_o
   , output logic                              m_axil_awvalid_o
   , input                                     m_axil_awready_i

   , output logic [m_axil_data_width_p-1:0]    m_axil_wdata_o
   , output logic [m_axil_mask_width_lp-1:0]   m_axil_wstrb_o
   , output logic                              m_axil_wvalid_o
   , input                                     m_axil_wready_i

   , input [1:0]                               m_axil_bresp_i
   , input                                     m_axil_bvalid_i
   , output logic                              m_axil_bready_o

   , output logic [m_axil_addr_width_p-1:0]    m_axil_araddr_o
   , output [2:0]                              m_axil_arprot_o
   , output logic                              m_axil_arvalid_o
   , input                                     m_axil_arready_i

   , input [m_axil_data_width_p-1:0]           m_axil_rdata_i
   , input [1:0]                               m_axil_rresp_i
   , input                                     m_axil_rvalid_i
   , output logic                              m_axil_rready_o

   //======================== Incoming I/O ========================
   , input [s_axil_addr_width_p-1:0]           s_axil_awaddr_i
   , input [2:0]                               s_axil_awprot_i
   , input                                     s_axil_awvalid_i
   , output logic                              s_axil_awready_o

   , input [s_axil_data_width_p-1:0]           s_axil_wdata_i
   , input [s_axil_mask_width_lp-1:0]          s_axil_wstrb_i
   , input                                     s_axil_wvalid_i
   , output logic                              s_axil_wready_o

   , output [1:0]                              s_axil_bresp_o
   , output logic                              s_axil_bvalid_o
   , input                                     s_axil_bready_i

   , input [s_axil_addr_width_p-1:0]           s_axil_araddr_i
   , input [2:0]                               s_axil_arprot_i
   , input                                     s_axil_arvalid_i
   , output logic                              s_axil_arready_o

   , output logic [s_axil_data_width_p-1:0]    s_axil_rdata_o
   , output [1:0]                              s_axil_rresp_o
   , output logic                              s_axil_rvalid_o
   , input                                     s_axil_rready_i

   //======================== Outgoing Memory ========================
   , output logic [axi_addr_width_p-1:0]       m_axi_awaddr_o
   , output logic                              m_axi_awvalid_o
   , input                                     m_axi_awready_i
   , output logic [axi_id_width_p-1:0]         m_axi_awid_o
   , output logic [1:0]                        m_axi_awlock_o
   , output logic [3:0]                        m_axi_awcache_o
   , output logic [2:0]                        m_axi_awprot_o
   , output logic [axi_len_width_p-1:0]        m_axi_awlen_o
   , output logic [axi_size_width_p-1:0]       m_axi_awsize_o
   , output logic [1:0]                        m_axi_awburst_o
   , output logic [3:0]                        m_axi_awqos_o

   , output logic [axi_data_width_p-1:0]       m_axi_wdata_o
   , output logic                              m_axi_wvalid_o
   , input                                     m_axi_wready_i
   , output logic [axi_id_width_p-1:0]         m_axi_wid_o
   , output logic                              m_axi_wlast_o
   , output logic [axi_mask_width_lp-1:0]      m_axi_wstrb_o

   , input                                     m_axi_bvalid_i
   , output logic                              m_axi_bready_o
   , input [axi_id_width_p-1:0]                m_axi_bid_i
   , input [1:0]                               m_axi_bresp_i

   , output logic [axi_addr_width_p-1:0]       m_axi_araddr_o
   , output logic                              m_axi_arvalid_o
   , input                                     m_axi_arready_i
   , output logic [axi_id_width_p-1:0]         m_axi_arid_o
   , output logic [1:0]                        m_axi_arlock_o
   , output logic [3:0]                        m_axi_arcache_o
   , output logic [2:0]                        m_axi_arprot_o
   , output logic [axi_len_width_p-1:0]        m_axi_arlen_o
   , output logic [axi_size_width_p-1:0]       m_axi_arsize_o
   , output logic [1:0]                        m_axi_arburst_o
   , output logic [3:0]                        m_axi_arqos_o

   , input [axi_data_width_p-1:0]              m_axi_rdata_i
   , input                                     m_axi_rvalid_i
   , output logic                              m_axi_rready_o
   , input [axi_id_width_p-1:0]                m_axi_rid_i
   , input                                     m_axi_rlast_i
   , input [1:0]                               m_axi_rresp_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  wire aclk_li   = axi_async_p ? aclk_i   : clk_i;
  wire areset_li = axi_async_p ? areset_i : reset_i;

  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_v_li, mem_fwd_ready_and_lo;
  bp_bedrock_mem_rev_header_s mem_rev_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_lo;
  logic mem_rev_v_lo, mem_rev_ready_and_li;
  bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_lo;
  logic mem_fwd_v_lo, mem_fwd_ready_and_li;
  bp_bedrock_mem_rev_header_s mem_rev_header_li;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_li;
  logic mem_rev_v_li, mem_rev_ready_and_lo;

  // DMA interface from BP to cache2axi
  `declare_bsg_cache_dma_pkt_s(daddr_width_p, dma_mask_width_p);
  bsg_cache_dma_pkt_s [num_cce_p*dma_els_p-1:0] dma_pkt_lo;
  logic [num_cce_p*dma_els_p-1:0] dma_pkt_v_lo, dma_pkt_ready_and_li, dma_pkt_full_li;
  logic [num_cce_p*dma_els_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [num_cce_p*dma_els_p-1:0] dma_data_v_lo, dma_data_ready_and_li;
  logic [num_cce_p*dma_els_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [num_cce_p*dma_els_p-1:0] dma_data_v_li, dma_data_ready_and_lo;

  bp_processor
   #(.bp_params_p(bp_params_p))
   processor
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)

     // Irrelevant for current AXI wrapper
     ,.my_did_i(1'b1)
     ,.host_did_i('1)

     // Outgoing I/O
     ,.mem_fwd_header_o(mem_fwd_header_lo)
     ,.mem_fwd_data_o(mem_fwd_data_lo)
     ,.mem_fwd_v_o(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_li)

     ,.mem_rev_header_i(mem_rev_header_li)
     ,.mem_rev_data_i(mem_rev_data_li)
     ,.mem_rev_v_i(mem_rev_v_li)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_lo)

     // Incoming I/O
     ,.mem_fwd_header_i(mem_fwd_header_li)
     ,.mem_fwd_data_i(mem_fwd_data_li)
     ,.mem_fwd_v_i(mem_fwd_v_li)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_lo)

     ,.mem_rev_header_o(mem_rev_header_lo)
     ,.mem_rev_data_o(mem_rev_data_lo)
     ,.mem_rev_v_o(mem_rev_v_lo)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_li)

     // DMA (memory) to cache2axi
     ,.dma_pkt_o(dma_pkt_lo)
     ,.dma_pkt_v_o(dma_pkt_v_lo)
     ,.dma_pkt_ready_and_i(dma_pkt_ready_and_li)

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_and_o(dma_data_ready_and_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_ready_and_i(dma_data_ready_and_li)
     );

  bp_me_axil_client
   #(.bp_params_p(bp_params_p)
     ,.axil_data_width_p(s_axil_data_width_p)
     ,.axil_addr_width_p(s_axil_addr_width_p)
     ,.axi_async_p(axi_async_p)
     ,.async_fifo_size_p(async_fifo_size_p)
     )
   axil2io
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.aclk_i(aclk_li)
     ,.areset_i(areset_li)

     ,.mem_fwd_header_o(mem_fwd_header_li)
     ,.mem_fwd_data_o(mem_fwd_data_li)
     ,.mem_fwd_v_o(mem_fwd_v_li)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_lo)

     ,.mem_rev_header_i(mem_rev_header_lo)
     ,.mem_rev_data_i(mem_rev_data_lo)
     ,.mem_rev_v_i(mem_rev_v_lo)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_li)

     ,.lce_id_i(lce_id_width_p'('b10))
     ,.did_i(did_width_p'('1))
     ,.*
     );

  bp_me_axil_master
   #(.bp_params_p(bp_params_p)
     ,.axil_data_width_p(m_axil_data_width_p)
     ,.axil_addr_width_p(m_axil_addr_width_p)
     ,.axi_async_p(axi_async_p)
     ,.async_fifo_size_p(async_fifo_size_p)
     )
   io2axil
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.aclk_i(aclk_li)
     ,.areset_i(areset_li)

     ,.mem_fwd_header_i(mem_fwd_header_lo)
     ,.mem_fwd_data_i(mem_fwd_data_lo)
     ,.mem_fwd_v_i(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_li)

     ,.mem_rev_header_o(mem_rev_header_li)
     ,.mem_rev_data_o(mem_rev_data_li)
     ,.mem_rev_v_o(mem_rev_v_li)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_lo)

     ,.*
     );

  // If necessary, downsize to axi data width. This could be done in bsg_cache_to_axi,
  //   but punt for now
  logic [num_cce_p*dma_els_p-1:0][axi_data_width_p-1:0] axi_dma_data_lo;
  logic [num_cce_p*dma_els_p-1:0] axi_dma_data_v_lo, axi_dma_data_ready_and_li;
  logic [num_cce_p*dma_els_p-1:0][axi_data_width_p-1:0] axi_dma_data_li;
  logic [num_cce_p*dma_els_p-1:0] axi_dma_data_v_li, axi_dma_data_yumi_lo, axi_dma_data_full_lo;
  for (genvar i = 0; i < num_cce_p*dma_els_p; i++)
    begin : narrow
      bsg_serial_in_parallel_out_full
       #(.width_p(axi_data_width_p), .els_p(l2_fill_width_p/axi_data_width_p))
       dma_sipo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(axi_dma_data_lo[i])
         ,.v_i(axi_dma_data_v_lo[i])
         ,.ready_o(axi_dma_data_ready_and_li[i])

         ,.data_o(dma_data_li[i])
         ,.v_o(dma_data_v_li[i])
         ,.yumi_i(dma_data_ready_and_lo[i] & dma_data_v_li[i])
         );

      bsg_parallel_in_serial_out
       #(.width_p(axi_data_width_p), .els_p(l2_fill_width_p/axi_data_width_p))
       dma_piso
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(dma_data_lo[i])
         ,.valid_i(dma_data_v_lo[i])
         ,.ready_and_o(dma_data_ready_and_li[i])

         ,.data_o(axi_dma_data_li[i])
         ,.valid_o(axi_dma_data_v_li[i])
         ,.yumi_i(axi_dma_data_yumi_lo[i])
         );
    end

  bsg_cache_dma_pkt_s [num_cce_p*dma_els_p-1:0] cache2axi_dma_pkt_lo;
  logic [num_cce_p*dma_els_p-1:0] cache2axi_dma_pkt_v_lo, cache2axi_dma_pkt_ready_and_li;

  logic [num_cce_p*dma_els_p-1:0][axi_data_width_p-1:0] cache2axi_dma_data_lo;
  logic [num_cce_p*dma_els_p-1:0] cache2axi_dma_data_v_lo, cache2axi_dma_data_ready_and_li;

  logic [num_cce_p*dma_els_p-1:0][axi_data_width_p-1:0] buf_axi_dma_data_lo;
  logic [num_cce_p*dma_els_p-1:0] buf_axi_dma_data_v_lo, buf_axi_dma_data_full_li;

  logic [num_cce_p*dma_els_p-1:0][axi_data_width_p-1:0] cache2axi_dma_data_li;
  logic [num_cce_p*dma_els_p-1:0] cache2axi_dma_data_v_li, cache2axi_dma_data_yumi_lo;

  if(axi_async_p) begin: async
    for (genvar i = 0; i < num_cce_p*dma_els_p; i++) begin: nl2
      bsg_async_fifo
       #(.width_p($bits(bsg_cache_dma_pkt_s))
        ,.lg_size_p(async_fifo_size_p)
        )
       bp2a_pkt_cross
        (.w_clk_i(clk_i)
        ,.w_reset_i(reset_i)

        ,.w_enq_i(dma_pkt_v_lo[i] & ~dma_pkt_full_li[i])
        ,.w_data_i(dma_pkt_lo[i])
        ,.w_full_o(dma_pkt_full_li[i])

        ,.r_clk_i(aclk_li)
        ,.r_reset_i(areset_li)

        ,.r_deq_i(cache2axi_dma_pkt_ready_and_li[i])
        ,.r_data_o(cache2axi_dma_pkt_lo[i])
        ,.r_valid_o(cache2axi_dma_pkt_v_lo[i])
        );
      assign dma_pkt_ready_and_li[i] = ~dma_pkt_full_li[i];

      bsg_async_fifo
       #(.width_p(axi_data_width_p)
        ,.lg_size_p(async_fifo_size_p)
        )
       bp2a_cross
        (.w_clk_i(clk_i)
        ,.w_reset_i(reset_i)

        ,.w_enq_i(axi_dma_data_v_li[i] & ~axi_dma_data_full_lo[i])
        ,.w_data_i(axi_dma_data_li[i])
        ,.w_full_o(axi_dma_data_full_lo[i])

        ,.r_clk_i(aclk_li)
        ,.r_reset_i(areset_li)

        ,.r_deq_i(cache2axi_dma_data_yumi_lo[i])
        ,.r_data_o(cache2axi_dma_data_li[i])
        ,.r_valid_o(cache2axi_dma_data_v_li[i])
        );
      assign axi_dma_data_yumi_lo[i] = ~axi_dma_data_full_lo[i] & axi_dma_data_v_li[i];

      bsg_fifo_1r1w_small
       #(.width_p(axi_data_width_p)
        ,.els_p(16*l2_block_width_p/axi_data_width_p)
        )
       a2bp_buf
        (.clk_i(aclk_li)
        ,.reset_i(areset_li)

        ,.v_i(cache2axi_dma_data_v_lo[i])
        ,.data_i(cache2axi_dma_data_lo[i])
        ,.ready_o(cache2axi_dma_data_ready_and_li[i])

        ,.v_o(buf_axi_dma_data_v_lo[i])
        ,.data_o(buf_axi_dma_data_lo[i])
        ,.yumi_i(~buf_axi_dma_data_full_li[i] & buf_axi_dma_data_v_lo[i])
        );

      bsg_async_fifo
       #(.width_p(axi_data_width_p)
        ,.lg_size_p(async_fifo_size_p)
        )
       a2bp_cross
        (.w_clk_i(aclk_li)
        ,.w_reset_i(areset_li)

        ,.w_enq_i (buf_axi_dma_data_v_lo[i] & ~buf_axi_dma_data_full_li[i])
        ,.w_data_i(buf_axi_dma_data_lo[i])
        ,.w_full_o(buf_axi_dma_data_full_li[i])

        ,.r_clk_i(clk_i)
        ,.r_reset_i(reset_i)

        ,.r_deq_i(axi_dma_data_ready_and_li[i] & axi_dma_data_v_lo[i])
        ,.r_data_o(axi_dma_data_lo[i])
        ,.r_valid_o(axi_dma_data_v_lo[i])
        );
    end
  end
  else begin
    assign dma_pkt_ready_and_li = cache2axi_dma_pkt_ready_and_li;
    assign cache2axi_dma_pkt_v_lo = dma_pkt_v_lo;
    assign cache2axi_dma_pkt_lo = dma_pkt_lo;

    assign cache2axi_dma_data_li = axi_dma_data_li;
    assign cache2axi_dma_data_v_li = axi_dma_data_v_li;
    assign axi_dma_data_yumi_lo = cache2axi_dma_data_yumi_lo;

    assign axi_dma_data_lo = cache2axi_dma_data_lo;
    assign axi_dma_data_v_lo = cache2axi_dma_data_v_lo;
    assign cache2axi_dma_data_ready_and_li = axi_dma_data_ready_and_li;
  end

  bsg_cache_to_axi
   #(.addr_width_p(daddr_width_p)
     ,.data_width_p(axi_data_width_p)
     ,.mask_width_p(dma_mask_width_p)
     ,.block_size_in_words_p(l2_block_width_p/axi_data_width_p)
     ,.num_cache_p(num_cce_p*dma_els_p)
     ,.axi_data_width_p(axi_data_width_p)
     ,.axi_id_width_p(axi_id_width_p)
     ,.axi_burst_len_p(l2_block_width_p/axi_data_width_p)
     ,.axi_burst_type_p(e_axi_burst_wrap)
     ,.tag_fifo_els_p(l2_en_p ? l2_banks_p : 4)
     ,.ordering_en_p(l2_en_p ? 0 : 1)
     )
   cache2axi
    (.clk_i(aclk_li)
     ,.reset_i(areset_li)

     ,.dma_pkt_i(cache2axi_dma_pkt_lo)
     ,.dma_pkt_v_i(cache2axi_dma_pkt_v_lo)
     ,.dma_pkt_yumi_o(cache2axi_dma_pkt_ready_and_li)

     ,.dma_data_o(cache2axi_dma_data_lo)
     ,.dma_data_v_o(cache2axi_dma_data_v_lo)
     ,.dma_data_ready_i(cache2axi_dma_data_ready_and_li)

     ,.dma_data_i(cache2axi_dma_data_li)
     ,.dma_data_v_i(cache2axi_dma_data_v_li)
     ,.dma_data_yumi_o(cache2axi_dma_data_yumi_lo)

     ,.axi_awid_o(m_axi_awid_o)
     ,.axi_awaddr_addr_o(m_axi_awaddr_o)
     ,.axi_awlen_o(m_axi_awlen_o)
     ,.axi_awsize_o(m_axi_awsize_o)
     ,.axi_awburst_o(m_axi_awburst_o)
     ,.axi_awcache_o(m_axi_awcache_o)
     ,.axi_awprot_o(m_axi_awprot_o)
     ,.axi_awlock_o(m_axi_awlock_o)
     ,.axi_awvalid_o(m_axi_awvalid_o)
     ,.axi_awready_i(m_axi_awready_i)

     ,.axi_wdata_o(m_axi_wdata_o)
     ,.axi_wstrb_o(m_axi_wstrb_o)
     ,.axi_wlast_o(m_axi_wlast_o)
     ,.axi_wvalid_o(m_axi_wvalid_o)
     ,.axi_wready_i(m_axi_wready_i)

     ,.axi_bid_i(m_axi_bid_i)
     ,.axi_bresp_i(m_axi_bresp_i)
     ,.axi_bvalid_i(m_axi_bvalid_i)
     ,.axi_bready_o(m_axi_bready_o)

     ,.axi_arid_o(m_axi_arid_o)
     ,.axi_araddr_addr_o(m_axi_araddr_o)
     ,.axi_arlen_o(m_axi_arlen_o)
     ,.axi_arsize_o(m_axi_arsize_o)
     ,.axi_arburst_o(m_axi_arburst_o)
     ,.axi_arcache_o(m_axi_arcache_o)
     ,.axi_arprot_o(m_axi_arprot_o)
     ,.axi_arlock_o(m_axi_arlock_o)
     ,.axi_arvalid_o(m_axi_arvalid_o)
     ,.axi_arready_i(m_axi_arready_i)

     ,.axi_rid_i(m_axi_rid_i)
     ,.axi_rdata_i(m_axi_rdata_i)
     ,.axi_rresp_i(m_axi_rresp_i)
     ,.axi_rlast_i(m_axi_rlast_i)
     ,.axi_rvalid_i(m_axi_rvalid_i)
     ,.axi_rready_o(m_axi_rready_o)

     // Unused
     ,.axi_awaddr_cache_id_o()
     ,.axi_araddr_cache_id_o()
     );

endmodule

