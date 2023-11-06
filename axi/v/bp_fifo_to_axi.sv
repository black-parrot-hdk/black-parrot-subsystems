/*
 * Name:
 *   bp_fifo_to_axi.sv
 *
 * Description:
 *   This module converts a fifo interface to an AXI4 manager interface. The fifo interface is
 *   split into independently operating AXI read and write channels. The fifo response interface
 *   returns responses in-order relative to the fifo request interface. This module re-orders
 *   the AXI read and write responses to preserve the fifo request interface ordering. Every
 *   fifo request receives a response. Write responses return null data (all zeros) and read
 *   responses contain valid data for only the requested bits, as determined by address and size.
 *
 *   One AXI read or write request is issued per fifo request. AXI requests have the following
 *   properties:
 *   - AWID, ARID = 0
 *   - AxBurst = Incr
 *   - AxCache = 0
 *   - AxSize is any valid AXI size up to the data channel width
 *   - AxLen = 0 (single transfer transactions only)
 *
 * Additonal Constraints and Assumptions:
 *   - data width must be a valid AXI data width and at least 64-bits
 *   - address width should be at least 32-bits, and preferrably a full 64-bits
 *   - address must be naturally aligned to request size (axsize)
 *
 */

// TODO: should fifo wmask_i be generated internally based on address and size?

