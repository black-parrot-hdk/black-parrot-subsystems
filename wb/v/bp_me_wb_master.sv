/*
 * Name:
 *  bp_me_wb_master.sv
 *
 * Description:
 *  This module converts BlackParrot (BP) Bedrock commands to Wishbone (WB)
 *  for master devices, follwoing the Wishbone B4 specification
 *  (https://cdn.opencores.org/downloads/wbspec_b4.pdf).
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_wb_master
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_wb_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , parameter `BSG_INV_PARAM(wb_data_width_p)
   , parameter `BSG_INV_PARAM(wb_addr_width_p)
   , localparam wb_mask_width_lp = wb_data_width_p >> 3
   , localparam wb_sel_width_lp = `BSG_SAFE_CLOG2(wb_mask_width_lp)
   , localparam wb_size_width_lp = `BSG_WIDTH(wb_sel_width_lp)
   , localparam wb_adr_width_lp = paddr_width_p - wb_sel_width_lp
   )
  (input                                        clk_i
   , input                                      reset_i

   // BP signals
   , input [mem_fwd_header_width_lp-1:0]        mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]           mem_fwd_data_i
   , input                                      mem_fwd_v_i
   , output logic                               mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0] mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]    mem_rev_data_o
   , output logic                               mem_rev_v_o
   , input                                      mem_rev_ready_and_i

   // WB signals
   , output logic [wb_adr_width_lp-1:0]         adr_o
   , output logic [wb_data_width_p-1:0]         dat_o
   , output logic                               cyc_o
   , output logic                               stb_o
   , output logic [wb_mask_width_lp-1:0]        sel_o
   , output logic                               we_o
   , output logic [1:0]                         cti_o
   , output logic [2:0]                         bte_o

   , input [wb_data_width_p-1:0]                dat_i
   , input                                      ack_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);

  // input pump
  bp_bedrock_mem_fwd_header_s fsm_fwd_header_lo;
  logic [wb_data_width_p-1:0] fsm_fwd_data_lo;
  logic fsm_fwd_v_lo, fsm_fwd_yumi_li;
  logic [paddr_width_p-1:0] fsm_fwd_addr_lo;
  logic fsm_fwd_new_lo, fsm_fwd_critical_lo, fsm_fwd_last_lo;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.fsm_data_width_p(wb_data_width_p)
     ,.block_width_p(bedrock_block_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     )
   pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(mem_fwd_header_i)
     ,.msg_data_i(mem_fwd_data_i)
     ,.msg_v_i(mem_fwd_v_i)
     ,.msg_ready_and_o(mem_fwd_ready_and_o)

     ,.fsm_header_o(fsm_fwd_header_lo)
     ,.fsm_data_o(fsm_fwd_data_lo)
     ,.fsm_v_o(fsm_fwd_v_lo)
     ,.fsm_yumi_i(fsm_fwd_yumi_li)
     ,.fsm_addr_o(fsm_fwd_addr_lo)
     ,.fsm_new_o(fsm_fwd_new_lo)
     ,.fsm_critical_o(fsm_fwd_critical_lo)
     ,.fsm_last_o(fsm_fwd_last_lo)
     );

  // output pump
  bp_bedrock_mem_rev_header_s fsm_rev_header_li;
  logic [wb_data_width_p-1:0] fsm_rev_data_li;
  logic fsm_rev_v_li, fsm_rev_yumi_lo;
  logic [paddr_width_p-1:0] fsm_rev_addr_lo;
  logic fsm_rev_new_lo, fsm_rev_critical_lo, fsm_rev_last_lo;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.fsm_data_width_p(wb_data_width_p)
     ,.block_width_p(bedrock_block_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     )
   pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(mem_rev_header_o)
     ,.msg_data_o(mem_rev_data_o)
     ,.msg_v_o(mem_rev_v_o)
     ,.msg_ready_and_i(mem_rev_ready_and_i)

     ,.fsm_header_i(fsm_rev_header_li)
     ,.fsm_data_i(fsm_rev_data_li)
     ,.fsm_v_i(fsm_rev_v_li)
     ,.fsm_yumi_o(fsm_rev_yumi_lo)
     ,.fsm_addr_o(fsm_rev_addr_lo)
     ,.fsm_new_o(fsm_rev_new_lo)
     ,.fsm_critical_o(fsm_rev_critical_lo)
     ,.fsm_last_o(fsm_rev_last_lo)
     );

  // return fifo to convert from ready->valid to ready&valid
  wire [mem_rev_header_width_lp-1:0] return_fifo_header_li = fsm_fwd_header_lo;
  wire [wb_data_width_p-1:0] return_fifo_data_li = dat_i;
  logic return_fifo_ready_and_li, return_fifo_v_lo;
  logic [wb_data_width_p-1:0] wb_rev_data_li;
  bsg_two_fifo
   #(.width_p(mem_rev_header_width_lp+wb_data_width_p))
   return_fifo
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({return_fifo_header_li, return_fifo_data_li})
     ,.v_i(return_fifo_v_lo)
     ,.ready_o(return_fifo_ready_and_li)

     ,.data_o({fsm_rev_header_li, wb_rev_data_li})
     ,.v_o(fsm_rev_v_li)
     ,.yumi_i(fsm_rev_yumi_lo)
    );

  // for BP, less than bus width data must be replicated
  wire [wb_size_width_lp-1:0] resp_size =
    fsm_rev_header_li.size > {wb_size_width_lp{1'b1}} ? '1 : fsm_rev_header_li.size;
  wire [wb_size_width_lp-1:0] byte_offset = fsm_fwd_addr_lo[0+:wb_size_width_lp];
  bsg_bus_pack
   #(.in_width_p(wb_data_width_p), .out_width_p(bedrock_fill_width_p))
   bus_pack
    (.data_i(wb_rev_data_li)
     ,.sel_i(byte_offset)
     ,.size_i(resp_size)
     ,.data_o(fsm_rev_data_li)
     );

  localparam stream_words_lp = bedrock_block_width_p / wb_data_width_p;
  localparam stream_cnt_width_lp = `BSG_SAFE_CLOG2(stream_words_lp);
  wire [stream_cnt_width_lp-1:0] stream_size =
    `BSG_MAX((1'b1 << fsm_fwd_header_lo.size) / wb_sel_width_lp, 1'b1) - 1'b1;
  always_comb begin
    // WB handshake signals
    cyc_o = fsm_fwd_v_lo & return_fifo_ready_and_li;
    stb_o = cyc_o;

    // BP handshake signals
    // Dequeue only when wishbone beat completes
    fsm_fwd_yumi_li = ack_i & cyc_o & stb_o;
    return_fifo_v_lo = fsm_fwd_yumi_li;

    // WB non-handshake signals
    adr_o = fsm_fwd_addr_lo[paddr_width_p-1:wb_sel_width_lp];
    dat_o = fsm_fwd_data_lo;
    unique case (fsm_fwd_header_lo.size)
      e_bedrock_msg_size_1: sel_o = 'h1 << byte_offset;
      e_bedrock_msg_size_2: sel_o = 'h3 << byte_offset;
      e_bedrock_msg_size_4: sel_o = 'hF << byte_offset;
      // >= e_bedrock_msg_size_8:
      default: sel_o = 'hFF << byte_offset;
    endcase
    we_o = (fsm_fwd_header_lo.msg_type == e_bedrock_mem_uc_wr);

    // WB registered feedback signals
    unique case (stream_size)
      // only 4, 8 and 16 beat wrapped bursts are supported by WB
      'h3: bte_o = e_wb_4_beat_wrap_burst;
      'h7: bte_o = e_wb_8_beat_wrap_burst;
      'hF: bte_o = e_wb_16_beat_wrap_burst;
      default: bte_o = e_wb_linear_burst;
    endcase

    if (fsm_fwd_last_lo)
      cti_o = e_wb_end_of_burst;
    else
      cti_o = e_wb_inc_addr_burst;
  end

  // assertions
  if (!(wb_data_width_p inside {8, 16, 32, 64}))
    $error("Data width must be 8, 16, 32 or 64 bits");
  if (!(wb_data_width_p == 64))
    $error("Adapter untested for data widths other than 64 bits. Use with caution");

  always_ff @(negedge clk_i)
    begin
      assert (reset_i !== '0 || ~mem_fwd_v_i || mem_fwd_header_cast_i.addr[0+:wb_sel_width_lp] == '0)
        else $error("Command address not aligned to bus width");
      assert (reset_i !== '0 || ~mem_fwd_v_i || mem_fwd_header_cast_i.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_uc_rd})
        else $error("Command message type must be uncached");
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_wb_master)

