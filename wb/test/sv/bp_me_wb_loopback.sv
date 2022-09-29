`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module top
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , parameter data_width_p         = (cce_type_p == e_cce_uce) ? uce_fill_width_p : bedrock_data_width_p
    , localparam wbone_addr_width_lp = paddr_width_p - `BSG_SAFE_CLOG2(data_width_p>>3)
  )
  (   input  clk_i
    , input  reset_i

    // master BP signals
    , input  [mem_header_width_lp-1:0] m_mem_cmd_header_i
    , input  [data_width_p-1:0]        m_mem_cmd_data_i
    , input                            m_mem_cmd_v_i
    , output                           m_mem_cmd_ready_o

    , output [mem_header_width_lp-1:0] m_mem_resp_header_o
    , output [data_width_p-1:0]        m_mem_resp_data_o
    , output                           m_mem_resp_v_o
    , input                            m_mem_resp_yumi_i

    // client BP signals
    , input  [lce_id_width_p-1:0]      c_lce_id_i
    , input  [did_width_p-1:0]         c_did_i

    , output [mem_header_width_lp-1:0] c_mem_cmd_header_o
    , output [data_width_p-1:0]        c_mem_cmd_data_o
    , output                           c_mem_cmd_v_o
    , input                            c_mem_cmd_ready_i

    , input  [mem_header_width_lp-1:0] c_mem_resp_header_i
    , input  [data_width_p-1:0]        c_mem_resp_data_i
    , input                            c_mem_resp_v_i
    , output                           c_mem_resp_yumi_o
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

  // WB signals
  wire [wbone_addr_width_lp-1:0] adr;
  wire [data_width_p-1:0]        dat_mosi;
  wire                           stb;
  wire                           cyc;
  wire [(data_width_p>>3)-1:0]   sel;
  wire                           we;

  wire [data_width_p-1:0]        dat_miso;
  wire                           ack;

  bp_me_wb_master
   #(.bp_params_p(bp_params_p))
   bp_me_wb_master
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(m_mem_cmd_header_i)
     ,.mem_cmd_data_i(m_mem_cmd_data_i)
     ,.mem_cmd_v_i(m_mem_cmd_v_i)
     ,.mem_cmd_ready_o(m_mem_cmd_ready_o)

     ,.mem_resp_header_o(m_mem_resp_header_o)
     ,.mem_resp_data_o(m_mem_resp_data_o)
     ,.mem_resp_v_o(m_mem_resp_v_o)
     ,.mem_resp_yumi_i(m_mem_resp_yumi_i)

     ,.adr_o(adr)
     ,.dat_o(dat_mosi)
     ,.cyc_o(cyc)
     ,.stb_o(stb)
     ,.sel_o(sel)
     ,.we_o(we)

     ,.dat_i(dat_miso)
     ,.ack_i(ack)
    );

  bp_me_wb_client
   #(.bp_params_p(bp_params_p))
   bp_me_wb_client
    ( .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(c_lce_id_i)
     ,.did_i(c_did_i)

     ,.mem_cmd_header_o(c_mem_cmd_header_o)
     ,.mem_cmd_data_o(c_mem_cmd_data_o)
     ,.mem_cmd_v_o(c_mem_cmd_v_o)
     ,.mem_cmd_ready_i(c_mem_cmd_ready_i)

     ,.mem_resp_header_i(c_mem_resp_header_i)
     ,.mem_resp_data_i(c_mem_resp_data_i)
     ,.mem_resp_v_i(c_mem_resp_v_i)
     ,.mem_resp_yumi_o(c_mem_resp_yumi_o)

     ,.adr_i(adr)
     ,.dat_i(dat_mosi)
     ,.cyc_i(cyc)
     ,.stb_i(stb)
     ,.sel_i(sel)
     ,.we_i(we)

     ,.dat_o(dat_miso)
     ,.ack_o(ack)
    );
endmodule
