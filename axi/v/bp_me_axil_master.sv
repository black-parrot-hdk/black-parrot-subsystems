
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

// This module is a minimal axi-lite master, supporting a single outgoing request.
// It could be extended to support pipelined accesses by adding input skid
//   buffers at the cost of additional area.

module bp_me_axil_master
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

  // AXI WRITE DATA CHANNEL PARAMS
  , parameter `BSG_INV_PARAM(axil_data_width_p)
  , parameter `BSG_INV_PARAM(axil_addr_width_p)
  , localparam axil_mask_width_lp = (axil_data_width_p>>3)

  , parameter axi_async_p = 0
  , parameter `BSG_INV_PARAM(async_fifo_size_p)
 )
 (//==================== GLOBAL SIGNALS =======================
  input                                        clk_i
  , input                                      reset_i
  , input                                      aclk_i
  , input                                      areset_i

  //==================== BP-STREAM SIGNALS ======================
  , input [mem_fwd_header_width_lp-1:0]        mem_fwd_header_i
  , input [bedrock_fill_width_p-1:0]           mem_fwd_data_i
  , input                                      mem_fwd_v_i
  , output logic                               mem_fwd_ready_and_o

  , output logic [mem_rev_header_width_lp-1:0] mem_rev_header_o
  , output logic [bedrock_fill_width_p-1:0]    mem_rev_data_o
  , output logic                               mem_rev_v_o
  , input                                      mem_rev_ready_and_i

  //====================== AXI-4 LITE =========================
  // WRITE ADDRESS CHANNEL SIGNALS
  , output logic [axil_addr_width_p-1:0]       m_axil_awaddr_o
  , output logic [2:0]                         m_axil_awprot_o
  , output logic                               m_axil_awvalid_o
  , input                                      m_axil_awready_i

  // WRITE DATA CHANNEL SIGNALS
  , output logic [axil_data_width_p-1:0]       m_axil_wdata_o
  , output logic [axil_mask_width_lp-1:0]      m_axil_wstrb_o
  , output logic                               m_axil_wvalid_o
  , input                                      m_axil_wready_i

  // WRITE RESPONSE CHANNEL SIGNALS
  , input [1:0]                                m_axil_bresp_i
  , input                                      m_axil_bvalid_i
  , output logic                               m_axil_bready_o

  // READ ADDRESS CHANNEL SIGNALS
  , output logic [axil_addr_width_p-1:0]       m_axil_araddr_o
  , output logic [2:0]                         m_axil_arprot_o
  , output logic                               m_axil_arvalid_o
  , input                                      m_axil_arready_i

  // READ DATA CHANNEL SIGNALS
  , input [axil_data_width_p-1:0]              m_axil_rdata_i
  , input [1:0]                                m_axil_rresp_i
  , input                                      m_axil_rvalid_i
  , output logic                               m_axil_rready_o
  );

  logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_li;
  logic [mem_rev_header_width_lp-1:0] mem_rev_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_li, mem_rev_data_lo;
  logic mem_fwd_last_li, mem_rev_last_lo;
  logic mem_fwd_v_li, mem_fwd_full_lo, mem_fwd_ready_and_lo;
  logic mem_rev_v_lo, mem_rev_full_li, mem_rev_ready_and_li;

  wire aclk_li   = axi_async_p ? aclk_i   : clk_i;
  wire areset_li = axi_async_p ? areset_i : reset_i;

  if(axi_async_p)
    begin: async
      bsg_async_fifo
        #(  .width_p($bits({mem_fwd_header_i, mem_fwd_data_i}))
            , .lg_size_p(async_fifo_size_p))
        io2axil_fwd
          (   .w_clk_i(clk_i)
            , .w_reset_i(reset_i)

            , .w_enq_i(mem_fwd_v_i & ~mem_fwd_full_lo)
            , .w_data_i({mem_fwd_header_i, mem_fwd_data_i})
            , .w_full_o(mem_fwd_full_lo)

            , .r_clk_i(aclk_li)
            , .r_reset_i(areset_li)

            , .r_deq_i(mem_fwd_ready_and_lo & mem_fwd_v_li)
            , .r_data_o({mem_fwd_header_li, mem_fwd_data_li})
            , .r_valid_o(mem_fwd_v_li)
           );
      assign mem_fwd_ready_and_o = ~mem_fwd_full_lo;

      bsg_async_fifo
        #(  .width_p($bits({mem_rev_header_o, mem_rev_data_o}))
            , .lg_size_p(async_fifo_size_p))
        io2axil_rev
          (   .w_clk_i(aclk_li)
            , .w_reset_i(areset_li)

            , .w_enq_i(mem_rev_v_lo & ~mem_rev_full_li)
            , .w_data_i({mem_rev_header_lo, mem_rev_data_lo})
            , .w_full_o(mem_rev_full_li)

            , .r_clk_i(clk_i)
            , .r_reset_i(reset_i)

            , .r_deq_i(mem_rev_ready_and_i & mem_rev_v_o)
            , .r_data_o({mem_rev_header_o, mem_rev_data_o})
            , .r_valid_o(mem_rev_v_o)
           );
      assign mem_rev_ready_and_li = ~mem_rev_full_li;
    end
  else
    begin
      assign mem_fwd_v_li         = mem_fwd_v_i;
      assign mem_fwd_data_li      = mem_fwd_data_i;
      assign mem_fwd_header_li    = mem_fwd_header_i;
      assign mem_fwd_ready_and_o  = mem_fwd_ready_and_lo;

      assign mem_rev_v_o          = mem_rev_v_lo;
      assign mem_rev_data_o       = mem_rev_data_lo;
      assign mem_rev_header_o     = mem_rev_header_lo;
      assign mem_rev_ready_and_li = mem_rev_ready_and_i;
    end

  // declaring i/o command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  bp_bedrock_mem_fwd_header_s mem_fwd_header_cast_li;
  assign mem_fwd_header_cast_li = mem_fwd_header_li;

  bp_bedrock_mem_rev_header_s mem_rev_header_cast_lo;
  assign mem_rev_header_lo = mem_rev_header_cast_lo;

  bp_bedrock_mem_fwd_header_s fsm_fwd_header_li;
  logic [bedrock_fill_width_p-1:0] fsm_fwd_data_li;
  logic fsm_fwd_v_li, fsm_fwd_yumi_lo;
  logic [paddr_width_p-1:0] fsm_fwd_addr_li;
  logic fsm_fwd_new_li, fsm_fwd_critical_li, fsm_fwd_last_li;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.fsm_data_width_p(bedrock_fill_width_p)
     ,.block_width_p(bedrock_block_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     )
   fwd_pump_in
    (.clk_i(aclk_li)
     ,.reset_i(areset_li)

     ,.msg_header_i(mem_fwd_header_cast_li)
     ,.msg_data_i(mem_fwd_data_li)
     ,.msg_v_i(mem_fwd_v_li)
     ,.msg_ready_and_o(mem_fwd_ready_and_lo)

     ,.fsm_header_o(fsm_fwd_header_li)
     ,.fsm_data_o(fsm_fwd_data_li)
     ,.fsm_v_o(fsm_fwd_v_li)
     ,.fsm_yumi_i(fsm_fwd_yumi_lo)
     ,.fsm_addr_o(fsm_fwd_addr_li)
     ,.fsm_new_o(fsm_fwd_new_li)
     ,.fsm_critical_o(fsm_fwd_critical_li)
     ,.fsm_last_o(fsm_fwd_last_li)
     );


  bp_bedrock_mem_rev_header_s fsm_rev_header_li;
  logic [bedrock_fill_width_p-1:0] fsm_rev_data_li;
  logic fsm_rev_v_li, fsm_rev_ready_and_lo;
  logic [paddr_width_p-1:0] fsm_rev_addr_lo;
  logic fsm_rev_new_lo, fsm_rev_critical_lo, fsm_rev_last_lo;
  logic stream_fifo_ready_and_lo;
  bsg_two_fifo
   #(.width_p($bits(bp_bedrock_mem_fwd_header_s)))
   stream_fifo
    (.clk_i(aclk_li)
     ,.reset_i(areset_li)

     ,.data_i(fsm_fwd_header_li)
     ,.v_i(fsm_fwd_yumi_lo & fsm_fwd_new_li)
     ,.ready_o(stream_fifo_ready_and_lo)

     ,.data_o(fsm_rev_header_li)
     ,.v_o(stream_header_v_lo)
     ,.yumi_i(fsm_rev_ready_and_lo & fsm_rev_v_li & fsm_rev_last_lo)
     );

  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.fsm_data_width_p(bedrock_fill_width_p)
     ,.block_width_p(bedrock_block_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     )
   rev_pump_out
    (.clk_i(aclk_li)
     ,.reset_i(areset_li)

     ,.msg_header_o(mem_rev_header_cast_lo)
     ,.msg_data_o(mem_rev_data_lo)
     ,.msg_v_o(mem_rev_v_lo)
     ,.msg_ready_and_i(mem_rev_ready_and_li)

     ,.fsm_header_i(fsm_rev_header_li)
     ,.fsm_data_i(fsm_rev_data_li)
     ,.fsm_v_i(fsm_rev_v_li)
     ,.fsm_ready_and_o(fsm_rev_ready_and_lo)
     ,.fsm_addr_o(fsm_rev_addr_lo)
     ,.fsm_new_o(fsm_rev_new_lo)
     ,.fsm_critical_o(fsm_rev_critical_lo)
     ,.fsm_last_o(fsm_rev_last_lo)
     );

  logic [axil_data_width_p-1:0] wdata_li;
  logic [axil_addr_width_p-1:0] addr_li;
  logic v_li, w_li, ready_and_lo;
  logic [axil_mask_width_lp-1:0] wmask_li;

  localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(axil_mask_width_lp);
  wire [byte_offset_width_lp-1:0] mask_shift = addr_li[0+:byte_offset_width_lp];

  always_comb
    begin
      wdata_li = fsm_fwd_data_li;
      addr_li = fsm_fwd_header_li.addr;
      v_li = fsm_fwd_v_li;
      w_li = fsm_fwd_header_li.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr};
      fsm_fwd_yumi_lo = fsm_fwd_v_li & ready_and_lo & stream_fifo_ready_and_lo;

      case (fsm_fwd_header_li.size)
        e_bedrock_msg_size_1: wmask_li = (axil_mask_width_lp)'('h1) << mask_shift;
        e_bedrock_msg_size_2: wmask_li = (axil_mask_width_lp)'('h3) << mask_shift;
        e_bedrock_msg_size_4: wmask_li = (axil_mask_width_lp)'('hF) << mask_shift;
        // e_bedrock_msg_size_8:
        default : wmask_li = (axil_mask_width_lp)'('hFF);
      endcase
    end

  localparam size_width_lp = `BSG_WIDTH(byte_offset_width_lp);

  wire [byte_offset_width_lp-1:0] resp_sel_li = fsm_rev_header_li.addr[0+:byte_offset_width_lp];
  wire [size_width_lp-1:0] resp_size_li = fsm_rev_header_li.size;
  logic [axil_data_width_p-1:0] rdata_lo;
  bsg_bus_pack
   #(.in_width_p(axil_data_width_p), .out_width_p(bedrock_fill_width_p))
   resp_data_bus_pack
    (.data_i(rdata_lo)
     ,.sel_i(resp_sel_li)
     ,.size_i(resp_size_li)
     ,.data_o(fsm_rev_data_li)
     );

  logic v_lo, yumi_li;
  always_comb
    begin
      fsm_rev_v_li = stream_header_v_lo & v_lo;
      yumi_li = fsm_rev_ready_and_lo & fsm_rev_v_li;
    end

  bsg_axil_fifo_master
   #(.axil_data_width_p(axil_data_width_p)
     ,.axil_addr_width_p(axil_addr_width_p)
     )
   fifo_master
    (.clk_i(aclk_li)
     ,.reset_i(areset_li)

     ,.data_i(wdata_li)
     ,.addr_i(addr_li)
     ,.v_i(v_li)
     ,.w_i(w_li)
     ,.wmask_i(wmask_li)
     ,.ready_and_o(ready_and_lo)

     ,.data_o(rdata_lo)
     ,.v_o(v_lo)
     ,.ready_and_i(yumi_li)

     ,.*
     );


endmodule
