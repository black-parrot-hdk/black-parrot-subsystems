
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
   , parameter axi_core_clk_async_p = 0
   , localparam lg_async_fifo_size_lp = 3

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
   , localparam axi_mask_width_lp = axi_data_width_p>>3

   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   )
  (input                                       axi_clk_i
   , input                                     core_clk_i
   , input                                     rt_clk_i
   , input                                     async_reset_i

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
   , output logic                              m_axi_awlock_o
   , output logic [3:0]                        m_axi_awcache_o
   , output logic [2:0]                        m_axi_awprot_o
   , output logic [7:0]                        m_axi_awlen_o
   , output logic [2:0]                        m_axi_awsize_o
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
   , output logic                              m_axi_arlock_o
   , output logic [3:0]                        m_axi_arcache_o
   , output logic [2:0]                        m_axi_arprot_o
   , output logic [7:0]                        m_axi_arlen_o
   , output logic [2:0]                        m_axi_arsize_o
   , output logic [1:0]                        m_axi_arburst_o
   , output logic [3:0]                        m_axi_arqos_o

   , input [axi_data_width_p-1:0]              m_axi_rdata_i
   , input                                     m_axi_rvalid_i
   , output logic                              m_axi_rready_o
   , input [axi_id_width_p-1:0]                m_axi_rid_i
   , input                                     m_axi_rlast_i
   , input [1:0]                               m_axi_rresp_i
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

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
  `declare_bsg_cache_dma_pkt_s(daddr_width_p, l2_block_size_in_words_p);
  bsg_cache_dma_pkt_s [num_cce_p*l2_dmas_p-1:0] dma_pkt_lo;
  logic [num_cce_p*l2_dmas_p-1:0] dma_pkt_v_lo, dma_pkt_ready_and_li;
  logic [num_cce_p*l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [num_cce_p*l2_dmas_p-1:0] dma_data_v_lo, dma_data_ready_and_li;
  logic [num_cce_p*l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [num_cce_p*l2_dmas_p-1:0] dma_data_v_li, dma_data_ready_and_lo;

  logic core_reset_li;
  bsg_sync_sync
   #(.width_p(1))
   core_reset_bss
    (.oclk_i(core_clk_i)
     ,.iclk_data_i(async_reset_i)
     ,.oclk_data_o(core_reset_li)
     );

  logic axi_reset_li;
  bsg_sync_sync
   #(.width_p(1))
   axi_reset_bss
    (.oclk_i(axi_clk_i)
     ,.iclk_data_i(async_reset_i)
     ,.oclk_data_o(axi_reset_li)
     );

  wire [did_width_p-1:0] my_did_li = 1'b1;
  wire [did_width_p-1:0] host_did_li = '1;
  bp_processor
   #(.bp_params_p(bp_params_p))
   processor
    (.clk_i(core_clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(core_reset_li)

     ,.my_did_i(my_did_li)
     ,.host_did_i(host_did_li)

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

  bp_bedrock_mem_fwd_header_s axi_mem_fwd_header_li;
  logic [bedrock_fill_width_p-1:0] axi_mem_fwd_data_li;
  logic axi_mem_fwd_v_li, axi_mem_fwd_ready_and_lo;
  bp_bedrock_mem_rev_header_s axi_mem_rev_header_lo;
  logic [bedrock_fill_width_p-1:0] axi_mem_rev_data_lo;
  logic axi_mem_rev_v_lo, axi_mem_rev_ready_and_li;
  bp_bedrock_mem_fwd_header_s axi_mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] axi_mem_fwd_data_lo;
  logic axi_mem_fwd_v_lo, axi_mem_fwd_ready_and_li;
  bp_bedrock_mem_rev_header_s axi_mem_rev_header_li;
  logic [bedrock_fill_width_p-1:0] axi_mem_rev_data_li;
  logic axi_mem_rev_v_li, axi_mem_rev_ready_and_lo;

  bsg_cache_dma_pkt_s [num_cce_p*l2_dmas_p-1:0] axi_dma_pkt_li;
  logic [num_cce_p*l2_dmas_p-1:0] axi_dma_pkt_v_li, axi_dma_pkt_yumi_lo;
  logic [num_cce_p*l2_dmas_p-1:0][axi_data_width_p-1:0] axi_dma_data_lo;
  logic [num_cce_p*l2_dmas_p-1:0] axi_dma_data_v_lo, axi_dma_data_ready_and_li;
  logic [num_cce_p*l2_dmas_p-1:0][axi_data_width_p-1:0] axi_dma_data_li;
  logic [num_cce_p*l2_dmas_p-1:0] axi_dma_data_v_li, axi_dma_data_yumi_lo;

  bp_me_axil_client
   #(.bp_params_p(bp_params_p)
     ,.axil_data_width_p(s_axil_data_width_p)
     ,.axil_addr_width_p(s_axil_addr_width_p)
     )
   axil2io
    (.clk_i(axi_clk_i)
     ,.reset_i(axi_reset_li)

     ,.mem_fwd_header_o(axi_mem_fwd_header_lo)
     ,.mem_fwd_data_o(axi_mem_fwd_data_lo)
     ,.mem_fwd_v_o(axi_mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(axi_mem_fwd_ready_and_li)

     ,.mem_rev_header_i(axi_mem_rev_header_li)
     ,.mem_rev_data_i(axi_mem_rev_data_li)
     ,.mem_rev_v_i(axi_mem_rev_v_li)
     ,.mem_rev_ready_and_o(axi_mem_rev_ready_and_lo)

     ,.lce_id_i(lce_id_width_p'('b10))
     ,.did_i(did_width_p'('1))
     ,.*
     );

  bp_me_axil_master
   #(.bp_params_p(bp_params_p)
     ,.axil_data_width_p(m_axil_data_width_p)
     ,.axil_addr_width_p(m_axil_addr_width_p)
     )
   io2axil
    (.clk_i(axi_clk_i)
     ,.reset_i(axi_reset_li)

     ,.mem_fwd_header_i(axi_mem_fwd_header_li)
     ,.mem_fwd_data_i(axi_mem_fwd_data_li)
     ,.mem_fwd_v_i(axi_mem_fwd_v_li)
     ,.mem_fwd_ready_and_o(axi_mem_fwd_ready_and_lo)

     ,.mem_rev_header_o(axi_mem_rev_header_lo)
     ,.mem_rev_data_o(axi_mem_rev_data_lo)
     ,.mem_rev_v_o(axi_mem_rev_v_lo)
     ,.mem_rev_ready_and_i(axi_mem_rev_ready_and_li)

     ,.*
     );

  logic [daddr_width_p-1:0] m_axi_awaddr_addr;
  logic [daddr_width_p-1:0] m_axi_araddr_addr;
  bsg_cache_to_axi
   #(.addr_width_p(daddr_width_p)
     ,.data_width_p(axi_data_width_p)
     ,.mask_width_p(l2_block_size_in_words_p)
     ,.block_size_in_words_p(l2_block_width_p/axi_data_width_p)
     ,.num_cache_p(num_cce_p*l2_dmas_p)
     ,.axi_data_width_p(axi_data_width_p)
     ,.axi_id_width_p(axi_id_width_p)
     ,.axi_burst_len_p(l2_block_width_p/axi_data_width_p)
     ,.axi_burst_type_p(e_axi_burst_incr)
     ,.ordering_en_p(1)
     )
   cache2axi
    (.clk_i(axi_clk_i)
     ,.reset_i(axi_reset_li)

     ,.dma_pkt_i(axi_dma_pkt_li)
     ,.dma_pkt_v_i(axi_dma_pkt_v_li)
     ,.dma_pkt_yumi_o(axi_dma_pkt_yumi_lo)

     ,.dma_data_o(axi_dma_data_lo)
     ,.dma_data_v_o(axi_dma_data_v_lo)
     ,.dma_data_ready_and_i(axi_dma_data_ready_and_li)

     ,.dma_data_i(axi_dma_data_li)
     ,.dma_data_v_i(axi_dma_data_v_li)
     ,.dma_data_yumi_o(axi_dma_data_yumi_lo)

     ,.axi_awid_o(m_axi_awid_o)
     ,.axi_awaddr_addr_o(m_axi_awaddr_addr)
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
     ,.axi_araddr_addr_o(m_axi_araddr_addr)
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

  assign m_axi_araddr_o = m_axi_araddr_addr;
  assign m_axi_awaddr_o = m_axi_awaddr_addr;

  if (axi_core_clk_async_p)
    begin : async
      // Input I/O interface
      logic axi_mem_fwd_out_full_lo;
      assign axi_mem_fwd_ready_and_li = ~axi_mem_fwd_out_full_lo;
      bsg_async_fifo
       #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+bedrock_fill_width_p), .lg_size_p(lg_async_fifo_size_lp))
       mem_fwd_iaf
        (.w_clk_i(axi_clk_i)
         ,.w_reset_i(axi_reset_li)

         ,.w_enq_i(axi_mem_fwd_ready_and_li & axi_mem_fwd_v_lo)
         ,.w_data_i({axi_mem_fwd_data_lo, axi_mem_fwd_header_lo})
         ,.w_full_o(axi_mem_fwd_out_full_lo)

         ,.r_clk_i(core_clk_i)
         ,.r_reset_i(core_reset_li)

         ,.r_deq_i(mem_fwd_ready_and_lo & mem_fwd_v_li)
         ,.r_data_o({mem_fwd_data_li, mem_fwd_header_li})
         ,.r_valid_o(mem_fwd_v_li)
         );

      logic mem_rev_out_full_lo;
      assign mem_rev_ready_and_li = ~mem_rev_out_full_lo;
      bsg_async_fifo
       #(.width_p($bits(bp_bedrock_mem_rev_header_s)+bedrock_fill_width_p), .lg_size_p(lg_async_fifo_size_lp))
       mem_rev_oaf
        (.w_clk_i(core_clk_i)
         ,.w_reset_i(core_reset_li)

         ,.w_enq_i(mem_rev_ready_and_li & mem_rev_v_lo)
         ,.w_data_i({mem_rev_data_lo, mem_rev_header_lo})
         ,.w_full_o(mem_rev_out_full_lo)

         ,.r_clk_i(axi_clk_i)
         ,.r_reset_i(axi_reset_li)

         ,.r_deq_i(axi_mem_rev_ready_and_lo & axi_mem_rev_v_li)
         ,.r_data_o({axi_mem_rev_data_li, axi_mem_rev_header_li})
         ,.r_valid_o(axi_mem_rev_v_li)
         );


      // Output I/O interface
      logic mem_fwd_out_full_lo;
      assign mem_fwd_ready_and_li = ~mem_fwd_out_full_lo;
      bsg_async_fifo
       #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+bedrock_fill_width_p), .lg_size_p(lg_async_fifo_size_lp))
       mem_fwd_oaf
        (.w_clk_i(core_clk_i)
         ,.w_reset_i(core_reset_li)

         ,.w_enq_i(mem_fwd_ready_and_li & mem_fwd_v_lo)
         ,.w_data_i({mem_fwd_data_lo, mem_fwd_header_lo})
         ,.w_full_o(mem_fwd_out_full_lo)

         ,.r_clk_i(axi_clk_i)
         ,.r_reset_i(axi_reset_li)

         ,.r_deq_i(axi_mem_fwd_ready_and_lo & axi_mem_fwd_v_li)
         ,.r_data_o({axi_mem_fwd_data_li, axi_mem_fwd_header_li})
         ,.r_valid_o(axi_mem_fwd_v_li)
         );

      logic axi_mem_rev_out_full_lo;
      assign axi_mem_rev_ready_and_li = ~axi_mem_rev_out_full_lo;
      bsg_async_fifo
       #(.width_p($bits(bp_bedrock_mem_rev_header_s)+bedrock_fill_width_p), .lg_size_p(lg_async_fifo_size_lp))
       mem_rev_iaf
        (.w_clk_i(axi_clk_i)
         ,.w_reset_i(axi_reset_li)

         ,.w_enq_i(axi_mem_rev_ready_and_li & axi_mem_rev_v_lo)
         ,.w_data_i({axi_mem_rev_data_lo, axi_mem_rev_header_lo})
         ,.w_full_o(axi_mem_rev_out_full_lo)

         ,.r_clk_i(core_clk_i)
         ,.r_reset_i(core_reset_li)

         ,.r_deq_i(mem_rev_ready_and_lo & mem_rev_v_li)
         ,.r_data_o({mem_rev_data_li, mem_rev_header_li})
         ,.r_valid_o(mem_rev_v_li)
         );

      // DMA interface
      logic dma_pkt_full_lo;
      assign dma_pkt_ready_and_li = ~dma_pkt_full_lo;
      bsg_async_fifo
       #(.width_p($bits(bsg_cache_dma_pkt_s)), .lg_size_p(lg_async_fifo_size_lp))
       dma_pkt_af
        (.w_clk_i(core_clk_i)
         ,.w_reset_i(core_reset_li)

         ,.w_enq_i(dma_pkt_ready_and_li & dma_pkt_v_lo)
         ,.w_data_i(dma_pkt_lo)
         ,.w_full_o(dma_pkt_full_lo)

         ,.r_clk_i(axi_clk_i)
         ,.r_reset_i(axi_reset_li)

         ,.r_deq_i(axi_dma_pkt_yumi_lo)
         ,.r_data_o(axi_dma_pkt_li)
         ,.r_valid_o(axi_dma_pkt_v_li)
         );

      logic dma_data_out_full_lo;
      assign dma_data_ready_and_li = ~dma_data_out_full_lo;
      bsg_async_fifo
       #(.width_p(l2_fill_width_p), .lg_size_p(lg_async_fifo_size_lp))
       dma_out_data_af
        (.w_clk_i(core_clk_i)
         ,.w_reset_i(core_reset_li)

         ,.w_enq_i(dma_data_ready_and_li & dma_data_v_lo)
         ,.w_data_i(dma_data_lo)
         ,.w_full_o(dma_data_out_full_lo)

         ,.r_clk_i(axi_clk_i)
         ,.r_reset_i(axi_reset_li)

         ,.r_deq_i(axi_dma_data_yumi_lo)
         ,.r_data_o(axi_dma_data_li)
         ,.r_valid_o(axi_dma_data_v_li)
         );

      logic axi_dma_in_full_lo;
      assign axi_dma_data_ready_and_li = ~axi_dma_in_full_lo;
      bsg_async_fifo
       #(.width_p(l2_fill_width_p), .lg_size_p(lg_async_fifo_size_lp))
       dma_in_data_af
        (.w_clk_i(axi_clk_i)
         ,.w_reset_i(axi_reset_li)

         ,.w_enq_i(axi_dma_data_ready_and_li & axi_dma_data_v_lo)
         ,.w_data_i(axi_dma_data_lo)
         ,.w_full_o(axi_dma_in_full_lo)

         ,.r_clk_i(core_clk_i)
         ,.r_reset_i(core_reset_li)

         ,.r_deq_i(dma_data_ready_and_lo & dma_data_v_li)
         ,.r_data_o(dma_data_li)
         ,.r_valid_o(dma_data_v_li)
         );
    end
  else
    begin : sync
      assign dma_data_li = axi_dma_data_lo;
      assign dma_data_v_li = axi_dma_data_v_lo;
      assign axi_dma_data_ready_and_li = dma_data_ready_and_lo;

      assign axi_dma_data_li = dma_data_lo;
      assign axi_dma_data_v_li = dma_data_v_lo;
      assign dma_data_ready_and_li = axi_dma_data_yumi_lo;

      assign axi_dma_pkt_li = dma_pkt_lo;
      assign axi_dma_pkt_v_li = dma_pkt_v_lo;
      assign dma_pkt_ready_and_li = axi_dma_pkt_yumi_lo;

      assign mem_fwd_header_li = axi_mem_fwd_header_lo;
      assign mem_fwd_data_li = axi_mem_fwd_data_lo;
      assign mem_fwd_v_li = axi_mem_fwd_v_lo;
      assign axi_mem_fwd_ready_and_li = mem_fwd_ready_and_lo;

      assign axi_mem_rev_header_li = mem_rev_header_lo;
      assign axi_mem_rev_data_li = mem_rev_data_lo;
      assign axi_mem_rev_v_li = mem_rev_v_lo;
      assign mem_rev_ready_and_li = axi_mem_rev_ready_and_lo;

      assign axi_mem_fwd_header_li = mem_fwd_header_lo;
      assign axi_mem_fwd_data_li = mem_fwd_data_lo;
      assign axi_mem_fwd_v_li = mem_fwd_v_lo;
      assign mem_fwd_ready_and_li = axi_mem_fwd_ready_and_lo;

      assign mem_rev_header_li = axi_mem_rev_header_lo;
      assign mem_rev_data_li = axi_mem_rev_data_lo;
      assign mem_rev_v_li = axi_mem_rev_v_lo;
      assign axi_mem_rev_ready_and_li = mem_rev_ready_and_lo;
    end

endmodule

