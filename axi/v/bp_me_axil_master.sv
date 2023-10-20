
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
  `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

  // AXI WRITE DATA CHANNEL PARAMS
  , parameter `BSG_INV_PARAM(axil_data_width_p)
  , parameter `BSG_INV_PARAM(axil_addr_width_p)
  , localparam axil_mask_width_lp = (axil_data_width_p>>3)
  )
 (//==================== GLOBAL SIGNALS =======================
  input                                        clk_i
  , input                                      reset_i

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

  // declaring i/o command and response struct type and size
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  bp_bedrock_mem_fwd_header_s fsm_fwd_header_li;
  logic [axil_data_width_p-1:0] fsm_fwd_data_li;
  logic fsm_fwd_v_li, fsm_fwd_yumi_lo;
  logic [paddr_width_p-1:0] fsm_fwd_addr_li;
  logic fsm_fwd_new_li, fsm_fwd_critical_li, fsm_fwd_last_li;
  bp_bedrock_mem_rev_header_s fsm_rev_header_lo;
  logic [axil_data_width_p-1:0] fsm_rev_data_lo;
  logic fsm_rev_v_lo, fsm_rev_ready_then_li;
  logic [paddr_width_p-1:0] fsm_rev_addr_li;
  logic fsm_rev_new_li, fsm_rev_critical_li, fsm_rev_last_li;

  bp_me_stream_pump
   #(.bp_params_p(bp_params_p)
     ,.in_data_width_p(axil_data_width_p)
     ,.in_payload_width_p(mem_fwd_payload_width_lp)
     ,.in_msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.in_fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     ,.out_data_width_p(axil_data_width_p)
     ,.out_payload_width_p(mem_rev_payload_width_lp)
     ,.out_msg_stream_mask_p(mem_rev_stream_mask_gp)
     ,.out_fsm_stream_mask_p(mem_fwd_stream_mask_gp | mem_rev_stream_mask_gp)
     ,.metadata_fifo_width_p(mem_fwd_header_width_lp)
     ,.metadata_fifo_els_p(2)
     )
   stream_pump
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.in_msg_header_i(mem_fwd_header_i)
     ,.in_msg_data_i(mem_fwd_data_i)
     ,.in_msg_v_i(mem_fwd_v_i)
     ,.in_msg_ready_and_o(mem_fwd_ready_and_o)

     ,.in_fsm_header_o(fsm_fwd_header_li)
     ,.in_fsm_data_o(fsm_fwd_data_li)
     ,.in_fsm_v_o(fsm_fwd_v_li)
     ,.in_fsm_yumi_i(fsm_fwd_yumi_lo)

     ,.in_fsm_metadata_i(fsm_fwd_header_li)
     ,.in_fsm_addr_o(fsm_fwd_addr_li)
     ,.in_fsm_new_o(fsm_fwd_new_li)
     ,.in_fsm_critical_o(fsm_fwd_critical_li)
     ,.in_fsm_last_o(fsm_fwd_last_li)

     ,.out_msg_header_o(mem_rev_header_o)
     ,.out_msg_data_o(mem_rev_data_o)
     ,.out_msg_v_o(mem_rev_v_o)
     ,.out_msg_ready_and_i(mem_rev_ready_and_i)

     ,.out_fsm_header_i(fsm_rev_header_lo)
     ,.out_fsm_data_i(fsm_rev_data_lo)
     ,.out_fsm_v_i(fsm_rev_v_lo)
     ,.out_fsm_ready_then_o(fsm_rev_ready_then_li)

     ,.out_fsm_metadata_o(fsm_rev_header_lo)
     ,.out_fsm_addr_o(fsm_rev_addr_li)
     ,.out_fsm_new_o(fsm_rev_new_li)
     ,.out_fsm_critical_o(fsm_rev_critical_li)
     ,.out_fsm_last_o(fsm_rev_last_li)
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
      addr_li = fsm_fwd_addr_li;
      v_li = fsm_fwd_v_li;
      w_li = fsm_fwd_header_li.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_wr};
      fsm_fwd_yumi_lo = fsm_fwd_v_li & ready_and_lo;

      case (fsm_fwd_header_li.size)
        e_bedrock_msg_size_1: wmask_li = (axil_mask_width_lp)'('h1) << mask_shift;
        e_bedrock_msg_size_2: wmask_li = (axil_mask_width_lp)'('h3) << mask_shift;
        e_bedrock_msg_size_4: wmask_li = (axil_mask_width_lp)'('hF) << mask_shift;
        // e_bedrock_msg_size_8:
        default : wmask_li = (axil_mask_width_lp)'('hFF);
      endcase
    end

  localparam size_width_lp = `BSG_WIDTH(byte_offset_width_lp);

  wire [byte_offset_width_lp-1:0] resp_sel_li = fsm_rev_addr_li[0+:byte_offset_width_lp];
  wire [size_width_lp-1:0] resp_size_li = fsm_rev_header_lo.size;
  logic [axil_data_width_p-1:0] rdata_lo;
  bsg_bus_pack
   #(.in_width_p(axil_data_width_p), .out_width_p(axil_data_width_p))
   resp_data_bus_pack
    (.data_i(rdata_lo)
     ,.sel_i(resp_sel_li)
     ,.size_i(resp_size_li)
     ,.data_o(fsm_rev_data_lo)
     );

  logic v_lo, ready_and_li;
  always_comb
    begin
      ready_and_li = fsm_rev_ready_then_li;
      fsm_rev_v_lo = fsm_rev_ready_then_li & v_lo;
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
     ,.ready_and_i(ready_and_li)

     ,.*
     );


endmodule

