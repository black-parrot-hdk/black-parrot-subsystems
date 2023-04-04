/*
 * Name:
 *  bp_me_wb_client.sv
 *
 * Description:
 *  This module converts BlackParrot (BP) Bedrock commands to Wishbone (WB)
 *  for client devices, follwoing the Wishbone B4 specification
 *  (https://cdn.opencores.org/downloads/wbspec_b4.pdf).
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_wb_defines.svh"

module bp_me_wb_client
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  import bsg_wb_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
    `declare_bsg_wb_widths(paddr_width_p, data_width_p)

    , parameter data_width_p = dword_width_gp
  )
  (   input                                      clk_i
    , input                                      reset_i

    // BP signals
    , input  [lce_id_width_p-1:0]                lce_id_i
    , input  [did_width_p-1:0]                   did_i

    , output logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_o
    , output logic [data_width_p-1:0]            mem_fwd_data_o
    , output logic                               mem_fwd_v_o
    , input                                      mem_fwd_ready_and_i
    , output logic                               mem_fwd_last_o

    , input  [mem_rev_header_width_lp-1:0]       mem_rev_header_i
    , input  [data_width_p-1:0]                  mem_rev_data_i
    , input                                      mem_rev_v_i
    , output logic                               mem_rev_ready_and_o
    , input                                      mem_rev_last_i

    // WB signals
    , input  [wb_adr_width_lp-1:0]               adr_i
    , input  [data_width_p-1:0]                  dat_i
    , input                                      cyc_i
    , input                                      stb_i
    , input  [wb_sel_width_lp-1:0]               sel_i
    , input                                      we_i

    , output logic [data_width_p-1:0]            dat_o
    , output logic                               ack_o
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  // for BP, less than bus width data must be replicated
  localparam size_width_lp = wb_sel_width_log_lp;
  bp_bedrock_msg_size_e msg_size;
  wire [size_width_lp-1:0] cmd_size = msg_size;
  bsg_bus_pack
    #(
      .in_width_p(data_width_p)
    )
    bus_pack(
      .data_i(dat_i)
     ,.sel_i('0)
     ,.size_i(cmd_size)
     ,.data_o(mem_fwd_data_o)
    );

  logic mem_fwd_sent_n, mem_fwd_sent_r;
  logic [data_width_p-1:0] dat_n;
  logic ack_n;
  always_comb begin
    // BP handshake signals
    mem_fwd_v_o         = cyc_i & stb_i & ~mem_fwd_sent_r;
    mem_rev_ready_and_o = 1'b1;
    mem_fwd_last_o      = 1'b1;

    // check if BP command was already sent
    mem_fwd_sent_n = mem_fwd_sent_r;
    if (mem_fwd_v_o & mem_fwd_ready_and_i)
      mem_fwd_sent_n = 1'b1;
    else if (ack_o)
      mem_fwd_sent_n = 1'b0;

    // WB handshake signals
    ack_n = mem_rev_v_i;
  
    // BP non-handshake signals
    unique case (sel_i)
      (wb_sel_width_lp)'('h1): msg_size = e_bedrock_msg_size_1;
      (wb_sel_width_lp)'('h3): msg_size = e_bedrock_msg_size_2;
      (wb_sel_width_lp)'('hF): msg_size = e_bedrock_msg_size_4;
      // (wb_sel_width_lp)'('hFF):
      default: msg_size = e_bedrock_msg_size_8;
    endcase
    mem_fwd_data_o                       = dat_i;
    mem_fwd_header_cast_o                = '0;
    mem_fwd_header_cast_o.addr           = {adr_i, (wb_sel_width_log_lp)'('b0)};
    mem_fwd_header_cast_o.size           = msg_size;
    mem_fwd_header_cast_o.payload.lce_id = lce_id_i;
    mem_fwd_header_cast_o.payload.did    = did_i;
    mem_fwd_header_cast_o.msg_type       = we_i
                                           ? e_bedrock_mem_uc_wr
                                           : e_bedrock_mem_uc_rd;

    // WB non-handshake signals
    dat_n = mem_rev_data_i;
  end

  // advance to next state
  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      ack_o       <= '0;
      dat_o       <= '0;
      mem_fwd_sent_r <= '0;
    end
    else begin
      ack_o       <= ack_n;
      dat_o       <= dat_n;
      mem_fwd_sent_r <= mem_fwd_sent_n;
    end
  end

  // assertions
  initial begin
    assert(data_width_p inside {8, 16, 32, 64})
      else $error("Data width must be 8, 16, 32 or 64 bits");
    assert(data_width_p == 64)
      else $display("Adapter untested for data widths other than 64 bits. Use with caution");
  end
endmodule
