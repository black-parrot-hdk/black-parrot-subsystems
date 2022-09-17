module top
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
    
    , localparam wbone_addr_ubound   = paddr_width_p
    , localparam wbone_addr_lbound   = 3
    , localparam wbone_addr_width_lp = wbone_addr_ubound - wbone_addr_lbound
    , localparam wbone_data_width_lp = 64
  )
  (   input  clk_i
    , input  reset_i

    // Master BP
    , input  [mem_header_width_lp-1:0] m_mem_cmd_header_i
    , input  [uce_fill_width_p-1:0]    m_mem_cmd_data_i
    , input                            m_mem_cmd_v_i
    , output                           m_mem_cmd_ready_o

    , output [mem_header_width_lp-1:0] m_mem_resp_header_o
    , output [uce_fill_width_p-1:0]    m_mem_resp_data_o
    , output                           m_mem_resp_v_o
    , input                            m_mem_resp_yumi_i

    // Slave BP
    , input  [lce_id_width_p-1:0]      c_lce_id_i
    , input  [did_width_p-1:0]         c_did_i

    , output [mem_header_width_lp-1:0] c_mem_cmd_header_o
    , output [uce_fill_width_p-1:0]    c_mem_cmd_data_o
    , output                           c_mem_cmd_v_o
    , input                            c_mem_cmd_ready_i

    , input  [mem_header_width_lp-1:0] c_mem_resp_header_i
    , input  [uce_fill_width_p-1:0]    c_mem_resp_data_i
    , input                            c_mem_resp_v_i
    , output                           c_mem_resp_yumi_o
  );

`declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

// WB
wire [wbone_data_width_lp-1:0]  dat_miso;
wire [wbone_data_width_lp-1:0]  dat_mosi;
wire                            ack;
wire                            err;
wire [wbone_addr_width_lp-1:0]  adr;
wire                            stb;
wire                            cyc;
wire [7:0]                      sel;
wire                            we;
wire [2:0]                      cti;
wire [1:0]                      bte;
wire                            rty;

bp_me_wb_master
#(.bp_params_p(bp_params_p))
  bp_me_wb_master
    (  .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.mem_cmd_header_i(m_mem_cmd_header_i)
      ,.mem_cmd_data_i(m_mem_cmd_data_i)
      ,.mem_cmd_v_i(m_mem_cmd_v_i)
      ,.mem_cmd_ready_o(m_mem_cmd_ready_o)

      ,.mem_resp_header_o(m_mem_resp_header_o)
      ,.mem_resp_data_o(m_mem_resp_data_o)
      ,.mem_resp_v_o(m_mem_resp_v_o)
      ,.mem_resp_yumi_i(m_mem_resp_yumi_i)

      ,.dat_i(dat_miso)
      ,.dat_o(dat_mosi)
      ,.ack_i(ack)
      ,.adr_o(adr)
      ,.stb_o(stb)
      ,.cyc_o(cyc)
      ,.sel_o(sel)
      ,.we_o(we)
      ,.cti_o(cti)
      ,.bte_o(bte)
      ,.rty_i(rty)
      ,.err_i(err)
    );

bp_me_wb_client
#(.bp_params_p(bp_params_p))
  bp_me_wb_client
    (  .clk_i(clk_i)
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

      ,.dat_i(dat_mosi)
      ,.dat_o(dat_miso)
      ,.ack_o(ack)
      ,.err_o(err)
      ,.adr_i (adr)
      ,.stb_i(stb)
      ,.cyc_i(cyc)
      ,.sel_i(sel)
      ,.we_i(we)
      ,.cti_i(cti)
      ,.bte_i(bte)
      ,.rty_o(rty)
    );
endmodule
