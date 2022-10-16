`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module top
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , parameter data_width_p         = dword_width_gp
    , localparam wbone_addr_width_lp = paddr_width_p - `BSG_SAFE_CLOG2(data_width_p>>3)

    , localparam cycle_time_lp      = 4
    , localparam reset_cycles_lo_lp = 0
    , localparam reset_cycles_hi_lp = 1
    , localparam debug_lp           = 0
  )
  ();

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

  // BP master signals
  wire [mem_header_width_lp-1:0] m_mem_cmd_header_i;
  wire [data_width_p-1:0]        m_mem_cmd_data_i;
  wire                           m_mem_cmd_v_i;
  wire                           m_mem_cmd_ready_o;

  wire [mem_header_width_lp-1:0] m_mem_resp_header_o;
  wire [data_width_p-1:0]        m_mem_resp_data_o;
  wire                           m_mem_resp_v_o;
  wire                           m_mem_resp_yumi_i;

  // BP client signals
  wire [mem_header_width_lp-1:0] c_mem_cmd_header_o;
  wire [data_width_p-1:0]        c_mem_cmd_data_o;
  wire                           c_mem_cmd_v_o;
  wire                           c_mem_cmd_ready_i;

  wire [mem_header_width_lp-1:0] c_mem_resp_header_i;
  wire [data_width_p-1:0]        c_mem_resp_data_i;
  wire                           c_mem_resp_v_i;
  wire                           c_mem_resp_ready_o;

  // WB signals
  wire [wbone_addr_width_lp-1:0] adr;
  wire [data_width_p-1:0]        dat_mosi;
  wire                           stb;
  wire                           cyc;
  wire [(data_width_p>>3)-1:0]   sel;
  wire                           we;

  wire [data_width_p-1:0]        dat_miso;
  wire                           ack;

  // generate clk and reset
  wire clk;
  bsg_nonsynth_dpi_clock_gen
    #(
      .cycle_time_p(cycle_time_lp)
    )
    clock_gen(
      .o(clk)
    );

  wire reset;
  bsg_nonsynth_reset_gen
    #(
      .reset_cycles_lo_p(reset_cycles_lo_lp)
     ,.reset_cycles_hi_p(reset_cycles_hi_lp)
    ) 
    reset_gen(
      .clk_i(clk) 
     ,.async_reset_o(reset)
    );
  
  // bsg_nonsynth_dpi_from_fifo and bsg_nonsynth_dpi_to_fifo can only handle up
  // to 128 bits of data, so we need two of each type per adapter
  // here, we just chose to split header and data, since it makes sense

  // modules for sending a command to the master adapter
  bsg_nonsynth_dpi_to_fifo
    #(
      .width_p(2 ** `BSG_SAFE_CLOG2(mem_header_width_lp))
     ,.debug_p(debug_lp)
    )
    m_d2f_cmd_header(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o() 

     ,.v_o(m_mem_cmd_v_i)
     ,.ready_i(m_mem_cmd_ready_o)
     ,.data_o(m_mem_cmd_header_i)
    );
  bsg_nonsynth_dpi_to_fifo
    #(
      .width_p(data_width_p)
     ,.debug_p(debug_lp)
    )
    m_d2f_cmd_data(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o()

      // m_d2f_cmd_header's v_o is used to interface the adapter
     ,.v_o()
     ,.ready_i(m_mem_cmd_ready_o)
     ,.data_o(m_mem_cmd_data_i)
    );

  // modules for receiving a command from the client adapter
  bsg_nonsynth_dpi_from_fifo
    #(
      .width_p(2 ** `BSG_SAFE_CLOG2(mem_header_width_lp))
     ,.debug_p(debug_lp)
    )
    c_f2d_cmd_header(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o()

     ,.v_i(c_mem_cmd_v_o)
     ,.yumi_o(c_mem_cmd_ready_i)
     ,.data_i(c_mem_cmd_header_o)
    );
  bsg_nonsynth_dpi_from_fifo
    #(
      .width_p(data_width_p)
     ,.debug_p(debug_lp)
    )
    c_f2d_cmd_data(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o()

     ,.v_i(c_mem_cmd_v_o)
      // c_f2d_cmd_header's yumi_o is used to interface the adapter
     ,.yumi_o()
     ,.data_i(c_mem_cmd_data_o)
    );

  // modules for sending a response to the client adapter
  bsg_nonsynth_dpi_to_fifo
    #(
      .width_p(2 ** `BSG_SAFE_CLOG2(mem_header_width_lp))
     ,.debug_p(debug_lp)
    )
    c_d2f_resp_header(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o() 

     ,.v_o(c_mem_resp_v_i)
     ,.ready_i(c_mem_resp_ready_o)
     ,.data_o(c_mem_resp_header_i)
    );
  bsg_nonsynth_dpi_to_fifo
    #(
      .width_p(data_width_p)
     ,.debug_p(debug_lp)
    )
    c_d2f_resp_data(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o()

      // c_d2f_resp_header's v_o is used to interface the adapter
     ,.v_o()
     ,.ready_i(c_mem_resp_ready_o)
     ,.data_o(c_mem_resp_data_i)
    );

  // modules for receiving a response from the master adapter
  bsg_nonsynth_dpi_from_fifo
    #(
      .width_p(2 ** `BSG_SAFE_CLOG2(mem_header_width_lp))
     ,.debug_p(debug_lp)
    )
    m_f2d_resp_header(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o()

     ,.v_i(m_mem_resp_v_o)
     ,.yumi_o(m_mem_resp_yumi_i)
     ,.data_i(m_mem_resp_header_o)
    );
  bsg_nonsynth_dpi_from_fifo
    #(
      .width_p(data_width_p)
     ,.debug_p(debug_lp)
    )
    m_f2d_resp_data(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o()

     ,.v_i(m_mem_resp_v_o)
      // m_f2d_resp_header's yumi_o is used to interface the adapter
     ,.yumi_o()
     ,.data_i(m_mem_resp_data_o)
    );

  // adapters
  bp_me_wb_master
   #(.bp_params_p(bp_params_p))
   bp_me_wb_master
    ( .clk_i(clk)
     ,.reset_i(reset)

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
    ( .clk_i(clk)
     ,.reset_i(reset)

     ,.lce_id_i('0)
     ,.did_i('0)

     ,.mem_cmd_header_o(c_mem_cmd_header_o)
     ,.mem_cmd_data_o(c_mem_cmd_data_o)
     ,.mem_cmd_v_o(c_mem_cmd_v_o)
     ,.mem_cmd_ready_i(c_mem_cmd_ready_i)

     ,.mem_resp_header_i(c_mem_resp_header_i)
     ,.mem_resp_data_i(c_mem_resp_data_i)
     ,.mem_resp_v_i(c_mem_resp_v_i)
     ,.mem_resp_ready_o(c_mem_resp_ready_o)

     ,.adr_i(adr)
     ,.dat_i(dat_mosi)
     ,.cyc_i(cyc)
     ,.stb_i(stb)
     ,.sel_i(sel)
     ,.we_i(we)

     ,.dat_o(dat_miso)
     ,.ack_o(ack)
     );

  // assertions
  initial begin
    assert(data_width_p == 64)
      else $error("Testbench is to be used with 64 bit wide data");
  end
endmodule
