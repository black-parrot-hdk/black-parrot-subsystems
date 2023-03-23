
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
  )

  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   //==================== BP-STREAM SIGNALS ======================
   , input [lce_id_width_p-1:0]                 lce_id_i
   , input [did_width_p-1:0]                    did_i

   , output logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]    mem_fwd_data_o
   , output logic                               mem_fwd_v_o
   , input                                      mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]        mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]           mem_rev_data_i
   , input                                      mem_rev_v_i
   , output logic                               mem_rev_ready_and_o

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

  // declaring i/o command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  logic [axil_data_width_p-1:0] wdata_lo;
  logic [axil_addr_width_p-1:0] addr_lo;
  logic v_lo, w_lo, ready_and_li;
  logic [axil_mask_width_lp-1:0] wmask_lo;

  logic [axil_data_width_p-1:0] rdata_li;
  logic v_li, ready_and_lo;
  bsg_axil_fifo_client
   #(.axil_data_width_p(axil_data_width_p)
     ,.axil_addr_width_p(axil_addr_width_p)
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
      mem_fwd_data_o = wdata_lo;
      mem_fwd_header_cast_o = '0;
      mem_fwd_header_cast_o.payload.lce_id = lce_id_i;
      mem_fwd_header_cast_o.payload.did    = did_i;
      mem_fwd_header_cast_o.addr           = addr_lo;
      mem_fwd_header_cast_o.msg_type       = w_lo ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
      if (~w_lo) begin
        // reads are full width
        mem_fwd_header_cast_o.size = bp_bedrock_msg_size_e'(lg_axil_mask_width_lp);
      end else begin
        case (wmask_lo)
          axil_mask_width_lp'('h80)
          ,axil_mask_width_lp'('h40)
          ,axil_mask_width_lp'('h20)
          ,axil_mask_width_lp'('h10)
          ,axil_mask_width_lp'('h08)
          ,axil_mask_width_lp'('h04)
          ,axil_mask_width_lp'('h02): mem_fwd_header_cast_o.size = e_bedrock_msg_size_1;
          axil_mask_width_lp'('hC0)
          ,axil_mask_width_lp'('h30)
          ,axil_mask_width_lp'('h0C)
          ,axil_mask_width_lp'('h03): mem_fwd_header_cast_o.size = e_bedrock_msg_size_2;
          axil_mask_width_lp'('hF0)
          ,axil_mask_width_lp'('h0F): mem_fwd_header_cast_o.size = e_bedrock_msg_size_4;
          // axil_mask_width_lp'('hFF):
          default: mem_fwd_header_cast_o.size = e_bedrock_msg_size_8;
        endcase
      end

      mem_fwd_v_o = v_lo;
      ready_and_li = mem_fwd_ready_and_i;
    end

  always_comb
    begin
      rdata_li = mem_rev_data_i;
      v_li = mem_rev_v_i;
      mem_rev_ready_and_o = ready_and_lo;
    end

endmodule