`include "bsg_defines.v"

module bp_fifo_to_axi
 import bsg_axi_pkg::*;
 #(// AXI parameters
    parameter m_axi_data_width_p = 64
  , parameter m_axi_addr_width_p = 64
  , parameter m_axi_id_width_p = 1
  , localparam m_axi_mask_width_lp = m_axi_data_width_p>>3
  // Buffer sizes
  , parameter rd_req_els_p = 2
  , parameter wr_req_els_p = rd_req_els_p
  , parameter rd_resp_els_p = rd_req_els_p
  , parameter wr_resp_els_p = wr_req_els_p
  , parameter reorder_els_p = (rd_req_els_p + wr_req_els_p)
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
   , input                                      yumi_i


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

  // unused AXI interface signals
  wire b_unused = &{m_axi_bid_i};
  wire r_unused = &{m_axi_rid_i, m_axi_rlast_i, m_axi_rresp_i};

  // Request Splitting

  // fifo input valid/ready management
  logic rd_req_ready_and, wr_req_ready_and, reorder_ready_and;
  wire rd_req_v = v_i & ~w_i & reorder_ready_and & wr_req_ready_and;
  wire wr_req_v = v_i & w_i & reorder_ready_and & rd_req_ready_and;
  wire reorder_v = v_i & wr_req_ready_and & rd_req_ready_and;
  assign ready_and_o = reorder_ready_and & rd_req_ready_and & wr_req_ready_and;

  // read request fifo outputs
  logic [m_axi_addr_width_p-1:0] rd_addr_lo;
  logic [2:0] rd_size_lo;
  logic rd_v_lo, rd_yumi_li;

  // write request fifo outputs
  logic [m_axi_addr_width_p-1:0] wr_addr_lo;
  logic [m_axi_data_width_p-1:0] wr_data_lo;
  logic [m_axi_mask_width_lp-1:0] wr_wmask_lo;
  logic [2:0] wr_size_lo;
  logic wr_v_lo, wr_yumi_li;

  // reorder fifo outputs
  logic reorder_v_lo, reorder_w_lo, reorder_yumi_li;

  // reorder fifo
  bsg_fifo_1r1w_small
    #(.width_p(1)
      ,.els_p(reorder_els_p)
      )
    reorder_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from FIFO interface
      ,.v_i(reorder_v)
      ,.ready_o(reorder_ready_and)
      ,.data_i(w_i)
      // to response arbitration
      ,.v_o(reorder_v_lo)
      ,.yumi_i(reorder_yumi_li)
      ,.data_o(reorder_w_lo)
      );

  // read request fifo
  bsg_fifo_1r1w_small
    #(.width_p(m_axi_addr_width_p+3)
      ,.els_p(rd_req_els_p)
      )
    rd_req_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from FIFO interface
      ,.v_i(rd_req_v)
      ,.ready_o(rd_req_ready_and)
      ,.data_i({size_i, addr_i})
      // to AXI
      ,.v_o(rd_v_lo)
      ,.yumi_i(rd_yumi_li)
      ,.data_o({rd_size_lo, rd_addr_lo})
      );

  // write request fifo
  bsg_fifo_1r1w_small
    #(.width_p(m_axi_addr_width_p+m_axi_data_width_p+m_axi_mask_width_lp+3)
      ,.els_p(wr_req_els_p)
      )
    wr_req_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from FIFO interface
      ,.v_i(wr_req_v)
      ,.ready_o(wr_req_ready_and)
      ,.data_i({size_i, wmask_i, data_i, addr_i})
      // to AXI
      ,.v_o(wr_v_lo)
      ,.yumi_i(wr_yumi_li)
      ,.data_o({wr_size_lo, wr_wmask_lo, wr_data_lo, wr_addr_lo})
      );

  // AXI AW/W control
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

  always_comb begin
    m_axi_awaddr_o = wr_addr_lo;
    m_axi_awvalid_o = wr_v_lo & ~addr_sent;
    m_axi_awid_o = '0;
    m_axi_awlock_o = '0;
    m_axi_awcache_o = '0;
    m_axi_awprot_o = '0;
    m_axi_awlen_o = '0; // single data transfer
    m_axi_awsize_o = wr_size_lo;
    m_axi_awburst_o = 2'b01; // INCR
    m_axi_awqos_o = '0;
    m_axi_awregion_o = '0;

    m_axi_wdata_o = wr_data_lo;
    m_axi_wvalid_o = wr_v_lo & ~data_sent;
    m_axi_wlast_o = 1'b1; // single data transfer
    m_axi_wstrb_o = wr_wmask_lo;

    addr_set = wr_v_lo & m_axi_awvalid_o & m_axi_awready_i;
    data_set = wr_v_lo & m_axi_wvalid_o & m_axi_wready_i;

    wr_yumi_li = wr_v_lo & (addr_sent | addr_set) & (data_sent | data_set);
    addr_clear = wr_yumi_li;
    data_clear = wr_yumi_li;
  end

  // AXI AR control
  always_comb begin
    // AR request
    m_axi_araddr_o = rd_addr_lo;
    m_axi_arvalid_o = rd_v_lo;
    m_axi_arid_o = '0;
    m_axi_arlock_o = '0;
    m_axi_arcache_o = '0;
    m_axi_arprot_o = '0;
    m_axi_arlen_o = '0; // single data transfer
    m_axi_arsize_o = rd_size_lo;
    m_axi_arburst_o = 2'b01; // INCR
    m_axi_arqos_o = '0;
    m_axi_arregion_o = '0;
    // request fifo yumi when AR request sends
    rd_yumi_li = m_axi_arvalid_o & m_axi_arready_i;
  end

  // Response re-ordering

  // B channel
  // write response fifo
  logic b_v_lo, b_yumi_li;
  bsg_fifo_1r1w_small
    #(.width_p(2)
      ,.els_p(wr_resp_els_p)
      )
    write_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from B
      ,.v_i(m_axi_bvalid_i)
      ,.ready_o(m_axi_bready_o)
      ,.data_i(m_axi_bresp_i)
      // to FIFO
      ,.v_o(b_v_lo)
      ,.yumi_i(b_yumi_li)
      ,.data_o() // B response unused
      );

  // R channel
  // read response fifo
  logic r_v_lo, r_yumi_li;
  logic [m_axi_data_width_p-1:0] r_data_lo;
  bsg_fifo_1r1w_small
    #(.width_p(m_axi_data_width_p)
      ,.els_p(rd_resp_els_p)
      )
    read_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from R
      ,.v_i(m_axi_rvalid_i)
      ,.ready_o(m_axi_rready_o)
      ,.data_i(m_axi_rdata_i)
      // to FIFO
      ,.v_o(r_v_lo)
      ,.yumi_i(r_yumi_li)
      ,.data_o(r_data_lo)
      );

  // fifo output and read/write response arbitration
  assign v_o = reorder_v_lo & ((reorder_w_lo & b_v_lo) | (~reorder_w_lo & r_v_lo));
  assign w_o = reorder_w_lo;
  assign data_o = reorder_w_lo ? '0 : r_data_lo;
  assign b_yumi_li = yumi_i & reorder_w_lo;
  assign r_yumi_li = yumi_i & ~reorder_w_lo;
  assign reorder_yumi_li = yumi_i;

endmodule

