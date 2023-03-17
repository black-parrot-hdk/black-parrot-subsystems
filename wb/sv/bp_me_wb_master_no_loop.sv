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
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , parameter  data_width_p        = dword_width_gp
    , parameter  block_width_p       = cce_block_width_p
    , parameter  return_fifo_els_p   = 4
    , localparam bus_bytes_lp        = data_width_p >> 3
    , localparam wbone_addr_width_lp = paddr_width_p - `BSG_SAFE_CLOG2(bus_bytes_lp)
  )
  (   input                                      clk_i
    , input                                      reset_i

    // BP signals
    , input  [mem_fwd_header_width_lp-1:0]       mem_fwd_header_i
    , input  [data_width_p-1:0]                  mem_fwd_data_i
    , input                                      mem_fwd_v_i
    , output logic                               mem_fwd_ready_and_o
    , input                                      mem_fwd_last_i

    , output logic [mem_rev_header_width_lp-1:0] mem_rev_header_o
    , output logic [data_width_p-1:0]            mem_rev_data_o
    , output logic                               mem_rev_v_o
    , input                                      mem_rev_ready_and_i
    , output logic                               mem_rev_last_o

    // WB signals
    , output logic [wbone_addr_width_lp-1:0]     adr_o
    , output logic [data_width_p-1:0]            dat_o
    , output logic                               cyc_o
    , output logic                               stb_o
    , output logic [bus_bytes_lp-1:0]            sel_o
    , output logic                               we_o
    , output logic [2:0]                         cti_o
    , output logic [1:0]                         bte_o

    , input  [data_width_p-1:0]                  dat_i
    , input                                      ack_i
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);

  // input pump
  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [paddr_width_p-1:0] mem_fwd_addr_li;
  logic [data_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_v_li;
  logic mem_fwd_last_li;
  bp_me_stream_pump_in
    #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(data_width_p)
     ,.block_width_p(block_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_payload_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_payload_mask_gp | mem_rev_payload_mask_gp)
     ,.header_els_p(2)
     ,.data_els_p(`BSG_MAX(2, block_width_p/data_width_p))
    )
    pump_in
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(mem_fwd_header_i)
     ,.msg_data_i(mem_fwd_data_i)
     ,.msg_v_i(mem_fwd_v_i)
     ,.msg_last_i(mem_fwd_last_i)
     ,.msg_ready_and_o(mem_fwd_ready_and_o)

     ,.fsm_header_o(mem_fwd_header_li)
     ,.fsm_addr_o(mem_fwd_addr_li)
     ,.fsm_data_o(mem_fwd_data_li)
     ,.fsm_v_o(mem_fwd_v_li)
     ,.fsm_yumi_i(ack_i & cyc_o & stb_o)
     ,.fsm_new_o(/* unused */)
     ,.fsm_cnt_o(/* unused */)
     ,.fsm_last_o(mem_fwd_last_li)
    );

  // output pump
  logic mem_rev_ready_and_li;
  bp_me_stream_pump_out
    #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(data_width_p)
     ,.block_width_p(block_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_payload_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_payload_mask_gp | mem_rev_payload_mask_gp)
    )
    pump_out
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(mem_rev_header_o)
     ,.msg_data_o(mem_rev_data_o)
     ,.msg_v_o(mem_rev_v_o)
     ,.msg_last_o(mem_rev_last_o)
     ,.msg_ready_and_i(mem_rev_ready_and_i)

     ,.fsm_header_i(return_fifo_header_li)
     ,.fsm_addr_o(/* unused */)
     ,.fsm_data_i(return_fifo_data_li)
     ,.fsm_v_i(return_fifo_v_li)
     ,.fsm_ready_and_o(mem_rev_ready_and_li)
     ,.fsm_cnt_o(/* unused */)
     ,.fsm_new_o(/* unused */)
     ,.fsm_last_o(/* unused */)
    );

  // return fifo to convert from ready->valid to ready&valid
  logic [mem_rev_header_width_lp-1:0] return_fifo_header_li;
  logic [data_width_p-1:0] return_fifo_data_li;
  logic return_fifo_v_li;
  logic return_fifo_ready_and_li;
  bsg_fifo_1r1w_small
    #(.width_p(mem_rev_header_width_lp + data_width_p)
     ,.els_p(return_fifo_els_p)
    )
    return_fifo
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({mem_fwd_header_li, mem_rev_data_lo})
     ,.v_i(ack_i & cyc_o & stb_o)
     ,.ready_o(return_fifo_ready_and_li)

     ,.data_o({return_fifo_header_li, return_fifo_data_li})
     ,.v_o(return_fifo_v_li)
     ,.yumi_i(mem_rev_ready_and_li & return_fifo_v_li)
    );

  // for BP, less than bus width data must be replicated
  localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(bus_bytes_lp));
  wire [size_width_lp-1:0] resp_size = mem_fwd_header_li.size > {size_width_lp{1'b1}}
                                          ? {size_width_lp{1'b1}}
                                          : mem_fwd_header_li.size;
  logic [data_width_p-1:0] mem_rev_data_lo;
  bsg_bus_pack
    #(
      .in_width_p(data_width_p)
    )
    bus_pack(
      .data_i(dat_i)
     ,.sel_i('0)
     ,.size_i(resp_size)
     ,.data_o(mem_rev_data_lo)
    );

  localparam stream_words_lp = block_width_p / data_width_p;
  localparam stream_cnt_width_lp = `BSG_SAFE_CLOG2(stream_words_lp);
  wire [stream_cnt_width_lp-1:0] stream_size =
    `BSG_MAX((1'b1 << mem_fwd_header_li.size) / bus_bytes_lp, 1'b1) - 1'b1;
  always_comb begin
    // WB handshake signals
    cyc_o = mem_fwd_v_li;
    stb_o = mem_fwd_v_li & return_fifo_ready_and_li;

    // WB non-handshake signals
    adr_o = mem_fwd_addr_li[paddr_width_p-1:`BSG_SAFE_CLOG2(bus_bytes_lp)];
    dat_o = mem_fwd_data_li;
    unique case (mem_fwd_header_li.size)
      e_bedrock_msg_size_1: sel_o = (bus_bytes_lp)'('h1);
      e_bedrock_msg_size_2: sel_o = (bus_bytes_lp)'('h3);
      e_bedrock_msg_size_4: sel_o = (bus_bytes_lp)'('hF);
      // >= e_bedrock_msg_size_8:
      default: sel_o = (bus_bytes_lp)'('hFF);
    endcase
    we_o = (mem_fwd_header_li.msg_type == e_bedrock_mem_uc_wr);

    // WB registered feedback signals
    priority case (stream_size)
      // only 4, 8 and 16 beat wrapped bursts are supported by WB
      (stream_cnt_width_lp)'('h3): bte_o = 2'b01;
      (stream_cnt_width_lp)'('h7): bte_o = 2'b10;
      (stream_cnt_width_lp)'('hF): bte_o = 2'b11;
      // 2'b00 would encode a linear burst, but we only use wrapped bursts
      default: bte_o = 2'b00;
    endcase
    if (bte_o == 2'b00)
      // no burst, classic cycle
      cti_o = 3'b000;
    else if (mem_fwd_last_li)
      // end-of-burst
      cti_o = 3'b111;
    else
      // incrementing burst
      cti_o = 3'b010;
  end

  // assertions
  initial begin
    assert(data_width_p inside {8, 16, 32, 64})
      else $error("Data width must be 8, 16, 32 or 64 bits");
    assert(data_width_p == 64)
      else $display("Adapter untested for data widths other than 64 bits. Use with caution");
  end

  always_ff @(negedge clk_i) begin
    assert(reset_i !== '0 || ~mem_fwd_v_i
           || mem_fwd_header_cast_i.addr[0+:`BSG_SAFE_CLOG2(bus_bytes_lp)] == '0)
      else $error("Command address not aligned to bus width");
    assert(reset_i !== '0 || ~mem_fwd_v_i
           || mem_fwd_header_cast_i.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_uc_rd})
      else $error("Command message type must be uncached");
  end
endmodule
