/*
 * Name:
 *  bp_me_wb_master.v
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

    , parameter data_width_p         = dword_width_gp
    , localparam wbone_addr_width_lp = paddr_width_p - `BSG_SAFE_CLOG2(data_width_p>>3)
  )
  (   input                                  clk_i
    , input                                  reset_i

    // BP signals
    , input  [mem_header_width_lp-1:0]       mem_cmd_header_i
    , input  [data_width_p-1:0]              mem_cmd_data_i
    , input                                  mem_cmd_v_i
    , output logic                           mem_cmd_ready_o

    , output logic [mem_header_width_lp-1:0] mem_resp_header_o
    , output logic [data_width_p-1:0]        mem_resp_data_o
    , output logic                           mem_resp_v_o
    , input                                  mem_resp_yumi_i

    // WB signals
    , output logic [wbone_addr_width_lp-1:0] adr_o
    , output logic [data_width_p-1:0]        dat_o
    , output logic                           cyc_o
    , output logic                           stb_o
    , output logic [(data_width_p>>3)-1:0]   sel_o
    , output logic                           we_o

    , input  [data_width_p-1:0]              dat_i
    , input                                  ack_i
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_header_s, mem_cmd_header);
  `bp_cast_o(bp_bedrock_mem_header_s, mem_resp_header);

  // command buffer
  bp_bedrock_mem_header_s mem_cmd_header_lo;
  wire [data_width_p-1:0] mem_cmd_data_lo;
  wire mem_cmd_v_li;
  bsg_one_fifo
    #(
      .width_p(mem_header_width_lp + data_width_p)
    )
    cmd_buffer(
      .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({mem_cmd_header_i, mem_cmd_data_i})
     ,.v_i(mem_cmd_v_i)
     ,.ready_o(mem_cmd_ready_o)

     ,.data_o({mem_cmd_header_lo, mem_cmd_data_lo})
     ,.v_o(mem_cmd_v_li)
     ,.yumi_i(mem_resp_yumi_i)
    );

  // response data buffer
  wire mem_resp_ready_lo;
  bsg_one_fifo
    #(
      .width_p(data_width_p)
    )
    resp_data_buffer(
      .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(dat_i)
     ,.v_i(ack_i)
     ,.ready_o(mem_resp_ready_lo)

     ,.data_o(mem_resp_data_o)
     ,.v_o(mem_resp_v_o)
     ,.yumi_i(mem_resp_yumi_i)
    );

  // for BP, less than bus width data must be replicated
  localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p>>3));
  wire [size_width_lp-1:0] resp_size_li = mem_cmd_header_lo.size;
  bsg_bus_pack
    #(
      .in_width_p(data_width_p)
    )
    bus_pack(
      .data_i(dat_i)
     ,.sel_i('0)
     ,.size_i(resp_size_li)
     ,.data_o(mem_resp_data_o)
    );

  // state machine for handling WB handshake
  // BP handshake is handled by the command and response data buffers
  typedef enum logic [1:0] {
     e_reset     = 2'b00
    ,e_wait_cmd  = 2'b01
    ,e_wait_resp = 2'b10
  } state_e;
  state_e state_n, state_r;

  always_comb begin
    state_n = state_r;

    // default values for handshake signals
    cyc_o = 1'b0;
    stb_o = 1'b0;

    // WB non-handshake signals
    dat_o = mem_cmd_data_lo;
    adr_o = mem_cmd_header_lo.addr[paddr_width_p-1:`BSG_SAFE_CLOG2(data_width_p>>3)];
    we_o  = (mem_cmd_header_lo.msg_type == e_bedrock_mem_uc_wr);
    unique case (mem_cmd_header_lo.size)
      e_bedrock_msg_size_1: sel_o = (data_width_p>>3)'('h1);
      e_bedrock_msg_size_2: sel_o = (data_width_p>>3)'('h3);
      e_bedrock_msg_size_4: sel_o = (data_width_p>>3)'('hF);
      // e_bedrock_msg_size_8:
      default: sel_o = (data_width_p>>3)'('hFF);
    endcase

    // BP non-handshake signals
    mem_resp_header_cast_o = mem_cmd_header_lo;

    unique case (state_r)
      e_reset: begin
        state_n = e_wait_cmd;
      end

      // wait for incoming BP command
      e_wait_cmd: begin
        cyc_o = mem_cmd_v_li & mem_resp_ready_lo;
        stb_o = mem_cmd_v_li & mem_resp_ready_lo;

        state_n = mem_cmd_v_li & mem_resp_ready_lo
                  ? e_wait_resp
                  : state_r;
      end

      // wait for WB response
      e_wait_resp: begin
        cyc_o = 1'b1;
        stb_o = 1'b1;

        state_n = ack_i
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

  always_ff @(negedge clk_i) begin
    assert(reset_i !== '0 || ~mem_cmd_v_i
           || mem_cmd_header_cast_i.addr[0+:`BSG_SAFE_CLOG2(data_width_p>>3)] == '0)
      else $error("Command address not aligned to bus width");
    assert(reset_i !== '0 || ~mem_cmd_v_i
           || mem_cmd_header_cast_i.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_uc_rd})
      else $error("Command message type must be uncached");
  end
endmodule
