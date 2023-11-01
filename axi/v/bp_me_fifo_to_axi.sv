/*
 * Name:
 *   bp_me_fifo_to_axi.sv
 *
 * Description:
 *   This module converts a fifo interface to an AXI4 manager interface. The fifo is split into
 *   independent read and write channels. The fifo client must manage ordering if required. Every
 *   FIFO transaction returns a response, and response order is preserved from the FIFO input
 *   interface.
 *
 * Constraints and Assumptions:
 *   - data width must be 64-bits
 *   - address must be naturally aligned to request size (axsize)
 *   - size may be 8, 16, 32, or 64-bits
 *
 */

`include "bsg_defines.v"

module bp_me_fifo_to_axi
 import bsg_axi_pkg::*;
 #(parameter m_axi_data_width_p = 64
  , parameter m_axi_addr_width_p = 64
  , parameter m_axi_id_width_p = 1
  , parameter input_els_p = 2
  , parameter response_els_p = 8

  , localparam m_axi_mask_width_lp = m_axi_data_width_p>>3
  )
  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   //==================== FIFO Interface =======================
   , input [m_axi_data_width_p-1:0]             data_i
   , input [m_axi_addr_width_p-1:0]             addr_i
   , input                                      v_i
   , input                                      w_i
   , input [m_axi_mask_width_lp-1:0]            wmask_i
   , input [2:0]                                size_i
   , output logic                               ready_and_o

   , output logic [m_axi_data_width_p-1:0]      data_o
   , output logic                               v_o
   , output logic                               w_o
   , input                                      ready_and_i


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

  // FIFO buffer
  // buffers address, data, wmask, size
  logic input_ready_and_lo;
  logic [m_axi_addr_width_p-1:0] addr_li;
  logic [m_axi_data_width_p-1:0] data_li;
  logic [m_axi_mask_width_lp-1:0] wmask_li;
  logic [2:0] size_li;
  logic v_li, yumi_lo, w_li;

  // Response type buffer
  logic resp_type_ready_and_lo;
  logic resp_type_lo, resp_type_v_lo;

  // accept input when both input FIFO and response type FIFO are ready
  assign ready_and_o = input_ready_and_lo & resp_type_ready_and_lo;

  bsg_fifo_1r1w_small
    #(.width_p(m_axi_addr_width_p+m_axi_data_width_p+m_axi_mask_width_lp+3+1)
      ,.els_p(input_els_p)
      )
    input_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from FIFO interface
      ,.v_i(v_i & resp_type_ready_and_lo)
      ,.ready_o(input_ready_and_lo)
      ,.data_i({size_i, wmask_i, data_i, w_i, addr_i})
      // to AXI
      ,.v_o(v_li)
      ,.yumi_i(yumi_lo)
      ,.data_o({size_li, wmask_li, data_li, w_li, addr_li})
      );

  bsg_fifo_1r1w_small
    #(.width_p(1)
      ,.els_p(response_els_p)
      )
    resp_type_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from FIFO interface
      ,.v_i(v_i & input_ready_and_lo)
      ,.ready_o(resp_type_ready_and_lo)
      ,.data_i(w_i)
      // to response arbitration
      ,.v_o(resp_type_v_lo)
      ,.yumi_i(v_o & ready_and_i)
      ,.data_o(resp_type_lo)
      );

  // B channel
  wire b_unused = &{m_axi_bid_i};
  logic b_v_li, b_yumi_lo;
  logic [1:0] b_resp_li;
  bsg_fifo_1r1w_small
    #(.width_p(2)
      ,.els_p(response_els_p)
      )
    write_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from B
      ,.v_i(m_axi_bvalid_i)
      ,.ready_o(m_axi_bready_o)
      ,.data_i(m_axi_bresp_i)
      // to FIFO
      ,.v_o(b_v_li)
      ,.yumi_i(b_yumi_lo)
      ,.data_o(b_resp_li)
      );

  // R channel
  wire r_unused = &{m_axi_rid_i, m_axi_rlast_i, m_axi_rresp_i};
  logic r_v_li, r_yumi_lo;
  logic [m_axi_data_width_p-1:0] r_data_li;
  bsg_fifo_1r1w_small
    #(.width_p(m_axi_data_width_p)
      ,.els_p(response_els_p)
      )
    read_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from R
      ,.v_i(m_axi_rvalid_i)
      ,.ready_o(m_axi_rready_o)
      ,.data_i(m_axi_rdata_i)
      // to FIFO
      ,.v_o(r_v_li)
      ,.yumi_i(r_yumi_lo)
      ,.data_o(r_data_li)
      );

  // FIFO response arbitration
  assign v_o = resp_type_v_lo & ((resp_type_lo & b_v_li) | (~resp_type_lo & r_v_li));
  assign w_o = resp_type_v_lo & resp_type_lo;
  assign b_yumi_lo = resp_type_v_lo & resp_type_lo & b_v_li & ready_and_i;
  assign r_yumi_lo = resp_type_v_lo & ~resp_type_lo & r_v_li & ready_and_i;
  assign data_o = resp_type_lo ? '0 : r_data_li;

  logic addr_sent, addr_clear, addr_set;
  logic data_sent, data_clear, data_set;
  bsg_dff_reset_set_clear
    #(.width_p(2)
      ,.clear_over_set_p(1))
    sent_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i({data_set, addr_set})
      ,.clear_i({data_clear, addr_clear})
      ,.data_o({data_sent, addr_sent})
      );

  // consume fifo when address and data (for writes) sent
  assign yumi_lo = v_li & addr_sent & (~w_li | (w_li & data_sent));
  assign addr_clear = yumi_lo;
  assign addr_set = v_li & ((m_axi_awvalid_o & m_axi_awready_i) | (m_axi_arvalid_o & m_axi_arready_i));
  assign data_clear = yumi_lo;
  assign data_set = v_li & m_axi_wvalid_o & m_axi_wready_i;

  localparam lg_m_axi_mask_width_lp = `BSG_SAFE_CLOG2(m_axi_mask_width_lp);
  wire [lg_m_axi_mask_width_lp-1:0] mask_shift = addr_li[0+:lg_m_axi_mask_width_lp];

  always_comb begin

    m_axi_awaddr_o = addr_li;
    m_axi_awvalid_o = v_li & w_li & ~addr_sent;
    m_axi_awid_o = '0;
    m_axi_awlock_o = '0;
    m_axi_awcache_o = '0;
    m_axi_awprot_o = '0;
    m_axi_awlen_o = '0; // single data transfer
    m_axi_awsize_o = size_li;
    m_axi_awburst_o = 2'b01; // INCR
    m_axi_awqos_o = '0;
    m_axi_awregion_o = '0;

    m_axi_wdata_o = data_li;
    m_axi_wvalid_o = v_li & w_li & ~data_sent;
    m_axi_wlast_o = 1'b1;
    m_axi_wstrb_o = '0; // set by case statement below
    // construct the write strobe
    case (size_li)
      // 1 byte
      3'b000: m_axi_wstrb_o = (m_axi_mask_width_lp)'('h1) << mask_shift;
      // 2 bytes
      3'b001: m_axi_wstrb_o = (m_axi_mask_width_lp)'('h3) << mask_shift;
      // 4 bytes
      3'b010: m_axi_wstrb_o = (m_axi_mask_width_lp)'('hF) << mask_shift;
      // 8 bytes
      // 3'b011
      default : m_axi_wstrb_o = (m_axi_mask_width_lp)'('hFF);
    endcase

    m_axi_araddr_o = addr_li;
    m_axi_arvalid_o = v_li & ~w_li & ~addr_sent;
    m_axi_arid_o = '0;
    m_axi_arlock_o = '0;
    m_axi_arcache_o = '0;
    m_axi_arprot_o = '0;
    m_axi_arlen_o = '0; // single data transfer
    m_axi_arsize_o = size_li;
    m_axi_arburst_o = 2'b01; // INCR
    m_axi_arqos_o = '0;
    m_axi_arregion_o = '0;

  end

endmodule

