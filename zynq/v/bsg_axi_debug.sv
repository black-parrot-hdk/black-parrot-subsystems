
`include "bsg_defines.sv"

// Master address space is the whole BP space
// Client address space is
// DMI bridge: 0x00_0000 - 0x12_FFFF 
// DMI client port: 0x13_0000 -
module bsg_axi_debug
 import dm::*;
 #(parameter m_axil_data_width_p = 32
   , parameter m_axil_addr_width_p = 32
   , parameter s_axil_data_width_p = 32
   , parameter s_axil_addr_width_p = 32
   , parameter bus_width_p = 32
   )
  (input                                         clk_i
   , input                                       reset_i

   //====================== AXI-4 LITE =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , output logic [m_axil_addr_width_p-1:0]      m_axil_awaddr_o
   , output logic [2:0]                          m_axil_awprot_o
   , output logic                                m_axil_awvalid_o
   , input                                       m_axil_awready_i

   // WRITE DATA CHANNEL SIGNALS
   , output logic [m_axil_data_width_p-1:0]      m_axil_wdata_o
   , output logic [(m_axil_data_width_p>>3)-1:0] m_axil_wstrb_o
   , output logic                                m_axil_wvalid_o
   , input                                       m_axil_wready_i

   // WRITE RESPONSE CHANNEL SIGNALS
   , input [1:0]                                 m_axil_bresp_i
   , input                                       m_axil_bvalid_i
   , output logic                                m_axil_bready_o

   // READ ADDRESS CHANNEL SIGNALS
   , output logic [m_axil_addr_width_p-1:0]      m_axil_araddr_o
   , output logic [2:0]                          m_axil_arprot_o
   , output logic                                m_axil_arvalid_o
   , input                                       m_axil_arready_i

   // READ DATA CHANNEL SIGNALS
   , input [m_axil_data_width_p-1:0]             m_axil_rdata_i
   , input [1:0]                                 m_axil_rresp_i
   , input                                       m_axil_rvalid_i
   , output logic                                m_axil_rready_o

   , input [s_axil_addr_width_p-1:0]             s_axil_awaddr_i
   , input [2:0]                                 s_axil_awprot_i
   , input                                       s_axil_awvalid_i
   , output logic                                s_axil_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [s_axil_data_width_p-1:0]             s_axil_wdata_i
   , input [(s_axil_data_width_p>>3)-1:0]        s_axil_wstrb_i
   , input                                       s_axil_wvalid_i
   , output logic                                s_axil_wready_o

   // WRITE RESPONSE CHANNEL SIGNALS
   , output logic [1:0]                          s_axil_bresp_o
   , output logic                                s_axil_bvalid_o
   , input                                       s_axil_bready_i

   // READ ADDRESS CHANNEL SIGNALS
   , input [s_axil_addr_width_p-1:0]             s_axil_araddr_i
   , input [2:0]                                 s_axil_arprot_i
   , input                                       s_axil_arvalid_i
   , output logic                                s_axil_arready_o

   // READ DATA CHANNEL SIGNALS
   , output logic [s_axil_data_width_p-1:0]      s_axil_rdata_o
   , output logic [1:0]                          s_axil_rresp_o
   , output logic                                s_axil_rvalid_o
   , input                                       s_axil_rready_i
   );

  enum logic [2:0]
    {e_ready
     ,e_send_npc
     ,e_send_hireq
     ,e_send_loreq
     ,e_lower_req
     ,e_unfreeze
     } state_n, state_r;
  wire is_ready      = (state_r == e_ready);
  wire is_send_npc   = (state_r == e_send_npc);
  wire is_send_hireq = (state_r == e_send_hireq);
  wire is_send_loreq = (state_r == e_send_loreq);
  wire is_lower_req  = (state_r == e_lower_req);
  wire is_unfreeze   = (state_r == e_unfreeze);

  hartinfo_t hartinfo;
  assign hartinfo = '{zero1      : '0
                      ,nscratch  : 2
                      ,zero0     : '0
                      ,dataaccess: 1'b1
                      ,datasize  : dm::DataCount
                      ,dataaddr  : dm::DataAddr
                      };

  logic debug_req;
  logic ndmreset_lo;

  logic slave_req_li, slave_we_li;
  logic [bus_width_p_p-1:0] slave_addr_li;
  logic [bus_width_p_p/8-1:0] slave_be_li;
  logic [bus_width_p_p-1:0] slave_wdata_li;
  logic [bus_width_p_p-1:0] slave_rdata_lo;

  logic master_req_lo, master_we_lo, master_gnt_li;
  logic [bus_width_p_p-1:0] master_add_lo;
  logic [bus_width_p_p-1:0] master_wdata_lo;
  logic [bus_width_p_p/8-1:0] master_be_lo;

  logic master_r_valid_li;
  logic master_r_err_li, master_r_other_err_li;
  logic [bus_width_p_p-1:0] master_r_rdata_li;

  dmi_req_t dmi_req_li;
  logic dmi_v_li, dmi_ready_lo;
  dmi_resp_t dmi_resp_lo;
  logic dmi_resp_v_lo, dmi_resp_ready_li;
  dm_top
   #(.NrHarts(1)
     ,.BusWidth(bus_width_p)
     ,.Xlen(dword_width_gp)
     // Forces portable debug rom
     ,.DmBaseAddress(1)
     )
   dm
    (.clk_i(clk_i)
     ,.rst_ni(~reset_i)
     ,.next_dm_addr_i('0)
     ,.testmode_i(1'b0) // unused
     ,.ndmreset_o(ndmreset_lo) // unused, connect??
     ,.ndmreset_i(ndmreset_lo) // unused, connect??
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
     ,.dmi_rst_ni(~reset_i)
     ,.dmi_req_valid_i(dmi_req_v_li)
     ,.dmi_req_ready_o(dmi_req_ready_lo)
     ,.dmi_req_i(dmi_req_li)

     ,.dmi_resp_valid_o(dmi_resp_v_lo)
     ,.dmi_resp_ready_i(dmi_resp_ready_li)
     ,.dmi_resp_o(dmi_resp_lo)
     );

  logic [s_axil_data_width_p-1:0] c_fifo_data_lo;
  logic [s_axil_addr_width_p-1:0] c_fifo_addr_lo;
  logic c_fifo_ready_and_li, c_fifo_v_lo, c_fifo_w_lo;
  logic [(s_axil_data_width_p/8)-1:0] c_fifo_wmask_lo;
  logic [s_axil_data_width_p-1:0] c_fifo_data_li;
  logic c_fifo_ready_and_lo, c_fifo_v_li;
  bsg_axil_fifo_client
   #(.axil_data_width_p(s_axil_data_width_p), .axil_addr_width_p(s_axil_addr_width_p))
   dut_bridge
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_o(c_fifo_data_lo)
     ,.addr_o(c_fifo_addr_lo)
     ,.v_o(c_fifo_v_lo)
     ,.w_o(c_fifo_w_lo)
     ,.wmask_o(c_fifo_wmask_lo)
     ,.ready_and_i(c_fifo_ready_and_li)

     ,.data_i(c_fifo_data_li)
     ,.v_i(c_fifo_v_li)
     ,.ready_and_o(c_fifo_ready_and_lo)

     ,.*
     );

  logic c_fifo_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   c_resp_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(c_fifo_ready_and_li & c_fifo_v_lo)
     ,.clear_i(c_fifo_ready_and_lo & c_fifo_v_li)
     ,.data_o(c_fifo_v_r)
     );

  // TODO: Parameterize
  always_comb
    begin
      slave_req_li = '0;
      slave_we_li = '0;
      slave_addr_li = '0;
      slave_be_li = '0;
      slave_wdata_li = '0;

      dmi_req_li = '0;
      dmi_req_v_li = '0;
      dmi_resp_ready_li = '0;

      c_fifo_data_li = '0;

      c_fifo_v_li = '0;

      if (c_fifo_addr_lo <  32'h130000)
        begin
          dmi_req_v_li = c_fifo_v_lo;
          dmi_req_li.addr = c_fifo_addr_lo >> 2'd2; // 23b word address
          dmi_req_li.op = c_fifo_w_lo ? DTM_WRITE : DTM_READ;
          dmi_req_li.data = c_fifo_data_lo;
        end
      else
        begin
          slave_req_li = c_fifo_v_lo;
          slave_we_li = c_fifo_w_lo;
          slave_addr_li = c_fifo_addr_lo;
          slave_be_li = c_fifo_wmask_lo;
          slave_wdata_li = c_fifo_data_lo;
        end
      c_fifo_ready_and_li = dmi_req_ready_lo;

      c_fifo_v_li = c_fifo_v_r;
      c_fifo_data_li = dmi_resp_v_lo ? dmi_resp_lo.data : slave_rdata_lo;
      dmi_resp_ready_li = c_fifo_ready_and_lo;
    end

  logic [m_axil_data_width_p-1:0] m_fifo_data_li;
  logic [m_axil_addr_width_p-1:0] m_fifo_addr_li;
  logic m_fifo_ready_and_lo, m_fifo_v_li, m_fifo_w_li;
  logic [(m_axil_data_width_p/8)-1:0] m_fifo_wmask_li;
  logic [m_axil_data_width_p-1:0] m_fifo_data_lo;
  logic m_fifo_ready_and_li, m_fifo_v_lo;
  bsg_axil_fifo_master
   #(.axil_data_width_p(m_axil_data_width_p), .axil_addr_width_p(m_axil_addr_width_p))
   sbi_bridge
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(m_fifo_data_li)
     ,.addr_i(m_fifo_addr_li)
     ,.v_i(m_fifo_v_li)
     ,.w_i(m_fifo_w_li)
     ,.wmask_i(m_fifo_wmask_li)
     ,.ready_and_o(m_fifo_ready_and_lo)

     ,.data_o(m_fifo_data_lo)
     ,.v_o(m_fifo_v_lo)
     ,.ready_and_i(m_fifo_ready_and_li)

     ,.*
     );

  // only allow 1 req at a time
  logic outstanding_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   outstanding_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(master_gnt_li)
     ,.clear_i(master_r_valid_li)
     ,.data_o(outstanding_r)
     );

  always_comb
    begin
      state_n = state_r;

      m_fifo_v_li = '0;
      m_fifo_w_li = '0;
      m_fifo_wmask_li = '0;
      m_fifo_data_li = '0;
      m_fifo_addr_li= '0;

      master_gnt_li = '0;

      master_r_valid_li = '0;
      master_r_err_li = '0;
      master_r_other_err_li = '0;
      master_r_rdata_li = '0;

      // DM is always ready and we only do stores for debug_req
      m_fifo_ready_and_li = 1'b1;

      unique casez (state_r)
        e_ready:
          m_fifo_v_li = master_req_lo;
          m_fifo_w_li = master_we_lo;
          m_fifo_wmask_li = master_be_lo;
          m_fifo_data_li = master_wdata_lo;
          m_fifo_addr_li = master_add_lo;
          master_gnt_li = m_fifo_ready_and_lo & m_fifo_v_li;

          master_r_valid_li = m_fifo_v_lo;
          master_r_rdata_li = m_fifo_data_lo;

          state_n = (debug_req & ~outstanding_r) ? e_send_npc : state_r;
        e_send_npc:
          begin
            m_fifo_v_li = ~outstanding_r;
            m_fifo_w_li = 1'b1;
            m_fifo_wmask_li = '1;
            // TODO: Parameterize
            m_fifo_data_li = 0x130800;
            m_fifo_addr_li = 0x200010;

            state_n = master_r_valid_li ? e_send_hireq : state_r;
          end
        e_send_hireq:
          begin
            m_fifo_v_li = ~outstanding_r;
            m_fifo_w_li = 1'b1;
            m_fifo_wmask_li = '1;
            // TODO: Parameterize
            m_fifo_data_li = 0x1;
            m_fifo_addr_li = 0x30c000;

            state_n = master_r_valid_li ? e_send_loreq : state_r;
          end
        e_send_loreq:
          begin
            m_fifo_v_li = ~outstanding_r;
            m_fifo_w_li = 1'b1;
            m_fifo_wmask_li = '1;
            // TODO: Parameterize
            m_fifo_data_li = 0x0;
            m_fifo_addr_li = 0x30c000;

            state_n = master_r_valid_li ? e_lower_req : state_r;
          end
        e_unfreeze:
          begin
            m_fifo_v_li = ~outstanding_r;
            m_fifo_w_li = 1'b1;
            m_fifo_wmask_li = '1;
            // TODO: Parameterize
            m_fifo_data_li = 0x0;
            m_fifo_addr_li = 0x200008;

            state_n = master_r_valid_li ? e_ready : state_r;
          end
        e_drain: state_n = !debug_req ? e_ready : state_r;
        default: begin end
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

endmodule

