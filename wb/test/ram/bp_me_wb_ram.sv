`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module top
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , parameter  data_width_p        = dword_width_gp
    , localparam ram_size_lp         = 4096
    , localparam wbone_addr_width_lp =   `BSG_SAFE_CLOG2(ram_size_lp)
                                       - `BSG_SAFE_CLOG2(data_width_p>>3)

    , localparam cycle_time_lp      = 4
    , localparam reset_cycles_lo_lp = 0
    , localparam reset_cycles_hi_lp = 1
    , localparam debug_lp           = 0
  )
  ();

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);

  // BP master signals
  logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_i;
  logic [data_width_p-1:0]            mem_fwd_data_i;
  logic                               mem_fwd_v_i;
  logic                               mem_fwd_ready_and_o;
  logic                               mem_fwd_last_i;

  logic [mem_rev_header_width_lp-1:0] mem_rev_header_o;
  logic [data_width_p-1:0]            mem_rev_data_o;
  logic                               mem_rev_v_o;
  logic                               mem_rev_ready_and_i;
  logic                               mem_rev_last_o;

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
  logic [62:0] mem_fwd_header_li;
  assign mem_fwd_header_i = {'0, mem_fwd_header_li};

  bsg_nonsynth_dpi_to_fifo
    #(
      .width_p(128)
     ,.debug_p(debug_lp)
    )
    m_d2f_cmd(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o() 

     ,.v_o(mem_fwd_v_i)
     ,.ready_i(mem_fwd_ready_and_o)
     ,.data_o({mem_fwd_last_i, mem_fwd_header_li, mem_fwd_data_i})
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

     ,.v_i(mem_rev_v_o)
     ,.yumi_o(mem_rev_ready_and_i)
     ,.data_i({mem_rev_last_o, mem_rev_header_o[0+:63], mem_rev_data_o})
    );

  /*
   * master adapter
   */
  bp_me_wb_master
   #(.bp_params_p(bp_params_p))
   bp_me_wb_master
    ( .clk_i(clk)
     ,.reset_i(reset)

     ,.mem_fwd_header_i(mem_fwd_header_i)
     ,.mem_fwd_data_i(mem_fwd_data_i)
     ,.mem_fwd_v_i(mem_fwd_v_i)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_o)
     ,.mem_fwd_last_i(mem_fwd_last_i)

     ,.mem_rev_header_o(mem_rev_header_o)
     ,.mem_rev_data_o(mem_rev_data_o)
     ,.mem_rev_v_o(mem_rev_v_o)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_i)
     ,.mem_rev_last_o(mem_rev_last_o)

     ,.adr_o(adr)
     ,.dat_o(dat_mosi)
     ,.cyc_o(cyc)
     ,.stb_o(stb)
     ,.sel_o(sel)
     ,.we_o(we)

     ,.dat_i(dat_miso)
     ,.ack_i(ack)
     );

  /*
   * ram module
   */
  wb_ram
   #(
     .DATA_WIDTH(data_width_p)
    ,.ADDR_WIDTH(`BSG_SAFE_CLOG2(ram_size_lp))
   )
   ram
    ( .clk(clk)
     ,.reset(reset)
     ,.adr_i({adr, 3'b000})
     ,.dat_i(dat_mosi)
     ,.cyc_i(cyc)
     ,.stb_i(stb)
     ,.sel_i(sel)
     ,.we_i(we)

     ,.ack_o(ack)
     ,.dat_o(dat_miso)
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
