/*
 * Name:
 *  bp_me_wb_client.v
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
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , parameter data_width_p         = dword_width_gp
    , localparam wbone_addr_width_lp = paddr_width_p - `BSG_SAFE_CLOG2(data_width_p>>3)
  )
  (   input                                  clk_i
    , input                                  reset_i

    // BP signals
    , input  [lce_id_width_p-1:0]            lce_id_i
    , input  [did_width_p-1:0]               did_i

    , output logic [mem_header_width_lp-1:0] mem_cmd_header_o
    , output logic [data_width_p-1:0]        mem_cmd_data_o
    , output logic                           mem_cmd_v_o
    , input                                  mem_cmd_ready_i

    , input  [mem_header_width_lp-1:0]       mem_resp_header_i
    , input  [data_width_p-1:0]              mem_resp_data_i
    , input                                  mem_resp_v_i
    , output logic                           mem_resp_ready_o

    // WB signals
    , input  [wbone_addr_width_lp-1:0]       adr_i
    , input  [data_width_p-1:0]              dat_i
    , input                                  cyc_i
    , input                                  stb_i
    , input  [(data_width_p>>3)-1:0]         sel_i
    , input                                  we_i

    , output logic [data_width_p-1:0]        dat_o
    , output logic                           ack_o
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_header_s, mem_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, mem_resp_header);

  // for BP, less than bus width data must be replicated
  localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p>>3));
  wire [size_width_lp-1:0] cmd_size_li = msg_size;
  bsg_bus_pack
   #(.in_width_p(data_width_p))
   bus_pack
    ( .data_i(dat_i)
     ,.sel_i('0)
     ,.size_i(cmd_size_li)
     ,.data_o(mem_cmd_data_o)
     );

  // state machine for handling BP and WB handshakes
  typedef enum logic [1:0] {
     e_reset     = 2'b00
    ,e_wait_cmd  = 2'b01
    ,e_wait_resp = 2'b10
  } state_e;
  state_e state_n, state_r;

  bp_bedrock_msg_size_e msg_size;
  always_comb begin
    state_n = state_r;

    // default values for handshake signals
    mem_cmd_v_o      = 1'b0;
    mem_resp_ready_o = 1'b0;
    ack_o            = 1'b0;

    // BP non-handshake signals
    unique case (sel_i)
      (data_width_p>>3)'('h1): msg_size = e_bedrock_msg_size_1;
      (data_width_p>>3)'('h3): msg_size = e_bedrock_msg_size_2;
      (data_width_p>>3)'('hF): msg_size = e_bedrock_msg_size_4;
      // (data_width_p>>3)'('hFF):
      default: msg_size = e_bedrock_msg_size_8;
    endcase
    mem_cmd_data_o                       = dat_i;
    mem_cmd_header_cast_o                = '0;
    mem_cmd_header_cast_o.addr           = {adr_i, (`BSG_SAFE_CLOG2(data_width_p>>3))'('b0)};
    mem_cmd_header_cast_o.size           = msg_size;
    mem_cmd_header_cast_o.payload.lce_id = lce_id_i;
    mem_cmd_header_cast_o.payload.did    = did_i;
    mem_cmd_header_cast_o.msg_type       = we_i
                                           ? e_bedrock_mem_uc_wr
                                           : e_bedrock_mem_uc_rd;

    // WB non-handshake signals
    dat_o = mem_resp_data_i;

    unique case (state_r)
      e_reset: begin
        state_n = e_wait_cmd;
      end

      // wait for incoming WB command
      e_wait_cmd: begin
        mem_cmd_v_o = cyc_i & stb_i;

        state_n = mem_cmd_v_o & mem_cmd_ready_i
                  ? e_wait_resp
                  : state_r;
      end

      // wait for the client's BP response
      e_wait_resp: begin
        mem_resp_ready_o = 1'b1;

        ack_o = mem_resp_v_i;

        state_n = mem_resp_v_i
                  ? e_wait_cmd
                  : state_r;
      end

      default: begin end
    endcase
  end

  // advance to next state
  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

  // assertions
  initial begin
    assert(data_width_p inside {8, 16, 32, 64})
      else $error("Data width must be 8, 16, 32 or 64 bits");
    assert(data_width_p == 64)
      else $display("Adapter untested for data widths other than 64 bits. Use with caution");
  end
endmodule
