/*
 * Name:
 *   bp_axi4_top.sv
 *
 * Description:
 *   This module wraps a BP processor with AXI4 interfaces on both of its I/O interfaces
 *   and the memory interface. Ordering and flow control of traffic is enforced by
 *   the bp_me_axi_manager|subordinate modules.
 *
 * Constraints:
 *   This wrapper supports 8, 16, 32, and 64-bit AXI I/O operations on AXI interfaces
 *   with 64-bit data channel width. Only one inbound or outbound I/O operation is
 *   processed at a time (i.e., all I/O is serialized) to guarantee correctness.
 *
 *   bedrock_fill_width_p and m|s_axi_data_width_p must all be 64-bits
 *   Incoming I/O (s_axi_*) transactions must be no larger than 64-bits in a single
 *   transfer and the address must be naturally aligned to the request size. The I/O
 *   converters do not check or enforce this condition, the sender must guarantee it.
 *   Outbound I/O (m_axi_*) generates transactions no larger than 64-bits with a single
 *   data transfer using naturally aligned addresses and the INCR burst type.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_axi4_top
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_axi_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(m_axi_addr_width_p)
   , parameter `BSG_INV_PARAM(m_axi_data_width_p)
   , parameter `BSG_INV_PARAM(m_axi_id_width_p)
   , localparam m_axi_mask_width_lp = m_axi_data_width_p>>3

   , parameter `BSG_INV_PARAM(s_axi_addr_width_p)
   , parameter `BSG_INV_PARAM(s_axi_data_width_p)
   , parameter `BSG_INV_PARAM(s_axi_id_width_p)
   , localparam s_axi_mask_width_lp = s_axi_data_width_p>>3

   , parameter `BSG_INV_PARAM(m01_axi_addr_width_p)
   , parameter `BSG_INV_PARAM(m01_axi_data_width_p)
   , parameter `BSG_INV_PARAM(m01_axi_id_width_p)
   , localparam m01_axi_mask_width_lp = m01_axi_data_width_p>>3

   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   )
  (// clk and reset are associated with the AXI interfaces (aclk and ~aresetn)
   input                                       clk_i
   , input                                     reset_i
   , input                                     rt_clk_i

   , input [did_width_p-1:0]                   my_did_i
   , input [did_width_p-1:0]                   host_did_i

   //======================== Outgoing I/O ========================
   , output logic [m_axi_addr_width_p-1:0]     m_axi_awaddr_o
   , output logic                              m_axi_awvalid_o
   , input                                     m_axi_awready_i
   , output logic [m_axi_id_width_p-1:0]       m_axi_awid_o
   , output logic                              m_axi_awlock_o
   , output logic [3:0]                        m_axi_awcache_o
   , output logic [2:0]                        m_axi_awprot_o
   , output logic [7:0]                        m_axi_awlen_o
   , output logic [2:0]                        m_axi_awsize_o
   , output logic [1:0]                        m_axi_awburst_o
   , output logic [3:0]                        m_axi_awqos_o
   , output logic [3:0]                        m_axi_awregion_o

   , output logic [m_axi_data_width_p-1:0]     m_axi_wdata_o
   , output logic                              m_axi_wvalid_o
   , input                                     m_axi_wready_i
   , output logic                              m_axi_wlast_o
   , output logic [m_axi_mask_width_lp-1:0]    m_axi_wstrb_o

   , input                                     m_axi_bvalid_i
   , output logic                              m_axi_bready_o
   , input [m_axi_id_width_p-1:0]              m_axi_bid_i
   , input [1:0]                               m_axi_bresp_i

   , output logic [m_axi_addr_width_p-1:0]     m_axi_araddr_o
   , output logic                              m_axi_arvalid_o
   , input                                     m_axi_arready_i
   , output logic [m_axi_id_width_p-1:0]       m_axi_arid_o
   , output logic                              m_axi_arlock_o
   , output logic [3:0]                        m_axi_arcache_o
   , output logic [2:0]                        m_axi_arprot_o
   , output logic [7:0]                        m_axi_arlen_o
   , output logic [2:0]                        m_axi_arsize_o
   , output logic [1:0]                        m_axi_arburst_o
   , output logic [3:0]                        m_axi_arqos_o
   , output logic [3:0]                        m_axi_arregion_o

   , input [m_axi_data_width_p-1:0]            m_axi_rdata_i
   , input                                     m_axi_rvalid_i
   , output logic                              m_axi_rready_o
   , input [m_axi_id_width_p-1:0]              m_axi_rid_i
   , input                                     m_axi_rlast_i
   , input [1:0]                               m_axi_rresp_i

   //======================== Incoming I/O ========================
   , input [s_axi_addr_width_p-1:0]            s_axi_awaddr_i
   , input                                     s_axi_awvalid_i
   , output logic                              s_axi_awready_o
   , input [s_axi_id_width_p-1:0]              s_axi_awid_i
   , input                                     s_axi_awlock_i
   , input [3:0]                               s_axi_awcache_i
   , input [2:0]                               s_axi_awprot_i
   , input [7:0]                               s_axi_awlen_i
   , input [2:0]                               s_axi_awsize_i
   , input [1:0]                               s_axi_awburst_i
   , input [3:0]                               s_axi_awqos_i
   , input [3:0]                               s_axi_awregion_i

   , input [s_axi_data_width_p-1:0]            s_axi_wdata_i
   , input                                     s_axi_wvalid_i
   , output logic                              s_axi_wready_o
   , input                                     s_axi_wlast_i
   , input [s_axi_mask_width_lp-1:0]           s_axi_wstrb_i

   , output logic                              s_axi_bvalid_o
   , input                                     s_axi_bready_i
   , output logic [s_axi_id_width_p-1:0]       s_axi_bid_o
   , output logic [1:0]                        s_axi_bresp_o

   , input [s_axi_addr_width_p-1:0]            s_axi_araddr_i
   , input                                     s_axi_arvalid_i
   , output logic                              s_axi_arready_o
   , input [s_axi_id_width_p-1:0]              s_axi_arid_i
   , input                                     s_axi_arlock_i
   , input [3:0]                               s_axi_arcache_i
   , input [2:0]                               s_axi_arprot_i
   , input [7:0]                               s_axi_arlen_i
   , input [2:0]                               s_axi_arsize_i
   , input [1:0]                               s_axi_arburst_i
   , input [3:0]                               s_axi_arqos_i
   , input [3:0]                               s_axi_arregion_i

   , output logic [s_axi_data_width_p-1:0]     s_axi_rdata_o
   , output logic                              s_axi_rvalid_o
   , input                                     s_axi_rready_i
   , output logic [s_axi_id_width_p-1:0]       s_axi_rid_o
   , output logic                              s_axi_rlast_o
   , output logic [1:0]                        s_axi_rresp_o

   //======================== Outgoing Memory ========================
   , output logic [m01_axi_addr_width_p-1:0]   m01_axi_awaddr_o
   , output logic                              m01_axi_awvalid_o
   , input                                     m01_axi_awready_i
   , output logic [m01_axi_id_width_p-1:0]     m01_axi_awid_o
   , output logic                              m01_axi_awlock_o
   , output logic [3:0]                        m01_axi_awcache_o
   , output logic [2:0]                        m01_axi_awprot_o
   , output logic [7:0]                        m01_axi_awlen_o
   , output logic [2:0]                        m01_axi_awsize_o
   , output logic [1:0]                        m01_axi_awburst_o
   , output logic [3:0]                        m01_axi_awqos_o
   , output logic [3:0]                        m01_axi_awregion_o

   , output logic [m01_axi_data_width_p-1:0]   m01_axi_wdata_o
   , output logic                              m01_axi_wvalid_o
   , input                                     m01_axi_wready_i
   , output logic                              m01_axi_wlast_o
   , output logic [m01_axi_mask_width_lp-1:0]  m01_axi_wstrb_o

   , input                                     m01_axi_bvalid_i
   , output logic                              m01_axi_bready_o
   , input [m01_axi_id_width_p-1:0]            m01_axi_bid_i
   , input [1:0]                               m01_axi_bresp_i

   , output logic [m01_axi_addr_width_p-1:0]   m01_axi_araddr_o
   , output logic                              m01_axi_arvalid_o
   , input                                     m01_axi_arready_i
   , output logic [m01_axi_id_width_p-1:0]     m01_axi_arid_o
   , output logic                              m01_axi_arlock_o
   , output logic [3:0]                        m01_axi_arcache_o
   , output logic [2:0]                        m01_axi_arprot_o
   , output logic [7:0]                        m01_axi_arlen_o
   , output logic [2:0]                        m01_axi_arsize_o
   , output logic [1:0]                        m01_axi_arburst_o
   , output logic [3:0]                        m01_axi_arqos_o
   , output logic [3:0]                        m01_axi_arregion_o

   , input [m01_axi_data_width_p-1:0]          m01_axi_rdata_i
   , input                                     m01_axi_rvalid_i
   , output logic                              m01_axi_rready_o
   , input [m01_axi_id_width_p-1:0]            m01_axi_rid_i
   , input                                     m01_axi_rlast_i
   , input [1:0]                               m01_axi_rresp_i
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
  bsg_cache_dma_pkt_s [num_cce_p*l2_banks_p-1:0] dma_pkt_lo;
  logic [num_cce_p*l2_banks_p-1:0] dma_pkt_v_lo, dma_pkt_ready_and_li;
  logic [num_cce_p*l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [num_cce_p*l2_banks_p-1:0] dma_data_v_lo, dma_data_ready_and_li;
  logic [num_cce_p*l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [num_cce_p*l2_banks_p-1:0] dma_data_v_li, dma_data_ready_and_lo;

  bp_processor
   #(.bp_params_p(bp_params_p))
   processor
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)

     ,.my_did_i(my_did_i)
     ,.host_did_i(host_did_i)

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

  bp_me_axi_subordinate
   #(.bp_params_p(bp_params_p)
     ,.s_axi_data_width_p(s_axi_data_width_p)
     ,.s_axi_addr_width_p(s_axi_addr_width_p)
     ,.s_axi_id_width_p(s_axi_id_width_p)
     )
   axi2io
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_o(mem_fwd_header_li)
     ,.mem_fwd_data_o(mem_fwd_data_li)
     ,.mem_fwd_v_o(mem_fwd_v_li)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_lo)

     ,.mem_rev_header_i(mem_rev_header_lo)
     ,.mem_rev_data_i(mem_rev_data_lo)
     ,.mem_rev_v_i(mem_rev_v_lo)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_li)

     // IDs for the I/O sender
     ,.lce_id_i(lce_id_width_p'('b10))
     ,.did_i(did_width_p'('1))
     ,.*
     );

  bp_me_axi_manager
   #(.bp_params_p(bp_params_p)
     ,.m_axi_data_width_p(m_axi_data_width_p)
     ,.m_axi_addr_width_p(m_axi_addr_width_p)
     ,.m_axi_id_width_p(m_axi_id_width_p)
     )
   io2axi
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

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

  logic [num_cce_p*l2_banks_p-1:0][m01_axi_data_width_p-1:0] axi_dma_data_lo;
  logic [num_cce_p*l2_banks_p-1:0] axi_dma_data_v_lo, axi_dma_data_ready_and_li;
  logic [num_cce_p*l2_banks_p-1:0][m01_axi_data_width_p-1:0] axi_dma_data_li;
  logic [num_cce_p*l2_banks_p-1:0] axi_dma_data_v_li, axi_dma_data_yumi_lo;
  for (genvar i = 0; i < num_cce_p*l2_banks_p; i++)
    begin : narrow
      bsg_serial_in_parallel_out_full
       #(.width_p(m01_axi_data_width_p), .els_p(l2_fill_width_p/m01_axi_data_width_p))
       dma_piso
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(axi_dma_data_lo[i])
         ,.v_i(axi_dma_data_v_lo[i])
         ,.ready_and_o(axi_dma_data_ready_and_li[i])

         ,.data_o(dma_data_li[i])
         ,.v_o(dma_data_v_li[i])
         ,.yumi_i(dma_data_ready_and_lo[i] & dma_data_v_li[i])
         );

      bsg_parallel_in_serial_out
       #(.width_p(m01_axi_data_width_p), .els_p(l2_fill_width_p/m01_axi_data_width_p))
       dma_sipo
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

  bsg_cache_to_axi
   #(.addr_width_p(daddr_width_p)
     ,.data_width_p(m01_axi_data_width_p)
     ,.mask_width_p(l2_block_size_in_words_p)
     ,.block_size_in_words_p(l2_block_width_p/m01_axi_data_width_p)
     ,.num_cache_p(num_cce_p*l2_banks_p)
     ,.axi_data_width_p(m01_axi_data_width_p)
     ,.axi_id_width_p(m01_axi_id_width_p)
     ,.axi_burst_len_p(l2_block_width_p/m01_axi_data_width_p)
     ,.axi_burst_type_p(e_axi_burst_incr)
     ,.ordering_en_p(0)
     )
   cache2axi
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dma_pkt_i(dma_pkt_lo)
     ,.dma_pkt_v_i(dma_pkt_v_lo)
     ,.dma_pkt_yumi_o(dma_pkt_ready_and_li)

     ,.dma_data_o(axi_dma_data_lo)
     ,.dma_data_v_o(axi_dma_data_v_lo)
     ,.dma_data_ready_and_i(axi_dma_data_ready_and_li)

     ,.dma_data_i(axi_dma_data_li)
     ,.dma_data_v_i(axi_dma_data_v_li)
     ,.dma_data_yumi_o(axi_dma_data_yumi_lo)

     ,.axi_awid_o(m01_axi_awid_o)
     ,.axi_awaddr_addr_o(m01_axi_awaddr_o)
     ,.axi_awlen_o(m01_axi_awlen_o)
     ,.axi_awsize_o(m01_axi_awsize_o)
     ,.axi_awburst_o(m01_axi_awburst_o)
     ,.axi_awcache_o(m01_axi_awcache_o)
     ,.axi_awprot_o(m01_axi_awprot_o)
     ,.axi_awlock_o(m01_axi_awlock_o)
     ,.axi_awvalid_o(m01_axi_awvalid_o)
     ,.axi_awready_i(m01_axi_awready_i)

     ,.axi_wdata_o(m01_axi_wdata_o)
     ,.axi_wstrb_o(m01_axi_wstrb_o)
     ,.axi_wlast_o(m01_axi_wlast_o)
     ,.axi_wvalid_o(m01_axi_wvalid_o)
     ,.axi_wready_i(m01_axi_wready_i)

     ,.axi_bid_i(m01_axi_bid_i)
     ,.axi_bresp_i(m01_axi_bresp_i)
     ,.axi_bvalid_i(m01_axi_bvalid_i)
     ,.axi_bready_o(m01_axi_bready_o)

     ,.axi_arid_o(m01_axi_arid_o)
     ,.axi_araddr_addr_o(m01_axi_araddr_o)
     ,.axi_arlen_o(m01_axi_arlen_o)
     ,.axi_arsize_o(m01_axi_arsize_o)
     ,.axi_arburst_o(m01_axi_arburst_o)
     ,.axi_arcache_o(m01_axi_arcache_o)
     ,.axi_arprot_o(m01_axi_arprot_o)
     ,.axi_arlock_o(m01_axi_arlock_o)
     ,.axi_arvalid_o(m01_axi_arvalid_o)
     ,.axi_arready_i(m01_axi_arready_i)

     ,.axi_rid_i(m01_axi_rid_i)
     ,.axi_rdata_i(m01_axi_rdata_i)
     ,.axi_rresp_i(m01_axi_rresp_i)
     ,.axi_rlast_i(m01_axi_rlast_i)
     ,.axi_rvalid_i(m01_axi_rvalid_i)
     ,.axi_rready_o(m01_axi_rready_o)

     // Unused
     ,.axi_awaddr_cache_id_o()
     ,.axi_araddr_cache_id_o()
     );

  assign m01_axi_awqos_o = '0;
  assign m01_axi_awregion_o = '0;
  assign m01_axi_arqos_o = '0;
  assign m01_axi_arregion_o = '0;

endmodule

