`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module top
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , parameter  data_width_p        = dword_width_gp
    , localparam ram_elements_lp     = 256
    , localparam wbone_addr_width_lp =   `BSG_SAFE_CLOG2(ram_elements_lp)
                                       - `BSG_SAFE_CLOG2(data_width_p>>3)

    , localparam cycle_time_lp      = 4
    , localparam reset_cycles_lo_lp = 0
    , localparam reset_cycles_hi_lp = 1
    , localparam debug_lp           = 0
  )
  ();

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

  // BP master signals
  wire [mem_header_width_lp-1:0] mem_cmd_header_i;
  wire [data_width_p-1:0]        mem_cmd_data_i;
  wire                           mem_cmd_v_i;
  wire                           mem_cmd_ready_o;

  wire [mem_header_width_lp-1:0] mem_resp_header_o;
  wire [data_width_p-1:0]        mem_resp_data_o;
  wire                           mem_resp_v_o;
  wire                           mem_resp_yumi_i;

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

  // send commands to the master adapter
  wire [63:0] m_d2f_cmd_header_o;
  wire [63:0] m_d2f_cmd_data_o;
  assign mem_cmd_header_i = {'0, m_d2f_cmd_header_o};
  assign mem_cmd_data_i   = m_d2f_cmd_data_o;

  bsg_nonsynth_dpi_to_fifo
    #(
      .width_p(128)
     ,.debug_p(debug_lp)
    )
    m_d2f_cmd(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o() 

     ,.v_o(mem_cmd_v_i)
     ,.ready_i(mem_cmd_ready_o)
     ,.data_o({m_d2f_cmd_header_o, m_d2f_cmd_data_o})
    );
  
  // receive responses from the master adapter
  wire [63:0] m_f2d_resp_header_i;
  wire [63:0] m_f2d_resp_data_i;
  assign m_f2d_resp_header_i = mem_resp_header_o[0+:64];
  assign m_f2d_resp_data_i   = mem_resp_data_o;

  bsg_nonsynth_dpi_from_fifo
    #(
      .width_p(128)
     ,.debug_p(debug_lp)
    )
    m_f2d_resp(
      .clk_i(clk)
     ,.reset_i(reset)
     ,.debug_o()

     ,.v_i(mem_resp_v_o)
     ,.yumi_o(mem_resp_yumi_i)
     ,.data_i({m_f2d_resp_header_i, m_f2d_resp_data_i})
    );

  // master adapter
  bp_me_wb_master
   #(.bp_params_p(bp_params_p))
   bp_me_wb_master
    ( .clk_i(clk)
     ,.reset_i(reset)

     ,.mem_cmd_header_i(mem_cmd_header_i)
     ,.mem_cmd_data_i(mem_cmd_data_i)
     ,.mem_cmd_v_i(mem_cmd_v_i)
     ,.mem_cmd_ready_o(mem_cmd_ready_o)

     ,.mem_resp_header_o(mem_resp_header_o)
     ,.mem_resp_data_o(mem_resp_data_o)
     ,.mem_resp_v_o(mem_resp_v_o)
     ,.mem_resp_yumi_i(mem_resp_yumi_i)

     ,.adr_o(adr)
     ,.dat_o(dat_mosi)
     ,.cyc_o(cyc)
     ,.stb_o(stb)
     ,.sel_o(sel)
     ,.we_o(we)

     ,.dat_i(dat_miso)
     ,.ack_i(ack)
     );
  
  // ram
  wb_ram
   #(
     .DATA_WIDTH(data_width_p)
    ,.ADDR_WIDTH(8)
   )
   ram
    ( .clk(clk)
     ,.adr_i({adr, 3'b000})
     ,.dat_i(dat_mosi)
     ,.cyc_i(cyc)
     ,.stb_i(stb)
     ,.sel_i(sel)
     ,.we_i(we)

     ,.ack_o(ack)
     ,.dat_o(dat_miso)
     );

  // assertions
  initial begin
    assert(data_width_p == 64)
      else $error("Testbench is to be used with 64 bit wide data");
  end
endmodule
