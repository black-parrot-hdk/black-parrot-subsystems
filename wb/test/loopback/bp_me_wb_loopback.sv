`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module top
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , parameter  data_width_p        = dword_width_gp
    , localparam wbone_addr_width_lp = paddr_width_p - `BSG_SAFE_CLOG2(data_width_p>>3)

    , localparam cycle_time_lp      = 4
    , localparam reset_cycles_lo_lp = 0
    , localparam reset_cycles_hi_lp = 1
    , localparam debug_lp           = 0
  )
  ();

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);

  // BP master signals
  logic [mem_fwd_header_width_lp-1:0] m_mem_fwd_header_i;
  logic [data_width_p-1:0]            m_mem_fwd_data_i;
  logic                               m_mem_fwd_v_i;
  logic                               m_mem_fwd_ready_and_o;
  logic                               m_mem_fwd_last_i;

  logic [mem_rev_header_width_lp-1:0] m_mem_rev_header_o;
  logic [data_width_p-1:0]            m_mem_rev_data_o;
  logic                               m_mem_rev_v_o;
  logic                               m_mem_rev_ready_and_i;
  logic                               m_mem_rev_last_o;

  // BP client signals
  logic [mem_fwd_header_width_lp-1:0] c_mem_fwd_header_o;
  logic [data_width_p-1:0]            c_mem_fwd_data_o;
  logic                               c_mem_fwd_v_o;
  logic                               c_mem_fwd_ready_and_i;
  logic                               c_mem_fwd_last_o;

  logic [mem_rev_header_width_lp-1:0] c_mem_rev_header_i;
  logic [data_width_p-1:0]            c_mem_rev_data_i;
  logic                               c_mem_rev_v_i;
  logic                               c_mem_rev_ready_and_o;
  logic                               c_mem_rev_last_i;

  // WB signals
  logic [wbone_addr_width_lp-1:0]     adr;
  logic [data_width_p-1:0]            dat_mosi;
  logic                               stb;
  logic                               cyc;
  logic [(data_width_p>>3)-1:0]       sel;
  logic                               we;

  logic [data_width_p-1:0]            dat_miso;
  logic                               ack;

  /*
   * generate clk and reset
   */
  logic clk;
  bsg_nonsynth_dpi_clock_gen
    #(
      .cycle_time_p(cycle_time_lp)
    )
    clock_gen(
      .o(clk)
    );

  logic reset;
  bsg_nonsynth_reset_gen
    #(
      .reset_cycles_lo_p(reset_cycles_lo_lp)
     ,.reset_cycles_hi_p(reset_cycles_hi_lp)
    ) 
    reset_gen(
      .clk_i(clk)
     ,.async_reset_o(reset)
    );

  /*
   * dpi module for sending commands to the master adapter
   */
  logic [62:0] m_mem_fwd_header_li;
  assign m_mem_fwd_header_i = {'0, m_mem_fwd_header_li};

  bsg_nonsynth_dpi_to_fifo
    #(
      .width_p(128)
     ,.debug_p(debug_lp)
    )
    m_d2f_cmd(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o() 

     ,.v_o(m_mem_fwd_v_i)
     ,.ready_i(m_mem_fwd_ready_and_o)
     ,.data_o({m_mem_fwd_last_i, m_mem_fwd_header_li, m_mem_fwd_data_i})
    );

  /*
   * dpi module for receiving commands from the client adapter
   */
  bsg_nonsynth_dpi_from_fifo
    #(
      .width_p(128)
     ,.debug_p(debug_lp)
    )
    c_f2d_cmd(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o()

     ,.v_i(c_mem_fwd_v_o)
     ,.yumi_o(c_mem_fwd_ready_and_i)
     ,.data_i({c_mem_fwd_header_o[0+:64], c_mem_fwd_data_o})
    );

  /*
   * dpi module for sending responses to the client adapter
   */
  logic [63:0] c_mem_rev_header_li;
  assign c_mem_rev_header_i = {'0, c_mem_rev_header_li};

  bsg_nonsynth_dpi_to_fifo
    #(
      .width_p(128)
     ,.debug_p(debug_lp)
    )
    c_d2f_resp(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o() 

     ,.v_o(c_mem_rev_v_i)
     ,.ready_i(c_mem_rev_ready_and_o)
     ,.data_o({c_mem_rev_header_li, c_mem_rev_data_i})
    );

  /*
   * dpi module for receiving responses from the master adapter
   */
  bsg_nonsynth_dpi_from_fifo
    #(
      .width_p(128)
     ,.debug_p(debug_lp)
    )
    m_f2d_resp(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o()

     ,.v_i(m_mem_rev_v_o)
     ,.yumi_o(m_mem_rev_ready_and_i)
     ,.data_i({m_mem_rev_last_o, m_mem_rev_header_o[0+:63], m_mem_rev_data_o})
    );

  /*
   * adapters
   */
  bp_me_wb_master
   #(.bp_params_p(bp_params_p))
   bp_me_wb_master
    ( .clk_i(clk)
     ,.reset_i(reset)

     ,.mem_fwd_header_i(m_mem_fwd_header_i)
     ,.mem_fwd_data_i(m_mem_fwd_data_i)
     ,.mem_fwd_v_i(m_mem_fwd_v_i)
     ,.mem_fwd_ready_and_o(m_mem_fwd_ready_and_o)
     ,.mem_fwd_last_i(m_mem_fwd_last_i)

     ,.mem_rev_header_o(m_mem_rev_header_o)
     ,.mem_rev_data_o(m_mem_rev_data_o)
     ,.mem_rev_v_o(m_mem_rev_v_o)
     ,.mem_rev_ready_and_i(m_mem_rev_ready_and_i)
     ,.mem_rev_last_o(m_mem_rev_last_o)

     ,.adr_o(adr)
     ,.dat_o(dat_mosi)
     ,.cyc_o(cyc)
     ,.stb_o(stb)
     ,.sel_o(sel)
     ,.we_o(we)
     ,.bte_o()
     ,.cti_o()

     ,.dat_i(dat_miso)
     ,.ack_i(ack)
     );

  bp_me_wb_client
   #(.bp_params_p(bp_params_p))
   bp_me_wb_client
    ( .clk_i(clk)
     ,.reset_i(reset)

     ,.lce_id_i('0)
     ,.did_i('0)

     ,.mem_fwd_header_o(c_mem_fwd_header_o)
     ,.mem_fwd_data_o(c_mem_fwd_data_o)
     ,.mem_fwd_v_o(c_mem_fwd_v_o)
     ,.mem_fwd_ready_and_i(c_mem_fwd_ready_and_i)
     ,.mem_fwd_last_o(/* always 1, unused */)

     ,.mem_rev_header_i(c_mem_rev_header_i)
     ,.mem_rev_data_i(c_mem_rev_data_i)
     ,.mem_rev_v_i(c_mem_rev_v_i)
     ,.mem_rev_ready_and_o(c_mem_rev_ready_and_o)
     ,.mem_rev_last_i('1)

     ,.adr_i(adr)
     ,.dat_i(dat_mosi)
     ,.cyc_i(cyc)
     ,.stb_i(stb)
     ,.sel_i(sel)
     ,.we_i(we)

     ,.dat_o(dat_miso)
     ,.ack_o(ack)
     );

  /*
   * assertions
   */
  initial begin
    assert(data_width_p == 64)
      else $error("Testbench is to be used with 64 bit wide data");
    assert(cce_block_width_p >= 512)
      else $error("Testbench is to be used with at least 512 bit wide cache blocks");
  end
endmodule
