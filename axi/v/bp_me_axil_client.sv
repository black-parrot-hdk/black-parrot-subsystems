
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_axil_client
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

  // AXI CHANNEL PARAMS
  , parameter axil_data_width_p = 32
  , parameter axil_addr_width_p = 32
  , localparam axil_mask_width_lp = axil_data_width_p>>3
  , parameter num_outstanding_p = 8
  )

  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   //==================== BP-STREAM SIGNALS ======================
   , input [lce_id_width_p-1:0]                 lce_id_i
   , input [did_width_p-1:0]                    did_i

   , output logic [mem_header_width_lp-1:0]     io_cmd_header_o
   , output logic [axil_data_width_p-1:0]       io_cmd_data_o
   , output logic                               io_cmd_v_o
   , input                                      io_cmd_ready_and_i
   , output logic                               io_cmd_last_o

   , input [mem_header_width_lp-1:0]            io_resp_header_i
   , input [axil_data_width_p-1:0]              io_resp_data_i
   , input                                      io_resp_v_i
   , output logic                               io_resp_ready_and_o
   , input                                      io_resp_last_i

   //====================== AXI-4 LITE =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_awaddr_i
   , input [2:0]                                s_axil_awprot_i
   , input                                      s_axil_awvalid_i
   , output logic                               s_axil_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [axil_data_width_p-1:0]              s_axil_wdata_i
   , input [(axil_data_width_p>>3)-1:0]         s_axil_wstrb_i
   , input                                      s_axil_wvalid_i
   , output logic                               s_axil_wready_o

   // WRITE RESPONSE CHANNEL SIGNALS
   , output logic [1:0]                         s_axil_bresp_o
   , output logic                               s_axil_bvalid_o
   , input                                      s_axil_bready_i

   // READ ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_araddr_i
   , input [2:0]                                s_axil_arprot_i
   , input                                      s_axil_arvalid_i
   , output logic                               s_axil_arready_o

   // READ DATA CHANNEL SIGNALS
   , output logic [axil_data_width_p-1:0]       s_axil_rdata_o
   , output logic [1:0]                         s_axil_rresp_o
   , output logic                               s_axil_rvalid_o
   , input                                      s_axil_rready_i
   );

  wire unused = &{io_resp_last_i};
  assign io_cmd_last_o = io_cmd_v_o;

  // declaring i/o command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, io_resp_header);

  logic [axil_data_width_p-1:0] wdata_lo;
  logic [axil_addr_width_p-1:0] addr_lo;
  logic v_lo, w_lo, ready_and_li;
  logic [axil_mask_width_lp-1:0] wmask_lo;

  logic [axil_data_width_p-1:0] rdata_li;
  logic v_li, ready_and_lo;
  bsg_axil_fifo_client
   #(.axil_data_width_p(axil_data_width_p)
     ,.axil_addr_width_p(axil_addr_width_p)
     ,.fifo_els_p(num_outstanding_p)
     )
   fifo_client
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_o(wdata_lo)
     ,.addr_o(addr_lo)
     ,.v_o(v_lo)
     ,.w_o(w_lo)
     ,.wmask_o(wmask_lo)
     ,.ready_and_i(ready_and_li)

     ,.data_i(rdata_li)
     ,.v_i(v_li)
     ,.ready_and_o(ready_and_lo)

     ,.*
     );

  always_comb
    begin
      io_cmd_data_o = wdata_lo;
      io_cmd_header_cast_o = '0;
      io_cmd_header_cast_o.payload.lce_id = lce_id_i;
      io_cmd_header_cast_o.payload.did    = did_i;
      io_cmd_header_cast_o.addr           = addr_lo;
      io_cmd_header_cast_o.msg_type       = w_lo ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
      case (wmask_lo)
        axil_mask_width_lp'('h1): io_cmd_header_cast_o.size = e_bedrock_msg_size_1;
        axil_mask_width_lp'('h3): io_cmd_header_cast_o.size = e_bedrock_msg_size_2;
        axil_mask_width_lp'('hF): io_cmd_header_cast_o.size = e_bedrock_msg_size_4;
        // axil_mask_width_lp'('hFF):
        default: io_cmd_header_cast_o.size = e_bedrock_msg_size_8;
      endcase

      io_cmd_v_o = v_lo;
      ready_and_li = io_cmd_ready_and_i;
    end

  always_comb
    begin
      rdata_li = io_resp_data_i;
      v_li = io_resp_v_i;
      io_resp_ready_and_o = ready_and_lo;
    end

endmodule

