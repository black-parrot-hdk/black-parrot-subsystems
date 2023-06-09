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

module bp_me_wb_client
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
   , input [lce_id_width_p-1:0]                 lce_id_i
   , input [did_width_p-1:0]                    did_i

   , output logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]    mem_fwd_data_o
   , output logic                               mem_fwd_v_o
   , input                                      mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]        mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]           mem_rev_data_i
   , input                                      mem_rev_v_i
   , output logic                               mem_rev_ready_and_o

   // WB signals
   , input [wb_adr_width_lp-1:0]                adr_i
   , input [wb_data_width_p-1:0]                dat_i
   , input                                      cyc_i
   , input                                      stb_i
   , input [wb_mask_width_lp-1:0]               sel_i
   , input                                      we_i

   , output logic [wb_data_width_p-1:0]         dat_o
   , output logic                               ack_o
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);

  logic pending_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   pending_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(mem_fwd_ready_and_i & mem_fwd_v_o)
     ,.clear_i(ack_o)
     ,.data_o(pending_r)
     );
  assign mem_rev_ready_and_o = pending_r;

  wire [wb_data_width_p-1:0] dat_n = mem_rev_data_i;
  wire ack_n = mem_rev_ready_and_o & mem_rev_v_i;
  bsg_dff
   #(.width_p(1+wb_data_width_p))
   wb_reg
    (.clk_i(clk_i)

     ,.data_i({ack_n, dat_n})
     ,.data_o({ack_o, dat_o})
     );

  bp_bedrock_msg_size_e msg_size;
  always_comb
    begin
      // BP non-handshake signals
      unique case (sel_i)
        'h1: msg_size = e_bedrock_msg_size_1;
        'h3: msg_size = e_bedrock_msg_size_2;
        'hF: msg_size = e_bedrock_msg_size_4;
        // 'hFF:
        default: msg_size = e_bedrock_msg_size_8;
      endcase

      mem_fwd_header_cast_o                = '0;
      mem_fwd_header_cast_o.addr           = {adr_i, {wb_sel_width_lp{1'b0}}};
      mem_fwd_header_cast_o.size           = msg_size;
      mem_fwd_header_cast_o.payload.lce_id = lce_id_i;
      mem_fwd_header_cast_o.payload.did    = did_i;
      mem_fwd_header_cast_o.msg_type       = we_i ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
    end

  // for BP, less than bus width data must be replicated
  wire [wb_sel_width_lp-1:0] cmd_sel = '0; // Always aligned
  wire [wb_size_width_lp-1:0] cmd_size = msg_size;
  bsg_bus_pack
   #(.in_width_p(wb_data_width_p), .out_width_p(bedrock_fill_width_p))
   bus_pack
    (.data_i(dat_i)
     ,.sel_i(cmd_sel)
     ,.size_i(cmd_size)
     ,.data_o(mem_fwd_data_o)
     );
  assign mem_fwd_v_o = cyc_i & stb_i & ~pending_r;

  // assertions
  if (!(wb_data_width_p inside {8, 16, 32, 64}))
    $error("Data width must be 8, 16, 32 or 64 bits");
  if (!(wb_data_width_p == 64))
    $warning("Adapter untested for data widths other than 64 bits. Use with caution");

endmodule

`BSG_ABSTRACT_MODULE(bp_me_wb_client)

