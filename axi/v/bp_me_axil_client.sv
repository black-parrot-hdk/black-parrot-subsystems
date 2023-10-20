
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_axil_client
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

  // AXI CHANNEL PARAMS
  , parameter `BSG_INV_PARAM(axil_data_width_p)
  , parameter `BSG_INV_PARAM(axil_addr_width_p)
  , parameter `BSG_INV_PARAM(axi_async_p)
  , parameter `BSG_INV_PARAM(async_fifo_size_p)
  , localparam axil_mask_width_lp = axil_data_width_p>>3
  )

  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i
   , input                                      aclk_i
   , input                                      areset_i

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

  wire aclk_li   = axi_async_p ? aclk_i   : clk_i;
  wire areset_li = axi_async_p ? areset_i : reset_i;

  bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
  bp_bedrock_mem_rev_header_s mem_rev_header_li;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_lo, mem_rev_data_li;
  logic mem_fwd_v_lo, mem_fwd_ready_and_li, mem_fwd_full_lo;
  logic mem_rev_v_li, mem_rev_ready_and_lo, mem_rev_full_lo;

  if(axi_async_p) begin: async
    assign mem_fwd_ready_and_li = ~mem_fwd_full_lo;
    bsg_async_fifo
     #(.width_p($bits({mem_fwd_header_o, mem_fwd_data_o}))
       ,.lg_size_p(async_fifo_size_p)
       )
     axil2io_fwd
      (.w_clk_i(aclk_li)
       ,.w_reset_i(areset_li)

       ,.w_enq_i(mem_fwd_v_lo & ~mem_fwd_full_lo)
       ,.w_data_i({mem_fwd_header_lo, mem_fwd_data_lo})
       ,.w_full_o(mem_fwd_full_lo)

       ,.r_clk_i(clk_i)
       ,.r_reset_i(reset_i)

       ,.r_deq_i(mem_fwd_ready_and_i & mem_fwd_v_o)
       ,.r_data_o({mem_fwd_header_o, mem_fwd_data_o})
       ,.r_valid_o(mem_fwd_v_o)
       );

    assign mem_rev_ready_and_o = ~mem_rev_full_lo;
    bsg_async_fifo
     #(.width_p($bits({mem_rev_header_i, mem_rev_data_i}))
       ,.lg_size_p(async_fifo_size_p)
       )
     axil2io_rev
      (.w_clk_i(clk_i)
       ,.w_reset_i(reset_i)

        ,.w_enq_i(mem_rev_v_i & ~mem_rev_full_lo)
        ,.w_data_i({mem_rev_header_i, mem_rev_data_i})
        ,.w_full_o(mem_rev_full_lo)

        ,.r_clk_i(aclk_li)
        ,.r_reset_i(areset_li)

        ,.r_deq_i(mem_rev_ready_and_lo & mem_rev_v_li)
        ,.r_data_o({mem_rev_header_li, mem_rev_data_li})
        ,.r_valid_o(mem_rev_v_li)
        );
  end
  else begin
    assign mem_fwd_v_o           = mem_fwd_v_lo;
    assign mem_fwd_data_o        = mem_fwd_data_lo;
    assign mem_fwd_header_o      = mem_fwd_header_lo;
    assign mem_fwd_ready_and_li  = mem_fwd_ready_and_i;

    assign mem_rev_v_li          = mem_rev_v_i;
    assign mem_rev_data_li       = mem_rev_data_i;
    assign mem_rev_header_li     = mem_rev_header_i;
    assign mem_rev_ready_and_o   = mem_rev_ready_and_lo;
  end



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
    (.clk_i(aclk_li)
     ,.reset_i(areset_li)

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

  localparam lg_axil_mask_width_lp = `BSG_SAFE_CLOG2(axil_mask_width_lp);
  always_comb
    begin
      mem_fwd_data_lo = wdata_lo;
      mem_fwd_header_lo = '0;
      mem_fwd_header_lo.payload.lce_id = lce_id_i;
      mem_fwd_header_lo.payload.did    = did_i;
      mem_fwd_header_lo.addr           = addr_lo;
      mem_fwd_header_lo.msg_type       = w_lo ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
      if (~w_lo) begin
        // reads are full width
        mem_fwd_header_lo.size = bp_bedrock_msg_size_e'(lg_axil_mask_width_lp);
      end else begin
        // TODO: check address aligned with write strobes and for error cases (including mask 'h00),
        // reply with AXIL error response, and do not send BedRock message.
        case (wmask_lo)
          axil_mask_width_lp'('h80)
          ,axil_mask_width_lp'('h40)
          ,axil_mask_width_lp'('h20)
          ,axil_mask_width_lp'('h10)
          ,axil_mask_width_lp'('h08)
          ,axil_mask_width_lp'('h04)
          ,axil_mask_width_lp'('h02)
          ,axil_mask_width_lp'('h01): mem_fwd_header_lo.size = e_bedrock_msg_size_1;
          axil_mask_width_lp'('hC0)
          ,axil_mask_width_lp'('h30)
          ,axil_mask_width_lp'('h0C)
          ,axil_mask_width_lp'('h03): mem_fwd_header_lo.size = e_bedrock_msg_size_2;
          axil_mask_width_lp'('hF0)
          ,axil_mask_width_lp'('h0F): mem_fwd_header_lo.size = e_bedrock_msg_size_4;
          axil_mask_width_lp'('hFF): mem_fwd_header_lo.size = e_bedrock_msg_size_8;
          default: mem_fwd_header_lo.size = e_bedrock_msg_size_8;
        endcase
      end

      mem_fwd_v_lo = v_lo;
      ready_and_li = mem_fwd_ready_and_li;
    end

  always_comb
    begin
      rdata_li = mem_rev_data_li;
      v_li = mem_rev_v_li;
      mem_rev_ready_and_lo = ready_and_lo;
    end

endmodule

