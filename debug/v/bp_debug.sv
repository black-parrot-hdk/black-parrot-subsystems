
`include "bp_common_defines.svh"

module bp_debug
 import dm::*;
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                        clk_i
   , input                                      reset_i

   , input [lce_id_width_p-1:0]                 lce_id_i
   , input [did_width_p-1:0]                    did_i

   , input                                      dmi_reset_i
   , input dmi_req_t                            dmi_req_i
   , input                                      dmi_req_v_i
   , output logic                               dmi_req_ready_and_o

   , output dmi_resp_t                          dmi_resp_o
   , output logic                               dmi_resp_v_o
   , input                                      dmi_resp_ready_and_i

   , output logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_o
   , output logic [dword_width_gp-1:0]          mem_fwd_data_o
   , output logic                               mem_fwd_v_o
   , input                                      mem_fwd_ready_and_i
   , output logic                               mem_fwd_last_o

   , input  [mem_rev_header_width_lp-1:0]       mem_rev_header_i
   , input  [dword_width_gp-1:0]                mem_rev_data_i
   , input                                      mem_rev_v_i
   , output logic                               mem_rev_ready_and_o
   , input                                      mem_rev_last_i

   , input [mem_fwd_header_width_lp-1:0]        mem_fwd_header_i
   , input [dword_width_gp-1:0]                 mem_fwd_data_i
   , input                                      mem_fwd_v_i
   , output logic                               mem_fwd_ready_and_o
   , input                                      mem_fwd_last_i

   , output logic [mem_rev_header_width_lp-1:0] mem_rev_header_o
   , output logic [dword_width_gp-1:0]          mem_rev_data_o
   , output logic                               mem_rev_v_o
   , input                                      mem_rev_ready_and_i
   , output logic                               mem_rev_last_o
   );

  //`declare_debug_structs(paddr_width_mp);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  localparam bedrock_reg_els_lp = 1;
  logic r_v_li;
  logic w_v_li;
  logic [dev_addr_width_gp-1:0] addr_lo;
  logic [`BSG_WIDTH(`BSG_SAFE_CLOG2(dword_width_gp/8))-1:0] size_lo;
  logic [dword_width_gp-1:0] data_lo;
  logic [bedrock_reg_els_lp-1:0][dword_width_gp-1:0] data_li;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.els_p(bedrock_reg_els_lp)
     ,.reg_addr_width_p(dev_addr_width_gp)
     ,.base_addr_p(20'h?????)
     )
   register
    (.*
     ,.r_v_o(r_v_li)
     ,.w_v_o(w_v_li)
     ,.addr_o(addr_lo)
     ,.size_o(size_lo)
     ,.data_o(data_lo)
     ,.data_i(data_li)
     );

  hartinfo_t hartinfo;
  assign hartinfo = '{zero1      : '0
                      ,nscratch  : 2
                      ,zero0     : '0
                      ,dataaccess: 1'b1
                      ,datasize  : dm::DataCount
                      ,dataaddr  : dm::DataAddr
                      };

  logic debug_req;

  localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(dword_width_gp/8);
  logic slave_req_li, slave_we_li;
  logic [dword_width_gp-1:0] slave_addr_li;
  logic [dword_width_gp/8-1:0] slave_be_li;
  logic [dword_width_gp-1:0] slave_wdata_li;
  logic [dword_width_gp-1:0] slave_rdata_lo;
  wire [byte_offset_width_lp-1:0] mask_shift = addr_lo[0+:byte_offset_width_lp];

  logic master_req_lo, master_we_lo, master_gnt_li;
  logic [dword_width_gp-1:0] master_add_lo;
  logic [dword_width_gp-1:0] master_wdata_lo;
  logic [dword_width_gp/8-1:0] master_be_lo;

  logic master_r_valid_li;
  logic master_r_err_li, master_r_other_err_li;
  logic [dword_width_gp-1:0] master_r_rdata_li;
  dm_top
   #(.NrHarts(num_core_p)
     ,.BusWidth(dword_width_gp)
     // Forces portable debug rom
     ,.DmBaseAddress(1)
     )
   dm
    (.clk_i(clk_i)
     ,.rst_ni(~reset_i)
     ,.testmode_i(1'b0) // unused
     ,.ndmreset_o() // unused, connect??
     ,.dmactive_o() // unused, connect??
     ,.debug_req_o(debug_req)
     ,.unavailable_i('0) // unused
     ,.hartinfo_i(hartinfo)

     ,.slave_req_i(slave_req_li)
     ,.slave_we_i(slave_we_li)
     ,.slave_addr_i(slave_addr_li)
     ,.slave_be_i(slave_be_li)
     ,.slave_wdata_i(slave_wdata_li)
     ,.slave_rdata_o(slave_rdata_lo)

     ,.master_req_o(master_req_lo)
     ,.master_add_o(master_add_lo)
     ,.master_we_o(master_we_lo)
     ,.master_wdata_o(master_wdata_lo)
     ,.master_be_o(master_be_lo)
     ,.master_gnt_i(master_gnt_li)
     ,.master_r_valid_i(master_r_valid_li)
     ,.master_r_err_i(master_r_err_li)
     ,.master_r_other_err_i(master_r_other_err_li)
     ,.master_r_rdata_i(master_r_rdata_li)

     // DMI interface
     ,.dmi_rst_ni(~dmi_reset_i)
     ,.dmi_req_valid_i(dmi_req_v_i)
     ,.dmi_req_ready_o(dmi_req_ready_and_o)
     ,.dmi_req_i(dmi_req_i)

     ,.dmi_resp_valid_o(dmi_resp_v_o)
     ,.dmi_resp_ready_i(dmi_resp_ready_and_i)
     ,.dmi_resp_o(dmi_resp_o)
     );

  enum logic [2:0]
    {e_ready
     ,e_send_npc
     ,e_send_hireq
     ,e_send_loreq
     ,e_lower_req
     ,e_send_sba
     } state_n, state_r;
  wire is_ready      = (state_r == e_ready);
  wire is_send_npc   = (state_r == e_send_npc);
  wire is_send_hireq = (state_r == e_send_hireq);
  wire is_send_loreq = (state_r == e_send_loreq);
  wire is_lower_req  = (state_r == e_lower_req);
  wire is_send_sba   = (state_r == e_send_sba);

  logic outstanding_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   outstanding_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(mem_fwd_ready_and_i & mem_fwd_v_o)
     ,.clear_i(mem_rev_ready_and_o & mem_rev_v_i)
     ,.data_o(outstanding_r)
     );

  always_comb
    begin
      slave_req_li = r_v_li | w_v_li;
      slave_we_li = w_v_li;
      slave_addr_li = addr_lo;
      case (size_lo)
        e_bedrock_msg_size_1: slave_be_li = (dword_width_gp>>3)'('h1) << mask_shift;
        e_bedrock_msg_size_2: slave_be_li = (dword_width_gp>>3)'('h3) << mask_shift;
        e_bedrock_msg_size_4: slave_be_li = (dword_width_gp>>3)'('hF) << mask_shift;
        default: slave_be_li = '1;
      endcase
      slave_wdata_li = data_lo;
      data_li = slave_rdata_lo;
    end

  always_comb
    begin
      mem_rev_ready_and_o = 1'b1;

      mem_fwd_v_o = 1'b0;
      mem_fwd_last_o = 1'b1;
      mem_fwd_header_cast_o = '0;
      mem_fwd_header_cast_o.payload.lce_id = 2'b10;
      mem_fwd_header_cast_o.payload.did = 2'b00;
      mem_fwd_header_cast_o.subop = e_bedrock_store;

      master_gnt_li = '0;

      master_r_valid_li = '0;
      master_r_err_li = '0;
      master_r_other_err_li = '0;
      master_r_rdata_li = mem_rev_data_i;

      unique casez (state_r)
        e_ready:
          state_n = debug_req ? e_send_npc : master_req_lo ? e_send_sba : state_r;
        e_send_npc:
          begin
            mem_fwd_v_o = ~outstanding_r;
            mem_fwd_header_cast_o.msg_type = e_bedrock_mem_uc_wr;
            mem_fwd_header_cast_o.addr = cfg_base_addr_gp + cfg_reg_npc_gp;
            mem_fwd_header_cast_o.size = e_bedrock_msg_size_8;
            mem_fwd_data_o = host_base_addr_gp + debugrom_base_addr_gp;

            state_n = (mem_rev_ready_and_o & mem_rev_v_i) ? e_send_hireq : state_r;
          end
        e_send_hireq:
          begin
            mem_fwd_v_o = ~outstanding_r;
            mem_fwd_header_cast_o.msg_type = e_bedrock_mem_uc_wr;
            mem_fwd_header_cast_o.addr = clint_dev_base_addr_gp + debug_reg_base_addr_gp;
            mem_fwd_data_o = 1'b1;

            state_n = (mem_rev_ready_and_o & mem_rev_v_i) ? e_send_loreq : state_r;
          end
        e_send_loreq:
          begin
            mem_fwd_v_o = ~outstanding_r;
            mem_fwd_header_cast_o.msg_type = e_bedrock_mem_uc_wr;
            mem_fwd_header_cast_o.addr = clint_dev_base_addr_gp + debug_reg_base_addr_gp;
            mem_fwd_data_o = 1'b0;

            state_n = (mem_rev_ready_and_o & mem_rev_v_i) ? e_lower_req : state_r;
          end
        e_lower_req:
          begin
            state_n = ~debug_req ? e_ready : state_r;
          end
        e_send_sba:
          begin
            mem_fwd_v_o = ~outstanding_r;
            mem_fwd_header_cast_o.msg_type = master_we_lo ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
            mem_fwd_header_cast_o.addr = master_add_lo;
            mem_fwd_data_o = master_wdata_lo;
            case (master_be_lo)
              'h80, 'h40, 'h20, 'h10,
              'h08, 'h04, 'h02, 'h01: mem_fwd_header_cast_o.size = e_bedrock_msg_size_1;
              'hC0, 'h30, 'h0C, 'h03: mem_fwd_header_cast_o.size = e_bedrock_msg_size_2;
                          'hf0, 'h0f: mem_fwd_header_cast_o.size = e_bedrock_msg_size_4;
              default: mem_fwd_header_cast_o.size = e_bedrock_msg_size_8;
            endcase
            master_gnt_li = (mem_fwd_ready_and_i & mem_fwd_v_o);

            master_r_valid_li = mem_rev_v_i;

            state_n = (mem_rev_ready_and_o & mem_rev_v_i) ? e_ready : state_r;
          end
        default: state_n = state_r;
      endcase
    end

  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

endmodule

