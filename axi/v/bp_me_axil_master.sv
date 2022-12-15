
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

  , parameter io_data_width_p = (cce_type_p == e_cce_uce) ? uce_fill_width_p : bedrock_data_width_p
  // AXI WRITE DATA CHANNEL PARAMS
  , parameter axil_data_width_p = 32
  , parameter axil_addr_width_p  = 32
  , localparam axi_mask_width_lp = (axil_data_width_p>>3)
  , parameter num_outstanding_p = 8
  , localparam num_reqs_lp = `BSG_MAX((io_data_width_p/axil_data_width_p),1)
  , localparam lg_num_reqs_lp = `BSG_SAFE_CLOG2(num_reqs_lp)
  )
 (//==================== GLOBAL SIGNALS =======================
  input                                        clk_i
  , input                                      reset_i

  //==================== BP-STREAM SIGNALS ======================
  , input [mem_header_width_lp-1:0]            io_cmd_header_i
  , input [io_data_width_p-1:0]                io_cmd_data_i
  , input                                      io_cmd_v_i
  , output logic                               io_cmd_ready_and_o
  , input                                      io_cmd_last_i

  , output logic [mem_header_width_lp-1:0]     io_resp_header_o
  , output logic [io_data_width_p-1:0]         io_resp_data_o
  , output logic                               io_resp_v_o
  , input                                      io_resp_ready_and_i
  , output logic                               io_resp_last_o

  //====================== AXI-4 LITE =========================
  // WRITE ADDRESS CHANNEL SIGNALS
  , output logic [axil_addr_width_p-1:0]       m_axil_awaddr_o
  , output logic [2:0]                         m_axil_awprot_o
  , output logic                               m_axil_awvalid_o
  , input                                      m_axil_awready_i

  // WRITE DATA CHANNEL SIGNALS
  , output logic [axil_data_width_p-1:0]       m_axil_wdata_o
  , output logic [(axil_data_width_p>>3)-1:0]  m_axil_wstrb_o
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

  wire unused = &{io_cmd_last_i};
  assign io_resp_last_o = io_resp_v_o;

  // declaring i/o command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_o(bp_bedrock_mem_header_s, io_resp_header);

  logic header_v_li, header_ready_lo;
  logic header_v_lo, header_yumi_li;
  logic [io_data_width_p-1:0] io_cmd_data_lo;
  bsg_fifo_1r1w_small
   #(.width_p($bits(bp_bedrock_mem_header_s)+io_data_width_p), .els_p(num_outstanding_p))
   return_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({io_cmd_header_cast_i, io_cmd_data_i})
     ,.v_i(header_v_li)
     ,.ready_o(header_ready_lo)

     ,.data_o({io_resp_header_cast_o, io_cmd_data_lo})
     ,.v_o(header_v_lo)
     ,.yumi_i(header_yumi_li)
     );

  logic req_up_li, resp_up_li, clear_li;
  logic [lg_num_reqs_lp:0] req_cnt_r, resp_cnt_r, counter_max;

  logic [num_reqs_lp-1:0][axil_data_width_p-1:0] rdata_r;
  logic [io_data_width_p-1:0] full_data;

  logic [axil_data_width_p-1:0] wdata_li;
  logic [axil_addr_width_p-1:0] addr_li, addr_r;
  logic v_li, w_li, ready_and_lo;
  logic [axi_mask_width_lp-1:0] wmask_li;

  for (genvar i=0; i<num_reqs_lp; i++) begin
      assign full_data[i*axil_data_width_p+:axil_data_width_p] = (i < resp_cnt_r)
                                                                 ? rdata_r[i]
                                                                 : ((i == resp_cnt_r)
                                                                   ? rdata_lo : '0);
  end

  //assign full_data  = {rdata_lo[axil_data_width_p-1:0], rdata_r[num_reqs_lp-2:0][axil_data_width_p-1:0]};

  always_ff @(posedge clk_i) begin
    if(reset_i | clear_li) begin
      rdata_r <= '0;
    end
    else if(resp_up_li) begin
      rdata_r[resp_cnt_r[0+:lg_num_reqs_lp]] <= rdata_lo;
    end
  end

  assign counter_max = (io_resp_header_cast_o.size < `BSG_SAFE_CLOG2(axil_data_width_p>>3))
                       ? '0
                       : ((lg_num_reqs_lp+1)'(1) << (io_resp_header_cast_o.size - `BSG_SAFE_CLOG2(axil_data_width_p>>3))) - (lg_num_reqs_lp+1)'(1);

  assign clear_li = header_yumi_li;
  assign req_up_li = v_li & ready_and_lo;
  assign resp_up_li = v_lo & ready_and_li & ~header_yumi_li;

  bsg_counter_clear_up
   #(.max_val_p(2**(lg_num_reqs_lp+1)), .init_val_p(0))
   req_counter
   (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.clear_i(clear_li)
   ,.up_i(req_up_li)
   ,.count_o(req_cnt_r)
   );

  bsg_counter_clear_up
   #(.max_val_p(2**(lg_num_reqs_lp+1)), .init_val_p(0))
   resp_counter
   (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.clear_i(clear_li)
   ,.up_i(resp_up_li)
   ,.count_o(resp_cnt_r)
   );

  always_comb
    begin
      wdata_li = io_cmd_data_lo;
      addr_li = io_resp_header_cast_o.addr + {'0, req_cnt_r[0+:lg_num_reqs_lp], {byte_offset_width_lp{1'b0}}};
      v_li = header_v_lo & (req_cnt_r <= counter_max);
      w_li = io_resp_header_cast_o.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr};
      io_cmd_ready_and_o = header_ready_lo;

      header_v_li = io_cmd_ready_and_o & io_cmd_v_i;

      case (io_resp_header_cast_o.size)
        e_bedrock_msg_size_1: wmask_li = (axil_data_width_p>>3)'('h1);
        e_bedrock_msg_size_2: wmask_li = (axil_data_width_p>>3)'('h3);
        e_bedrock_msg_size_4: wmask_li = (axil_data_width_p>>3)'('hF);
        // e_bedrock_msg_size_8:
        default : wmask_li = (axil_data_width_p>>3)'('hFF);
      endcase
    end

  localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(axil_data_width_p>>3);
  localparam size_width_lp = `BSG_WIDTH(byte_offset_width_lp);

  wire [byte_offset_width_lp-1:0] resp_sel_li = io_resp_header_cast_o.addr[0+:byte_offset_width_lp];
  wire [size_width_lp-1:0] resp_size_li = io_resp_header_cast_o.size;
  logic [axil_data_width_p-1:0] rdata_lo;
  bsg_bus_pack
   #(.in_width_p(io_data_width_p), .out_width_p(io_data_width_p))
   resp_data_bus_pack
    (.data_i(full_data)
     ,.sel_i('0)
     ,.size_i(resp_size_li)
     ,.data_o(io_resp_data_o)
     );

  logic v_lo, ready_and_li;
  always_comb
    begin
      io_resp_v_o = v_lo & (resp_cnt_r == counter_max);
      ready_and_li = io_resp_ready_and_i;

      header_yumi_li = header_v_lo & io_resp_v_o & io_resp_ready_and_i;
    end

  bsg_axil_fifo_master
   #(.axil_data_width_p(axil_data_width_p)
     ,.axil_addr_width_p(axil_addr_width_p)
     ,.fifo_els_p(num_outstanding_p*num_reqs_lp)
     )
   fifo_master
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

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

