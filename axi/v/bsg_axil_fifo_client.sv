
`include "bsg_defines.v"

module bsg_axil_fifo_client
 import bsg_axi_pkg::*;
 #(parameter `BSG_INV_PARAM(axil_data_width_p)
   , parameter `BSG_INV_PARAM(axil_addr_width_p)
   , parameter `BSG_INV_PARAM(fifo_els_p)

   , localparam axil_mask_width_lp = axil_data_width_p >> 3
   )
  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   , output logic [axil_data_width_p-1:0]       data_o
   , output logic [axil_addr_width_p-1:0]       addr_o
   , output logic                               v_o
   , output logic                               w_o
   , output logic [axil_mask_width_lp-1:0]      wmask_o
   , input                                      ready_and_i

   , input [axil_data_width_p-1:0]              data_i
   , input                                      v_i
   , output logic                               ready_and_o

   //====================== AXI-4 LITE =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_awaddr_i
   , input [2:0]                                s_axil_awprot_i
   , input                                      s_axil_awvalid_i
   , output logic                               s_axil_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [axil_data_width_p-1:0]              s_axil_wdata_i
   , input [axil_mask_width_lp-1:0]             s_axil_wstrb_i
   , input                                      s_axil_wvalid_i
   , output logic                               s_axil_wready_o

   // WRITE RESPONSE CHANNEL SIGNALS
   , output [1:0]                               s_axil_bresp_o
   , output logic                               s_axil_bvalid_o
   , input                                      s_axil_bready_i

   // READ ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_araddr_i
   , input [2:0]                                s_axil_arprot_i
   , input                                      s_axil_arvalid_i
   , output logic                               s_axil_arready_o

   // READ DATA CHANNEL SIGNALS
   , output logic [axil_data_width_p-1:0]       s_axil_rdata_o
   , output [1:0]                               s_axil_rresp_o
   , output logic                               s_axil_rvalid_o
   , input                                      s_axil_rready_i
  );

  wire unused = &{s_axil_awprot_i, s_axil_arprot_i};
  assign s_axil_bresp_o = e_axi_resp_okay;
  assign s_axil_rresp_o = e_axi_resp_okay;

  logic [axil_addr_width_p-1:0] araddr_li;
  logic araddr_v_li, araddr_yumi_lo;
  bsg_fifo_1r1w_small
   #(.width_p(axil_addr_width_p), .els_p(fifo_els_p))
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
  bsg_fifo_1r1w_small
   #(.width_p(axil_addr_width_p), .els_p(fifo_els_p))
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
  logic [axil_mask_width_lp-1:0] wmask_li;
  logic wdata_v_li, wdata_yumi_lo;
  bsg_fifo_1r1w_small
   #(.width_p(axil_mask_width_lp+axil_data_width_p), .els_p(fifo_els_p))
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

  logic return_v_li, return_ready_lo, return_w_lo, return_v_lo, return_yumi_li;
  bsg_fifo_1r1w_small
   #(.width_p(1), .els_p(fifo_els_p), .ready_THEN_valid_p(1))
   return_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(w_o)
     ,.v_i(return_v_li)
     ,.ready_o(return_ready_lo)

     ,.data_o(return_w_lo)
     ,.v_o(return_v_lo)
     ,.yumi_i(return_yumi_li)
     );

  // Align read addresses to bus width (per axil spec)
  // TODO: Replace with https://github.com/bespoke-silicon-group/basejump_stl/pull/565/files
  `ifndef BSG_ALIGN
  `define BSG_ALIGN(addr_mp, nb_mp) \
    ({addr_mp[$bits(addr_mp)-1:$clog2(nb_mp)], {$clog2(nb_mp){1'b0}}}) 
  `endif

  // Prioritize reads over writes
  assign addr_o  = araddr_v_li ? `BSG_ALIGN(araddr_li, axil_mask_width_lp) : awaddr_li;
  assign data_o  = wdata_li;
  assign v_o     = return_ready_lo & (araddr_v_li | (awaddr_v_li & wdata_v_li));
  assign w_o     = ~araddr_v_li;
  assign wmask_o = wmask_li;

  assign araddr_yumi_lo = ready_and_i & v_o & araddr_v_li;
  assign awaddr_yumi_lo = ready_and_i & v_o & ~araddr_v_li;
  assign wdata_yumi_lo = awaddr_yumi_lo;

  assign s_axil_rdata_o  = data_i;
  assign s_axil_rvalid_o = v_i & ~return_w_lo;
  assign s_axil_bvalid_o = v_i &  return_w_lo;

  assign ready_and_o = (return_v_lo & return_w_lo & s_axil_bready_i) | (return_v_lo & ~return_w_lo & s_axil_rready_i);

  assign return_v_li = ready_and_i & v_o;
  assign return_yumi_li = ready_and_o & v_i;

endmodule

