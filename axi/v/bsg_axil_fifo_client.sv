
`include "bsg_defines.v"

module bsg_axil_fifo_client
 import bsg_axi_pkg::*;
 #(parameter `BSG_INV_PARAM(axil_data_width_p)
   , parameter `BSG_INV_PARAM(axil_addr_width_p)

   , localparam axi_mask_width_lp = axil_data_width_p >> 3
   )
  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   , output logic [axil_data_width_p-1:0]       data_o
   , output logic [axil_addr_width_p-1:0]       addr_o
   , output logic                               v_o
   , output logic                               w_o
   , output logic [(axil_data_width_p>>3)-1:0]  wmask_o
   , input                                      ready_and_i

   , input [axil_data_width_p-1:0]              data_i
   , input                                      v_i
   , output logic                               ready_and_o

   //====================== AXI-4 LITE =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_awaddr_i
   , input axi_prot_type_e                      s_axil_awprot_i
   , input                                      s_axil_awvalid_i
   , output logic                               s_axil_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [axil_data_width_p-1:0]              s_axil_wdata_i
   , input [(axil_data_width_p>>3)-1:0]         s_axil_wstrb_i
   , input                                      s_axil_wvalid_i
   , output logic                               s_axil_wready_o

   // WRITE RESPONSE CHANNEL SIGNALS
   , output axi_resp_type_e                     s_axil_bresp_o
   , output logic                               s_axil_bvalid_o
   , input                                      s_axil_bready_i

   // READ ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_araddr_i
   , input axi_prot_type_e                      s_axil_arprot_i
   , input                                      s_axil_arvalid_i
   , output logic                               s_axil_arready_o

   // READ DATA CHANNEL SIGNALS
   , output logic [axil_data_width_p-1:0]       s_axil_rdata_o
   , output axi_resp_type_e                     s_axil_rresp_o
   , output logic                               s_axil_rvalid_o
   , input                                      s_axil_rready_i
  );

  enum logic [1:0] {e_wait, e_read_rx, e_write_rx} state_n, state_r;
  wire is_wait     = (state_r == e_wait);
  wire is_read_rx  = (state_r == e_read_rx);
  wire is_write_rx = (state_r == e_write_rx);

  wire unused = &{s_axil_awprot_i, s_axil_arprot_i};
  assign s_axil_bresp_o = e_axi_resp_okay;
  assign s_axil_rresp_o = e_axi_resp_okay;

  logic [axil_addr_width_p-1:0] araddr_li;
  logic araddr_v_li, araddr_yumi_lo;
  bsg_one_fifo
   #(.width_p(axil_addr_width_p))
   araddr_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(s_axil_araddr_i)
     ,.v_i(s_axil_arvalid_i)
     ,.ready_o(s_axil_arready_o)

     ,.data_o(araddr_li)
     ,.v_o(araddr_v_li)
     ,.yumi_i(araddr_yumi_lo)
     );

  logic [axil_addr_width_p-1:0] awaddr_li;
  logic awaddr_v_li, awaddr_yumi_lo;
  bsg_one_fifo
   #(.width_p(axil_addr_width_p))
   awaddr_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(s_axil_awaddr_i)
     ,.v_i(s_axil_awvalid_i)
     ,.ready_o(s_axil_awready_o)

     ,.data_o(awaddr_li)
     ,.v_o(awaddr_v_li)
     ,.yumi_i(awaddr_yumi_lo)
     );

  logic [axil_data_width_p-1:0] wdata_li;
  logic [axil_data_width_p-1:0] wmask_li;
  logic wdata_v_li, wdata_yumi_lo;
  bsg_one_fifo
   #(.width_p(axi_mask_width_lp+axil_data_width_p))
   wdata_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({s_axil_wstrb_i, s_axil_wdata_i})
     ,.v_i(s_axil_wvalid_i)
     ,.ready_o(s_axil_wready_o)

     ,.data_o({wmask_li, wdata_li})
     ,.v_o(wdata_v_li)
     ,.yumi_i(wdata_yumi_lo)
     );

  assign araddr_yumi_lo = is_wait & ready_and_i & araddr_v_li;
  assign awaddr_yumi_lo = is_wait & ready_and_i & ~araddr_v_li & awaddr_v_li & wdata_v_li;
  assign wdata_yumi_lo = awaddr_yumi_lo;

  // Prioritize reads over writes
  assign data_o  = wdata_li;
  assign addr_o  = araddr_v_li ? araddr_li : awaddr_li;
  assign v_o     = araddr_v_li | (awaddr_v_li & wdata_v_li);
  assign w_o     = ~araddr_v_li;
  assign wmask_o = wmask_li;

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_wait;
    else
      state_r <= state_n;

  always_comb
    case (state_r)
      e_wait: state_n = araddr_yumi_lo
                        ? e_read_rx
                        : awaddr_yumi_lo
                          ? e_write_rx
                          : e_wait;
      default: state_n = (v_i & ready_and_o) ? e_wait : state_r;
    endcase
  assign ready_and_o = (is_read_rx & s_axil_rready_i) | (is_write_rx & s_axil_bready_i);

  assign s_axil_rdata_o  = data_i;
  assign s_axil_rvalid_o = is_read_rx & v_i;
  assign s_axil_bvalid_o = is_write_rx & v_i;

endmodule

