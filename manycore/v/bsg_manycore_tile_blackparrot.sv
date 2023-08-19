
`include "bsg_manycore_defines.vh"
`include "bp_common_defines.svh"

// This is the tile for a blackparrot core.
// The address map for external I/O is the same as for BP itself
// Address Map:
//   42'h000_0020_0000-42'h000_002f_ffff: CFG 
//                       42'h000_0020_0004: FREEZE
//                       42'h000_0020_0008: BOOT NPC
//                       42'h000_0020_000c: CORE ID
//                       42'h000_0020_0014: CORD
//                       42'h000_0020_001c: HIO MASK
//                       42'h000_0020_0200: ICACHE ID
//                       42'h000_0020_0204: ICACHE MODE
//                       42'h000_0020_0400: DCACHE ID
//                       42'h000_0020_0404: DCACHE MODE
//   42'h000_0030_0000-42'h000_003f_ffff: CLINT
//                       42'h000_0030_0000: MIPI
//                       42'h000_0030_4000: MTIMECMP
//                       42'h000_0030_8000: MTIMESEL
//                       42'h000_0030_bff8: MTIME
//                       42'h000_0030_b000: PLIC
//                       42'h000_0030_c000: DEBUG
//   42'h000_0040_0000-42'h000_004f_ffff: BRIDGE
//                       42'h000_0400_0000: DRAM OFFSET
//                       42'h000_0400_0004: DRAM POD
//                       42'h000_0400_0008: HOST CORD
//                       42'h000_0400_1000-
//                       42'h000_0400_1fff: SCRATCHPAD
//   42'h000_0050_0000-42'h000_005f_ffff: FIFO
//                       42'h000_0050_1000: REQ FIFO
//                       42'h000_0050_2000: REQ FIFO CREDITS
//                       42'h000_0050_3000: RESP FIFO
//                       42'h000_0050_4000: RESP FIFO ENTRIES
//                       42'h000_0050_5000: REQ FIFO
//                       42'h000_0050_6000: REQ FIFO ENTRIES
//                       42'h200_0000_0000-
//                       42'h2ff_ffff_ffff: MMIO VCACHE
//                       42'h300_0000_0000-
//                       42'h2ff_ffff_ffff: MMIO COMPUTE
//

