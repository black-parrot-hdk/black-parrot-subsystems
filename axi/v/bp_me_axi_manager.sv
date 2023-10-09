/*
 * Name:
 *   bp_me_axi_manager.sv
 *
 * Description:
 *   This module converts BedRock Stream requests to AXI4 requests. It supports one outstanding
 *   AXI transaction at a time to preserve ordering, since AXI read and write channels have no
 *   inter-channel ordering guarantees and there is no ordering for transactions to different
 *   peripheral or memory regions.
 *
 *   bedrock_fill_width and axi_data_width must be 64b. The bedrock transaction must have size
 *   less than or equal to axi_data_width (i.e., single beat).
 *
 *   This is a very low performance implementation that buffers the input transaction in the first
 *   cycle, issues the read or write, then waits for the response before processing the next
 *   transaction.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_axi_manager
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

  , parameter m_axi_data_width_p = 64
  , parameter m_axi_addr_width_p = 64
  , parameter m_axi_id_width_p = 1
  , localparam m_axi_mask_width_lp = (m_axi_data_width_p>>3)
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

  //====================== AXI-4 =========================
  , output logic [m_axi_addr_width_p-1:0]      m_axi_awaddr_o
  , output logic                               m_axi_awvalid_o
  , input                                      m_axi_awready_i
  , output logic [m_axi_id_width_p-1:0]        m_axi_awid_o
  , output logic                               m_axi_awlock_o
  , output logic [3:0]                         m_axi_awcache_o
  , output logic [2:0]                         m_axi_awprot_o
  , output logic [7:0]                         m_axi_awlen_o
  , output logic [2:0]                         m_axi_awsize_o
  , output logic [1:0]                         m_axi_awburst_o
  , output logic [3:0]                         m_axi_awqos_o
  , output logic [3:0]                         m_axi_awregion_o

  , output logic [m_axi_data_width_p-1:0]      m_axi_wdata_o
  , output logic                               m_axi_wvalid_o
  , input                                      m_axi_wready_i
  , output logic                               m_axi_wlast_o
  , output logic [m_axi_mask_width_lp-1:0]     m_axi_wstrb_o

  , input                                      m_axi_bvalid_i
  , output logic                               m_axi_bready_o
  , input [m_axi_id_width_p-1:0]               m_axi_bid_i
  , input [1:0]                                m_axi_bresp_i

  , output logic [m_axi_addr_width_p-1:0]      m_axi_araddr_o
  , output logic                               m_axi_arvalid_o
  , input                                      m_axi_arready_i
  , output logic [m_axi_id_width_p-1:0]        m_axi_arid_o
  , output logic                               m_axi_arlock_o
  , output logic [3:0]                         m_axi_arcache_o
  , output logic [2:0]                         m_axi_arprot_o
  , output logic [7:0]                         m_axi_arlen_o
  , output logic [2:0]                         m_axi_arsize_o
  , output logic [1:0]                         m_axi_arburst_o
  , output logic [3:0]                         m_axi_arqos_o
  , output logic [3:0]                         m_axi_arregion_o

  , input [m_axi_data_width_p-1:0]             m_axi_rdata_i
  , input                                      m_axi_rvalid_i
  , output logic                               m_axi_rready_o
  , input [m_axi_id_width_p-1:0]               m_axi_rid_i
  , input                                      m_axi_rlast_i
  , input [1:0]                                m_axi_rresp_i
  );

  wire unused = &{m_axi_bid_i, m_axi_bresp_i, m_axi_rid_i, m_axi_rlast_i, m_axi_rresp_i};

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);

  bp_bedrock_mem_fwd_header_s mem_fwd_fifo_header_li;
  logic [m_axi_data_width_p-1:0] mem_fwd_fifo_data_li;
  logic mem_fwd_fifo_v_li, mem_fwd_fifo_ready_and_lo;

  bp_me_stream_gearbox
    #(.bp_params_p(bp_params_p)
      ,.buffered_p(1)
      ,.in_data_width_p(bedrock_fill_width_p)
      ,.out_data_width_p(m_axi_data_width_p)
      ,.payload_width_p(mem_fwd_payload_width_lp)
      ,.stream_mask_p(mem_fwd_stream_mask_gp)
      )
    mem_fwd_gearbox
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.msg_header_i(mem_fwd_header_cast_i)
      ,.msg_data_i(mem_fwd_data_i)
      ,.msg_v_i(mem_fwd_v_i)
      ,.msg_ready_and_o(mem_fwd_ready_and_o)
      ,.msg_header_o(mem_fwd_fifo_header_li)
      ,.msg_data_o(mem_fwd_fifo_data_li)
      ,.msg_v_o(mem_fwd_fifo_v_li)
      ,.msg_ready_param_i(mem_fwd_fifo_ready_and_lo)
      );

  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [m_axi_data_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_v_li, mem_fwd_yumi_lo;

  bsg_two_fifo
    #(.width_p(mem_fwd_header_width_lp+m_axi_data_width_p))
    mem_fwd_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(mem_fwd_fifo_v_li)
      ,.ready_o(mem_fwd_fifo_ready_and_lo)
      ,.data_i({mem_fwd_fifo_data_li, mem_fwd_fifo_header_li})
      ,.v_o(mem_fwd_v_li)
      ,.yumi_i(mem_fwd_yumi_lo)
      ,.data_o({mem_fwd_data_li, mem_fwd_header_li})
      );

  wire mem_fwd_write = (mem_fwd_header_li.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr});

  logic mem_rev_v_lo, mem_rev_ready_and_li;

  logic mem_rev_fifo_v_lo, mem_rev_fifo_ready_and_li;
  logic [m_axi_data_width_p-1:0] mem_rev_fifo_data_lo;
  bp_bedrock_mem_rev_header_s mem_rev_fifo_header_lo;

  bsg_one_fifo
    #(.width_p(mem_rev_header_width_lp+m_axi_data_width_p))
    mem_rev_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(mem_rev_v_lo)
      ,.ready_o(mem_rev_ready_and_li)
      ,.data_i({m_axi_rdata_i, mem_fwd_header_li})
      ,.v_o(mem_rev_fifo_v_lo)
      ,.yumi_i(mem_rev_fifo_v_lo & mem_rev_fifo_ready_and_li)
      ,.data_o({mem_rev_fifo_data_lo, mem_rev_fifo_header_lo})
      );

  bp_me_stream_gearbox
    #(.bp_params_p(bp_params_p)
      ,.buffered_p(1)
      ,.in_data_width_p(m_axi_data_width_p)
      ,.out_data_width_p(bedrock_fill_width_p)
      ,.payload_width_p(mem_rev_payload_width_lp)
      ,.stream_mask_p(mem_rev_stream_mask_gp)
      )
    mem_rev_gearbox
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.msg_header_i(mem_rev_fifo_header_lo)
      ,.msg_data_i(mem_rev_fifo_data_lo)
      ,.msg_v_i(mem_rev_fifo_v_lo)
      ,.msg_ready_and_o(mem_rev_fifo_ready_and_li)
      ,.msg_header_o(mem_rev_header_cast_o)
      ,.msg_data_o(mem_rev_data_o)
      ,.msg_v_o(mem_rev_v_o)
      ,.msg_ready_param_i(mem_rev_ready_and_i)
      );

  assign mem_fwd_yumi_lo = mem_rev_v_lo & mem_rev_ready_and_li;

  typedef enum logic [2:0] {
    e_ready
    ,e_write
    ,e_wresp
    ,e_read
    ,e_rdata
  } state_e;
  state_e state_r, state_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
    end else begin
      state_r <= state_n;
    end
  end

  logic waddr_sent, waddr_clear, waddr_set;
  logic wdata_sent, wdata_clear, wdata_set;
  bsg_dff_reset_set_clear
    #(.width_p(2)
      ,.clear_over_set_p(1)
      )
    sent_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i({wdata_set, waddr_set})
      ,.clear_i({wdata_clear, waddr_clear})
      ,.data_o({wdata_sent, waddr_sent})
      );

  localparam lg_m_axi_mask_width_lp = `BSG_SAFE_CLOG2(m_axi_mask_width_lp);
  wire [lg_m_axi_mask_width_lp-1:0] mask_shift = mem_fwd_header_li.addr[0+:lg_m_axi_mask_width_lp];

  always_comb begin
    state_n = state_r;

    mem_rev_v_lo = 1'b0;

    wdata_set = 1'b0;
    wdata_clear = 1'b0;
    waddr_set = 1'b0;
    waddr_clear = 1'b0;

    m_axi_awaddr_o = mem_fwd_header_li.addr;
    m_axi_awvalid_o = 1'b0;
    m_axi_awid_o = '0;
    m_axi_awlock_o = '0;
    m_axi_awcache_o = '0;
    m_axi_awprot_o = '0;
    m_axi_awlen_o = '0; // single data transfer
    m_axi_awsize_o = mem_fwd_header_li.size;
    m_axi_awburst_o = 2'b01; // INCR
    m_axi_awqos_o = '0;
    m_axi_awregion_o = '0;

    m_axi_wdata_o = mem_fwd_data_li;
    m_axi_wvalid_o = 1'b0;
    m_axi_wlast_o = 1'b1;
    m_axi_wstrb_o = '0; // set by case statement below

    m_axi_bready_o = 1'b0;

    m_axi_araddr_o = mem_fwd_header_li.addr;
    m_axi_arvalid_o = 1'b0;
    m_axi_arid_o = '0;
    m_axi_arlock_o = '0;
    m_axi_arcache_o = '0;
    m_axi_arprot_o = '0;
    m_axi_arlen_o = '0; // single data transfer
    m_axi_arsize_o = mem_fwd_header_li.size;
    m_axi_arburst_o = 2'b01; // INCR
    m_axi_arqos_o = '0;
    m_axi_arregion_o = '0;

    m_axi_rready_o = 1'b0;

    // construct the write strobe
    case (mem_fwd_header_li.size)
      e_bedrock_msg_size_1: m_axi_wstrb_o = (m_axi_mask_width_lp)'('h1) << mask_shift;
      e_bedrock_msg_size_2: m_axi_wstrb_o = (m_axi_mask_width_lp)'('h3) << mask_shift;
      e_bedrock_msg_size_4: m_axi_wstrb_o = (m_axi_mask_width_lp)'('hF) << mask_shift;
      // e_bedrock_msg_size_8:
      default : m_axi_wstrb_o = (m_axi_mask_width_lp)'('hFF);
    endcase

    case (state_r)
      // capture mem_fwd and data
      e_ready: begin
        waddr_clear = 1'b1;
        wdata_clear = 1'b1;
        state_n = mem_fwd_v_li
                  ? mem_fwd_write
                    ? e_write
                    : e_read
                  : state_r;
      end
      // send write data and address
      e_write: begin
        m_axi_awvalid_o = ~waddr_sent;
        waddr_set = m_axi_awvalid_o & m_axi_awready_i;
        m_axi_wvalid_o = ~wdata_sent;
        wdata_set = m_axi_wvalid_o & m_axi_wready_i;
        state_n = (waddr_set & wdata_set) | (waddr_set & wdata_sent) | (waddr_sent & wdata_set)
                  ? e_wresp
                  : state_r;
      end
      // sink write response and send mem_rev
      e_wresp: begin
        m_axi_bready_o = mem_rev_ready_and_li;
        mem_rev_v_lo = m_axi_bvalid_i;
        state_n = (m_axi_bvalid_i & m_axi_bready_o)
                  ? e_ready
                  : state_r;
      end
      // sned read request
      e_read: begin
        m_axi_arvalid_o = 1'b1;
        state_n = (m_axi_arvalid_o & m_axi_arready_i)
                  ? e_rdata
                  : state_r;
      end
      // sink read data and send mem_rev
      e_rdata: begin
        m_axi_rready_o = mem_rev_ready_and_li;
        mem_rev_v_lo = m_axi_rvalid_i;
        state_n = (m_axi_rvalid_i & m_axi_rready_o)
                  ? e_ready
                  : state_r;
      end
      default: begin
      end
    endcase
  end

endmodule

