
`include "bp_common_defines.svh"
`include "bsg_manycore_defines.svh"

module bp_me_manycore_mmio
 import bp_common_pkg::*;
 import bsg_manycore_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_y_cord_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(icache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(vcache_size_p)
   , parameter `BSG_INV_PARAM(vcache_sets_p)
   , parameter `BSG_INV_PARAM(num_tiles_x_p)
   , localparam x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
   , parameter `BSG_INV_PARAM(num_tiles_y_p)
   , localparam y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)

   , parameter `BSG_INV_PARAM(outstanding_words_p)

   , localparam mc_link_sif_width_lp =
       `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)

   , localparam debug_p = 0
   )
  (input                                        clk_i
   , input                                      reset_i

   , input [mem_fwd_header_width_lp-1:0]        mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]           mem_fwd_data_i
   , input                                      mem_fwd_v_i
   , output logic                               mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0] mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]    mem_rev_data_o
   , output logic                               mem_rev_v_o
   , input                                      mem_rev_ready_and_i

   , output logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]    mem_fwd_data_o
   , output logic                               mem_fwd_v_o
   , input                                      mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]        mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]           mem_rev_data_i
   , input                                      mem_rev_v_i
   , output logic                               mem_rev_ready_and_o

   , input [mc_link_sif_width_lp-1:0]           link_sif_i
   , output logic [mc_link_sif_width_lp-1:0]    link_sif_o

   , input [x_cord_width_p-1:0]                 host_x_i
   , input [y_cord_width_p-1:0]                 host_y_i
   , input [x_cord_width_p-1:0]                 global_x_i
   , input [y_cord_width_p-1:0]                 global_y_i
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  bsg_manycore_packet_s                    packet_lo;
  logic                                    packet_v_lo;
  logic                                    packet_yumi_li;

  bsg_manycore_return_packet_s             return_packet_li;
  logic                                    return_packet_v_li;

  bsg_manycore_packet_s                    packet_li;
  logic                                    packet_v_li;
  logic                                    packet_ready_lo;

  bsg_manycore_return_packet_s             return_packet_lo;
  logic                                    return_packet_v_lo;
  logic                                    return_packet_yumi_li;
  logic                                    return_packet_fifo_full_lo;

  logic [5:0]                              out_credits_used_lo;
  bsg_manycore_endpoint_fc
   #(.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.fifo_els_p(4)
     ,.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
     )
   blackparrot_endpoint
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.link_sif_i(link_sif_i)
     ,.link_sif_o(link_sif_o)

     //--------------------------------------------------------
     // 1. in_request signal group
     ,.packet_o(packet_lo)
     ,.packet_v_o(packet_v_lo)
     ,.packet_yumi_i(packet_yumi_li)

     //--------------------------------------------------------
     // 2. out_response signal group
     //    responses that will send back to the network
     ,.return_packet_i(return_packet_li)
     ,.return_packet_v_i(return_packet_v_li)

     //--------------------------------------------------------
     // 3. out_request signal group
     //    request that will send to the network
     ,.packet_i(packet_li)
     ,.packet_v_i(packet_v_li)
     ,.packet_credit_or_ready_o(packet_ready_lo)

     //--------------------------------------------------------
     // 4. in_response signal group
     //    responses that send back from the network
     //    the node shold always be ready to receive this response.
     ,.return_packet_o(return_packet_lo)
     ,.return_packet_v_o(return_packet_v_lo)
     ,.return_packet_yumi_i(return_packet_yumi_li)
     ,.return_packet_fifo_full_o()

     ,.out_credits_used_o(out_credits_used_lo)
     );

  // Other MMIO
  localparam tile_addr_width_lp = 18;
  wire [addr_width_p-1:0]      mmio_tile_epa_lo = mem_fwd_header_cast_i.addr[2+:tile_addr_width_lp-2];
  wire [x_cord_width_p-1:0] mmio_tile_x_cord_lo = mem_fwd_header_cast_i.addr[tile_addr_width_lp+:x_cord_width_p];
  wire [y_cord_width_p-1:0] mmio_tile_y_cord_lo = mem_fwd_header_cast_i.addr[tile_addr_width_lp+x_cord_width_p+:y_cord_width_p];

  localparam vcache_addr_width_lp = 29;
  wire [vcache_addr_width_lp-1:0] mmio_vcache_epa_lo     = mem_fwd_header_cast_i.addr[2+:vcache_addr_width_lp-2];
  wire [x_cord_width_p-1:0]    mmio_vcache_x_cord_lo     = mem_fwd_header_cast_i.addr[vcache_addr_width_lp+:x_cord_width_p];
  // If we have extra address space it goes to y_pod. Additionally, we drop the low bit because all vcache pods are even
  wire [pod_y_cord_width_p-1:0] mmio_vcache_y_pod_lo     = (mem_fwd_header_cast_i.addr[paddr_width_p-2:vcache_addr_width_lp+x_cord_width_p] << 1);
  wire [y_subcord_width_lp-1:0] mmio_vcache_y_subcord_lo = (mmio_vcache_y_pod_lo[1] == '0) ? '1 : '0;
  wire [y_cord_width_p-1:0] mmio_vcache_y_cord_lo        = {mmio_vcache_y_pod_lo, mmio_vcache_y_subcord_lo};

  wire [addr_width_p-1:0] host_epa_lo = mem_fwd_header_cast_i.addr[2+:addr_width_p];

  logic [(data_width_p>>3)-1:0] store_mask;
  always_comb
    case (mem_fwd_header_cast_i.size)
       e_bedrock_msg_size_1: store_mask = 4'h1 << mem_fwd_header_cast_i.addr[0+:2];
       e_bedrock_msg_size_2: store_mask = 4'h3 << mem_fwd_header_cast_i.addr[0+:2];
       // e_bedrock_msg_size_4:
       default:              store_mask = 4'hf << mem_fwd_header_cast_i.addr[0+:2];
    endcase

  localparam trans_id_width_lp = `BSG_SAFE_CLOG2(outstanding_words_p);
  logic [trans_id_width_lp-1:0] trans_id_lo;
  logic trans_id_v_lo, trans_id_yumi_li;
  logic [data_width_p-1:0] mmio_rev_data_lo;
  logic [trans_id_width_lp-1:0] mmio_rev_id_lo;
  logic mmio_rev_v_lo, mmio_rev_yumi_li;
  logic mmio_returned_v_li;

  wire [bsg_manycore_reg_id_width_gp-1:0] mmio_returned_reg_id_li = return_packet_lo.reg_id;
  wire [data_width_p-1:0] mmio_returned_data_li = return_packet_lo.data;
  bsg_fifo_reorder
   #(.width_p(data_width_p), .els_p(outstanding_words_p))
   return_data_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.fifo_alloc_id_o(trans_id_lo[0+:trans_id_width_lp])
     ,.fifo_alloc_v_o(trans_id_v_lo)
     ,.fifo_alloc_yumi_i(trans_id_yumi_li)

     // We write an entry on credit return in order to determine when to send
     //   back a store response.  A little inefficent, but allocating storage for
     //   worst case (all loads) isn't unreasonable
     ,.write_id_i(mmio_returned_reg_id_li[0+:trans_id_width_lp])
     ,.write_data_i(mmio_returned_data_li)
     ,.write_v_i(mmio_returned_v_li)

     ,.fifo_deq_data_o(mmio_rev_data_lo)
     ,.fifo_deq_id_o(mmio_rev_id_lo)
     ,.fifo_deq_v_o(mmio_rev_v_lo)
     ,.fifo_deq_yumi_i(mmio_rev_yumi_li)

     ,.empty_o()
     );

  bp_bedrock_mem_rev_header_s mmio_rev_header_lo;
  bsg_mem_1r1w
   #(.width_p($bits(mem_fwd_header_i)), .els_p(outstanding_words_p))
   return_headers
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)

     ,.w_v_i(trans_id_yumi_li)
     ,.w_addr_i(trans_id_lo)
     ,.w_data_i(mem_fwd_header_i)

     ,.r_v_i(mmio_rev_yumi_li)
     ,.r_addr_i(mmio_rev_id_lo)
     ,.r_data_o(mmio_rev_header_lo)
     );

  logic [data_width_p-1:0] store_payload;
  logic [bsg_manycore_reg_id_width_gp-1:0] store_reg_id;
  bsg_manycore_packet_op_e store_op;
  bsg_manycore_reg_id_encode
   #(.data_width_p(data_width_p))
   reg_id_encode
    (.data_i(mem_fwd_data_i[0+:word_width_gp])
     ,.mask_i(store_mask)
     ,.reg_id_i(bsg_manycore_reg_id_width_gp'(trans_id_lo))

     ,.data_o(store_payload)
     ,.reg_id_o(store_reg_id)
     ,.op_o(store_op)
     );

  //////////////////////////////////////////////
  // Outgoing Request
  //////////////////////////////////////////////
  wire is_mc_compute_tile_li = mem_fwd_v_i & mem_fwd_header_cast_i.addr[paddr_width_p-1-:2] == 2'b11;
  wire is_mc_vcache_tile_li  = mem_fwd_v_i & mem_fwd_header_cast_i.addr[paddr_width_p-1-:2] == 2'b10;

  always_comb
    begin
      mem_fwd_ready_and_o = trans_id_v_lo & packet_ready_lo;
      trans_id_yumi_li = mem_fwd_ready_and_o & mem_fwd_v_i;
      packet_v_li = trans_id_yumi_li;

      packet_li = '0;
      packet_li.src_y_cord = global_y_i;
      packet_li.src_x_cord = global_x_i;
      if (is_mc_compute_tile_li)
        begin
          packet_li.addr   = mmio_tile_epa_lo;
          packet_li.y_cord = mmio_tile_y_cord_lo;
          packet_li.x_cord = mmio_tile_x_cord_lo;
        end
      else if (is_mc_vcache_tile_li)
        begin
          packet_li.addr   = mmio_vcache_epa_lo;
          packet_li.y_cord = mmio_vcache_y_cord_lo;
          packet_li.x_cord = mmio_vcache_x_cord_lo;
        end
      else // Send to host
        begin
          packet_li.addr   = host_epa_lo;
          packet_li.y_cord = host_y_i;
          packet_li.x_cord = host_x_i;
        end

      case (mem_fwd_header_cast_i.msg_type)
        e_bedrock_mem_uc_rd, e_bedrock_mem_rd:
          begin
            packet_li.op_v2                                    = e_remote_load;
            packet_li.payload.load_info_s.load_info.is_byte_op = (mem_fwd_header_cast_i.size == e_bedrock_msg_size_1);
            packet_li.payload.load_info_s.load_info.is_hex_op  = (mem_fwd_header_cast_i.size == e_bedrock_msg_size_2);
            packet_li.payload.load_info_s.load_info.part_sel   = mem_fwd_header_cast_i.addr[0+:2];
            packet_li.reg_id                                   = bsg_manycore_reg_id_width_gp'(trans_id_lo);
          end
        e_bedrock_mem_amo:
          begin
            packet_li.payload.data = mem_fwd_data_i;
            packet_li.reg_id = bsg_manycore_reg_id_width_gp'(trans_id_lo);
            unique case (mem_fwd_header_cast_i.subop)
              e_bedrock_amoadd:  packet_li.op_v2               = e_remote_amoadd;
              e_bedrock_amoor:   packet_li.op_v2               = e_remote_amoor;
              e_bedrock_amoswap: packet_li.op_v2               = e_remote_amoswap;
              default: packet_li.op_v2 = e_remote_amoswap; // Must never come here
            endcase
          end
        default: // e_bedrock_mem_uc_wr, e_bedrock_mem_wr:
          begin
            packet_li.op_v2                                    = store_op;
            packet_li.payload.data                             = store_payload;
            packet_li.reg_id                                   = store_reg_id;
          end
      endcase

      // We can always ack mmio requests, because we've allocated space in the reorder fifo
      return_packet_yumi_li = return_packet_v_lo;
      mmio_returned_v_li = return_packet_yumi_li;

      mem_rev_v_o = mmio_rev_v_lo;
      mem_rev_header_cast_o = mmio_rev_header_lo;
      mmio_rev_yumi_li = mem_rev_ready_and_i & mem_rev_v_o;
    end

  localparam sel_width_lp = `BSG_SAFE_CLOG2(dword_width_gp>>3);
  localparam size_width_lp = `BSG_SAFE_CLOG2(sel_width_lp);
  bsg_bus_pack
   #(.in_width_p(data_width_p), .out_width_p(bedrock_fill_width_p))
   fwd_bus_pack
    (.data_i(mmio_rev_data_lo)
     ,.sel_i('0) // We are aligned
     ,.size_i(mem_rev_header_cast_o.size[0+:size_width_lp])
     ,.data_o(mem_rev_data_o)
     );

  //////////////////////////////////////////////
  // Incoming packet
  //////////////////////////////////////////////
  // BP EPA Map
  // dev:
  //      1 -- HOST
  //      2 -- CFG
  //      3 -- CLINT
  //      4 -- BRIDGE
  //      5 -- FIFO
  typedef struct packed
  {
    logic [3:0]  dev;
    logic [11:0] addr;
  }  bp_epa_s;

  // MUST be kept in sync with bsg_manycore_blackparrot_tile
  localparam mc_host_dev_base_addr_gp   = 32'h0010_0000;
  localparam mc_cfg_dev_base_addr_gp    = 32'h0020_0000;
  localparam mc_clint_dev_base_addr_gp  = 32'h0030_0000;
  localparam mc_bridge_dev_base_addr_gp = 32'h0040_0000;
  localparam mc_fifo_dev_base_addr_gp   = 32'h0050_0000;

  bp_epa_s in_epa_li;
  always_comb
    begin
      mem_fwd_header_cast_o = '0;
      mem_fwd_header_cast_o.payload.lce_id = 2'b10; // Always 2'b10 for I/O
      mem_fwd_header_cast_o.payload.src_did[0+:x_cord_width_p] = packet_lo.src_x_cord;
      mem_fwd_header_cast_o.payload.src_did[x_cord_width_p+:y_cord_width_p] = packet_lo.src_y_cord;
      mem_fwd_header_cast_o.payload.src_did[x_cord_width_p+y_cord_width_p+:5] = packet_lo.reg_id;
      mem_fwd_header_cast_o.msg_type = (packet_lo.op_v2 inside {e_remote_load}) ? e_bedrock_mem_uc_rd : e_bedrock_mem_uc_wr;
      // TODO: we only support 32-bit loads and stores to BP configuration addresses
      mem_fwd_header_cast_o.size = e_bedrock_msg_size_4;
      mem_fwd_data_o = packet_lo.payload;

      mem_fwd_v_o = packet_v_lo;
      packet_yumi_li = mem_fwd_ready_and_i & mem_fwd_v_o;

      // Assumes alignment
      in_epa_li = packet_lo.addr << 2'b10;
      case (in_epa_li.dev)
        4'h1: mem_fwd_header_cast_o.addr = mc_host_dev_base_addr_gp + in_epa_li.addr;
        4'h2: mem_fwd_header_cast_o.addr = mc_cfg_dev_base_addr_gp + in_epa_li.addr;
        4'h3: mem_fwd_header_cast_o.addr = mc_clint_dev_base_addr_gp + in_epa_li.addr;
        4'h4: mem_fwd_header_cast_o.addr = mc_bridge_dev_base_addr_gp + in_epa_li.addr;
        4'h5: mem_fwd_header_cast_o.addr = mc_fifo_dev_base_addr_gp + in_epa_li.addr;
        // default to bridge address, which will return in case of erroneous packet
        default : mem_fwd_header_cast_o.addr = mc_bridge_dev_base_addr_gp + in_epa_li.addr;
      endcase
    end

  //////////////////////////////////////////////
  // Return to incoming packet
  //////////////////////////////////////////////
  always_comb
    begin
      // Returning data is always "ready" (but please don't randomly respond)
      mem_rev_ready_and_o = 1'b1;
      return_packet_v_li = mem_rev_ready_and_o & mem_rev_v_i;
      // TODO: Handle subword ops, float / ifetch ops
      return_packet_li.pkt_type = (mem_rev_header_cast_i.msg_type inside {e_bedrock_mem_uc_wr}) ? e_return_credit : e_return_int_wb;
      return_packet_li.data = mem_rev_data_i;
      return_packet_li.x_cord = mem_rev_header_cast_i.payload.src_did[0+:x_cord_width_p];
      return_packet_li.y_cord = mem_rev_header_cast_i.payload.src_did[x_cord_width_p+:y_cord_width_p];
      return_packet_li.reg_id = mem_rev_header_cast_i.payload.src_did[x_cord_width_p+y_cord_width_p+:5];
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_manycore_mmio)