module bsg_manycore_tile_blackparrot
 import bsg_manycore_pkg::*;
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_x_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_y_cord_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(icache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(num_vcache_rows_p)
   , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(vcache_size_p)
   , parameter `BSG_INV_PARAM(vcache_sets_p)
   , parameter `BSG_INV_PARAM(num_tiles_x_p)
   , parameter `BSG_INV_PARAM(num_tiles_y_p)
   , parameter `BSG_INV_PARAM(scratchpad_els_p)

   , localparam link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
   )
  (input                                       clk_i
   , input                                     rt_clk_i
   , input                                     reset_i

   , input [3:0][x_cord_width_p-1:0]           global_x_i
   , input [3:0][y_cord_width_p-1:0]           global_y_i

   , input [3:0][link_sif_width_lp-1:0]        link_sif_i
   , output logic [3:0][link_sif_width_lp-1:0] link_sif_o
   );

  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  bp_cfg_bus_s cfg_bus_lo; 

  localparam num_proc_lp = 3;
  localparam lg_num_proc_lp = `BSG_SAFE_CLOG2(num_proc_lp);
  localparam num_dev_lp = 8;
  localparam lg_num_dev_lp = `BSG_SAFE_CLOG2(num_dev_lp);

  wire [mem_noc_did_width_p-1:0]  my_did_li = '0;
  wire [mem_noc_did_width_p-1:0]  host_did_li = '0;
  wire [coh_noc_cord_width_p-1:0] my_cord_li = global_y_i[0+:`BSG_SAFE_CLOG2(num_tiles_y_p)] >> 2;

  // {IO CMD, BE UCE, FE UCE}
  bp_bedrock_mem_fwd_header_s [num_proc_lp-1:0] proc_fwd_header_lo;
  logic [num_proc_lp-1:0][bedrock_fill_width_p-1:0] proc_fwd_data_lo;
  logic [num_proc_lp-1:0] proc_fwd_v_lo, proc_fwd_ready_and_li;
  bp_bedrock_mem_rev_header_s [num_proc_lp-1:0] proc_rev_header_li;
  logic [num_proc_lp-1:0][bedrock_fill_width_p-1:0] proc_rev_data_li;
  logic [num_proc_lp-1:0] proc_rev_v_li, proc_rev_ready_and_lo;

  // {LOOPBACK, DRAM1, DRAM0, MMIO, FIFO, BRIDGE, CLINT, CFG}
  bp_bedrock_mem_fwd_header_s [num_dev_lp-1:0] dev_fwd_header_li;
  logic [num_dev_lp-1:0][bedrock_fill_width_p-1:0] dev_fwd_data_li;
  logic [num_dev_lp-1:0] dev_fwd_v_li, dev_fwd_ready_and_lo;
  bp_bedrock_mem_rev_header_s [num_dev_lp-1:0] dev_rev_header_lo;
  logic [num_dev_lp-1:0][bedrock_fill_width_p-1:0] dev_rev_data_lo;
  logic [num_dev_lp-1:0] dev_rev_v_lo, dev_rev_ready_and_li;

  logic debug_irq_li, timer_irq_li, software_irq_li, m_external_irq_li, s_external_irq_li;
  bp_unicore_lite
   #(.bp_params_p(bp_params_p))
   blackparrot
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_lo)

     ,.mem_fwd_header_o(proc_fwd_header_lo[0+:2])
     ,.mem_fwd_data_o(proc_fwd_data_lo[0+:2])
     ,.mem_fwd_v_o(proc_fwd_v_lo[0+:2])
     ,.mem_fwd_ready_and_i(proc_fwd_ready_and_li[0+:2])

     ,.mem_rev_header_i(proc_rev_header_li[0+:2])
     ,.mem_rev_data_i(proc_rev_data_li[0+:2])
     ,.mem_rev_v_i(proc_rev_v_li[0+:2])
     ,.mem_rev_ready_and_o(proc_rev_ready_and_lo[0+:2])

     ,.debug_irq_i(debug_irq_li)
     ,.timer_irq_i(timer_irq_li)
     ,.software_irq_i(software_irq_li)
     ,.m_external_irq_i(m_external_irq_li)
     ,.s_external_irq_i(s_external_irq_li)
     );

  localparam mc_host_dev_gp   = 1;
  localparam mc_cfg_dev_gp    = 2;
  localparam mc_clint_dev_gp  = 3;
  localparam mc_bridge_dev_gp = 4;
  localparam mc_fifo_dev_gp   = 5;

  logic [2:0][lg_num_dev_lp-1:0] proc_fwd_dst_lo;
  logic dram_select_n, dram_select_r;
  for (genvar i = 0; i < 3; i++)
    begin : fwd_dest
      bp_local_addr_s local_addr;
      assign local_addr = proc_fwd_header_lo[i].addr;
      wire [dev_id_width_gp-1:0] device_fwd_li = local_addr.dev;
      wire local_fwd_li = (proc_fwd_header_lo[i].addr < dram_base_addr_gp);
      wire is_mc_addr = proc_fwd_header_lo[i].addr[paddr_width_p-1-:1] == 1'b1;

      wire is_host_fwd      =  local_fwd_li & (device_fwd_li == mc_host_dev_gp);
      wire is_cfg_fwd       =  local_fwd_li & (device_fwd_li == mc_cfg_dev_gp);
      wire is_clint_fwd     =  local_fwd_li & (device_fwd_li == mc_clint_dev_gp);
      wire is_bridge_fwd    =  local_fwd_li & (device_fwd_li == mc_bridge_dev_gp);
      wire is_fifo_fwd      =  local_fwd_li & (device_fwd_li == mc_fifo_dev_gp);

      wire vcache_row_id = local_addr[2+`BSG_SAFE_CLOG2(vcache_block_size_in_words_p*num_tiles_x_p)+:1];

      wire is_dram0_fwd     = ~local_fwd_li & ~is_mc_addr & ~vcache_row_id;
      wire is_dram1_fwd     = ~local_fwd_li & ~is_mc_addr &  vcache_row_id; 
      wire is_mmio_fwd      = is_mc_addr | is_host_fwd;
      wire is_loopback_fwd  =  local_fwd_li & ~is_host_fwd & ~is_cfg_fwd & ~is_fifo_fwd & ~is_clint_fwd & ~is_bridge_fwd;

      bsg_encode_one_hot
       #(.width_p(num_dev_lp), .lo_to_hi_p(1))
       fwd_pe
        (.i({is_loopback_fwd, is_dram1_fwd, is_dram0_fwd, is_mmio_fwd, is_fifo_fwd, is_bridge_fwd, is_clint_fwd, is_cfg_fwd})
         ,.addr_o(proc_fwd_dst_lo[i])
         ,.v_o()
         );
    end

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.block_width_p(bedrock_block_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.stream_mask_p(mem_fwd_stream_mask_gp)
     ,.num_source_p(3)
     ,.num_sink_p(8)
     )
   fwd_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     
     ,.msg_header_i(proc_fwd_header_lo)
     ,.msg_data_i(proc_fwd_data_lo)
     ,.msg_v_i(proc_fwd_v_lo)
     ,.msg_ready_and_o(proc_fwd_ready_and_li)
     ,.msg_dst_i(proc_fwd_dst_lo)
     
     ,.msg_header_o(dev_fwd_header_li)
     ,.msg_data_o(dev_fwd_data_li)
     ,.msg_v_o(dev_fwd_v_li)
     ,.msg_ready_and_i(dev_fwd_ready_and_lo)
     );

  // Select destination of responses. Were there a way to transpose structs...
  logic [num_dev_lp-1:0][lg_num_proc_lp-1:0] dev_rev_dst_lo;
  assign dev_rev_dst_lo[7] = dev_rev_header_lo[7].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_rev_dst_lo[6] = dev_rev_header_lo[6].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_rev_dst_lo[5] = dev_rev_header_lo[5].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_rev_dst_lo[4] = dev_rev_header_lo[4].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_rev_dst_lo[3] = dev_rev_header_lo[3].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_rev_dst_lo[2] = dev_rev_header_lo[2].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_rev_dst_lo[1] = dev_rev_header_lo[1].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_rev_dst_lo[0] = dev_rev_header_lo[0].payload.lce_id[0+:lg_num_proc_lp];

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.block_width_p(bedrock_block_width_p)
     ,.stream_mask_p(mem_rev_stream_mask_gp)
     ,.num_source_p(8)
     ,.num_sink_p(3)
     )
   rev_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     
     ,.msg_header_i(dev_rev_header_lo)
     ,.msg_data_i(dev_rev_data_lo)
     ,.msg_v_i(dev_rev_v_lo)
     ,.msg_ready_and_o(dev_rev_ready_and_li)
     ,.msg_dst_i(dev_rev_dst_lo)
     
     ,.msg_header_o(proc_rev_header_li)
     ,.msg_data_o(proc_rev_data_li)
     ,.msg_v_o(proc_rev_v_li)
     ,.msg_ready_and_i(proc_rev_ready_and_lo)
     );

  bp_me_cfg_slice
   #(.bp_params_p(bp_params_p))
   cfgs
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[0])
     ,.mem_fwd_data_i(dev_fwd_data_li[0])
     ,.mem_fwd_v_i(dev_fwd_v_li[0])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[0])

     ,.mem_rev_header_o(dev_rev_header_lo[0])
     ,.mem_rev_data_o(dev_rev_data_lo[0])
     ,.mem_rev_v_o(dev_rev_v_lo[0])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[0])

     ,.cfg_bus_o(cfg_bus_lo)
     ,.did_i(my_did_li)
     ,.host_did_i(host_did_li)
     ,.cord_i(my_cord_li)

     ,.cce_ucode_v_o()
     ,.cce_ucode_w_o()
     ,.cce_ucode_addr_o()
     ,.cce_ucode_data_o()
     ,.cce_ucode_data_i('0)
     );

  bp_me_clint_slice
   #(.bp_params_p(bp_params_p))
   clint
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_lo)

     ,.mem_fwd_header_i(dev_fwd_header_li[1])
     ,.mem_fwd_data_i(dev_fwd_data_li[1])
     ,.mem_fwd_v_i(dev_fwd_v_li[1])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[1])

     ,.mem_rev_header_o(dev_rev_header_lo[1])
     ,.mem_rev_data_o(dev_rev_data_lo[1])
     ,.mem_rev_v_o(dev_rev_v_lo[1])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[1])

     ,.debug_irq_o(debug_irq_li)
     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.m_external_irq_o(m_external_irq_li)
     ,.s_external_irq_o(s_external_irq_li)
     );

  logic [pod_y_cord_width_p+pod_x_cord_width_p-1:0] dram_pod_lo;
  logic [addr_width_p-1:0] dram_offset_lo;
  logic [x_cord_width_p+y_cord_width_p-1:0] my_cord_lo;
  logic [x_cord_width_p+y_cord_width_p-1:0] host_cord_lo;
  bp_me_manycore_bridge
   #(.bp_params_p(bp_params_p)
     ,.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.pod_x_cord_width_p(pod_x_cord_width_p)
     ,.pod_y_cord_width_p(pod_y_cord_width_p)
     ,.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.scratchpad_els_p(scratchpad_els_p)
     )
   bridge_csr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[2])
     ,.mem_fwd_data_i(dev_fwd_data_li[2])
     ,.mem_fwd_v_i(dev_fwd_v_li[2])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[2])

     ,.mem_rev_header_o(dev_rev_header_lo[2])
     ,.mem_rev_data_o(dev_rev_data_lo[2])
     ,.mem_rev_v_o(dev_rev_v_lo[2])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[2])

     ,.dram_pod_o(dram_pod_lo)
     ,.dram_offset_o(dram_offset_lo)
     ,.my_cord_o(my_cord_lo)
     ,.host_cord_o(host_cord_lo)
     );

  wire [x_cord_width_p-1:0] mmio_x_li = global_x_i[0];
  wire [y_cord_width_p-1:0] mmio_y_li = global_y_i[0];
  bp_me_manycore_mmio
   #(.bp_params_p(bp_params_p)
     ,.x_cord_width_p(x_cord_width_p)
     ,.pod_x_cord_width_p(pod_x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.pod_y_cord_width_p(pod_y_cord_width_p)
     ,.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
     ,.num_vcache_rows_p(num_vcache_rows_p)
     ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
     ,.vcache_size_p(vcache_size_p)
     ,.vcache_sets_p(vcache_sets_p)
     ,.num_tiles_x_p(num_tiles_x_p)
     ,.num_tiles_y_p(num_tiles_y_p)
     ,.outstanding_words_p(32)
     )
   mmio_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[4])
     ,.mem_fwd_data_i(dev_fwd_data_li[4])
     ,.mem_fwd_v_i(dev_fwd_v_li[4])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[4])

     ,.mem_rev_header_o(dev_rev_header_lo[4])
     ,.mem_rev_data_o(dev_rev_data_lo[4])
     ,.mem_rev_v_o(dev_rev_v_lo[4])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[4])

     ,.mem_fwd_header_o(proc_fwd_header_lo[2])
     ,.mem_fwd_data_o(proc_fwd_data_lo[2])
     ,.mem_fwd_v_o(proc_fwd_v_lo[2])
     ,.mem_fwd_ready_and_i(proc_fwd_ready_and_li[2])

     ,.mem_rev_header_i(proc_rev_header_li[2])
     ,.mem_rev_data_i(proc_rev_data_li[2])
     ,.mem_rev_v_i(proc_rev_v_li[2])
     ,.mem_rev_ready_and_o(proc_rev_ready_and_lo[2])

     ,.link_sif_i(link_sif_i[0])
     ,.link_sif_o(link_sif_o[0])

     ,.host_x_i(host_cord_lo[y_cord_width_p+:x_cord_width_p])
     ,.host_y_i(host_cord_lo[0+:y_cord_width_p])
     ,.global_x_i(mmio_x_li)
     ,.global_y_i(mmio_y_li)
     );

  wire [x_cord_width_p-1:0] fifo_x_li = global_x_i[1];
  wire [y_cord_width_p-1:0] fifo_y_li = global_y_i[1];
  bp_me_manycore_fifo
   #(.bp_params_p(bp_params_p)
     ,.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
     )
   fifo_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[3])
     ,.mem_fwd_data_i(dev_fwd_data_li[3])
     ,.mem_fwd_v_i(dev_fwd_v_li[3])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[3])

     ,.mem_rev_header_o(dev_rev_header_lo[3])
     ,.mem_rev_data_o(dev_rev_data_lo[3])
     ,.mem_rev_v_o(dev_rev_v_lo[3])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[3])

     ,.link_sif_i(link_sif_i[1])
     ,.link_sif_o(link_sif_o[1])

     ,.global_x_i(fifo_x_li)
     ,.global_y_i(fifo_y_li)
     );

  for (genvar i = 0; i < 2; i++)
    begin : d
      wire [x_cord_width_p-1:0] dram_x_li = global_x_i[2+i];
      wire [y_cord_width_p-1:0] dram_y_li = global_y_i[2+i];
      bp_me_manycore_dram
       #(.bp_params_p(bp_params_p)
         ,.x_cord_width_p(x_cord_width_p)
         ,.pod_x_cord_width_p(pod_x_cord_width_p)
         ,.y_cord_width_p(y_cord_width_p)
         ,.pod_y_cord_width_p(pod_y_cord_width_p)
         ,.data_width_p(data_width_p)
         ,.addr_width_p(addr_width_p)
         ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
         ,.num_vcache_rows_p(num_vcache_rows_p)
         ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
         ,.vcache_size_p(vcache_size_p)
         ,.vcache_sets_p(vcache_sets_p)
         ,.num_tiles_x_p(num_tiles_x_p)
         ,.num_tiles_y_p(num_tiles_y_p)
         ,.outstanding_words_p(32)
         )
       dram_link
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.mem_fwd_header_i(dev_fwd_header_li[5+i])
         ,.mem_fwd_data_i(dev_fwd_data_li[5+i])
         ,.mem_fwd_v_i(dev_fwd_v_li[5+i])
         ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[5+i])

         ,.mem_rev_header_o(dev_rev_header_lo[5+i])
         ,.mem_rev_data_o(dev_rev_data_lo[5+i])
         ,.mem_rev_v_o(dev_rev_v_lo[5+i])
         ,.mem_rev_ready_and_i(dev_rev_ready_and_li[5+i])

         ,.link_sif_i(link_sif_i[2+i])
         ,.link_sif_o(link_sif_o[2+i])

         ,.dram_pod_i(dram_pod_lo)
         ,.dram_offset_i(dram_offset_lo)
         ,.global_x_i(dram_x_li)
         ,.global_y_i(dram_y_li)
         );
    end

  bp_me_loopback
   #(.bp_params_p(bp_params_p))
   loopback
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[7])
     ,.mem_fwd_data_i(dev_fwd_data_li[7])
     ,.mem_fwd_v_i(dev_fwd_v_li[7])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[7])

     ,.mem_rev_header_o(dev_rev_header_lo[7])
     ,.mem_rev_data_o(dev_rev_data_lo[7])
     ,.mem_rev_v_o(dev_rev_v_lo[7])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[7])
     );

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_tile_blackparrot)

