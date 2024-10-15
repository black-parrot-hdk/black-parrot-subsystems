
`include "bsg_defines.sv"

module bsg_axil_dma
 import bsg_axi_pkg::*;
 #(parameter m_axil_data_width_p = 32
   , parameter m_axil_addr_width_p = 32
   , localparam m_axil_strb_width_lp = m_axil_data_width_p >> 3

   , parameter s_axil_data_width_p = 32
   , parameter s_axil_addr_width_p = 32
   , localparam s_axil_strb_width_lp = s_axil_data_width_p >> 3

   , parameter lg_max_length_p = 16
   , parameter lg_max_stride_p = 8
   
   , parameter max_outstanding_rd_p = 16
   , parameter max_outstanding_wr_p = 16
   )
  (input                                        clk_i
   , input                                      reset_i

   //====================== AXI-4 LITE (Master) =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , output logic [m_axil_addr_width_p-1:0]     m_axil_awaddr_o
   , output logic [2:0]                         m_axil_awprot_o
   , output logic                               m_axil_awvalid_o
   , input                                      m_axil_awready_i

   // WRITE DATA CHANNEL SIGNALS
   , output logic [m_axil_data_width_p-1:0]     m_axil_wdata_o
   , output logic [m_axil_strb_width_lp-1:0]    m_axil_wstrb_o
   , output logic                               m_axil_wvalid_o
   , input                                      m_axil_wready_i

   // WRITE RESPONSE CHANNEL SIGNALS
   , input [1:0]                                m_axil_bresp_i
   , input                                      m_axil_bvalid_i
   , output logic                               m_axil_bready_o

   // READ ADDRESS CHANNEL SIGNALS
   , output logic [m_axil_addr_width_p-1:0]     m_axil_araddr_o
   , output logic [2:0]                         m_axil_arprot_o
   , output logic                               m_axil_arvalid_o
   , input                                      m_axil_arready_i

   // READ DATA CHANNEL SIGNALS
   , input [m_axil_data_width_p-1:0]            m_axil_rdata_i
   , input [1:0]                                m_axil_rresp_i
   , input                                      m_axil_rvalid_i
   , output logic                               m_axil_rready_o

   //====================== AXI-4 LITE (Slave) =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [s_axil_addr_width_p-1:0]            s_axil_awaddr_i
   , input [2:0]                                s_axil_awprot_i
   , input                                      s_axil_awvalid_i
   , output logic                               s_axil_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [s_axil_data_width_p-1:0]            s_axil_wdata_i
   , input [s_axil_strb_width_lp-1:0]           s_axil_wstrb_i
   , input                                      s_axil_wvalid_i
   , output logic                               s_axil_wready_o

   // WRITE RESPONSE CHANNEL SIGNALS
   , output logic [1:0]                         s_axil_bresp_o
   , output logic                               s_axil_bvalid_o
   , input                                      s_axil_bready_i

   // READ ADDRESS CHANNEL SIGNALS
   , input [s_axil_addr_width_p-1:0]            s_axil_araddr_i
   , input [2:0]                                s_axil_arprot_i
   , input                                      s_axil_arvalid_i
   , output logic                               s_axil_arready_o

   // READ DATA CHANNEL SIGNALS
   , output logic [s_axil_data_width_p-1:0]     s_axil_rdata_o
   , output logic [1:0]                         s_axil_rresp_o
   , output logic                               s_axil_rvalid_o
   , input                                      s_axil_rready_i

   , output logic                               interrupt_o
   );

  logic axil_v_lo, axil_w_lo, axil_yumi_li;
  logic [s_axil_addr_width_p-1:0] axil_addr_lo;
  logic [s_axil_data_width_p-1:0] axil_data_lo;
  logic [s_axil_strb_width_lp-1:0]  axil_wmask_lo;

  logic axil_v_li, axil_ready_and_lo;
  logic [s_axil_data_width_p-1:0] axil_data_li;

  bsg_axil_fifo_client
   #(.axil_data_width_p(s_axil_data_width_p), .axil_addr_width_p(s_axil_addr_width_p))
   client
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_o(axil_data_lo)
     ,.addr_o(axil_addr_lo)
     ,.v_o(axil_v_lo)
     ,.w_o(axil_w_lo)
     ,.wmask_o(axil_wmask_lo)
     ,.ready_and_i(axil_yumi_li)

     ,.data_i(axil_data_li)
     ,.v_i(axil_v_li)
     ,.ready_and_o(axil_ready_and_lo)

     ,.*
     );

  logic [s_axil_addr_width_p-1:0] p_addr_li;
  logic [s_axil_data_width_p-1:0] p_data_li;
  logic p_w_li, p_v_li, p_yumi_lo;
  logic [s_axil_data_width_p-1:0] p_data_lo;
  logic p_v_lo;

  logic [m_axil_addr_width_p-1:0] c_rd_addr_lo;
  logic c_rd_v_lo, c_rd_yumi_li;

  logic [m_axil_addr_width_p-1:0] c_rd_addr_li;
  logic [m_axil_data_width_p-1:0] c_rd_data_li;
  logic c_rd_v_li;

  logic [m_axil_addr_width_p-1:0] c_wr_addr_lo;
  logic [m_axil_data_width_p-1:0] c_wr_data_lo;
  logic [m_axil_strb_width_lp-1:0] c_wr_mask_lo;
  logic c_wr_v_lo, c_wr_yumi_li, c_wr_ack_li;
  bsg_mla_dma_controller
   #(.p_addr_width_p(s_axil_addr_width_p)
     ,.p_data_width_p(s_axil_data_width_p)

     ,.c_addr_width_p(m_axil_addr_width_p)
     ,.c_data_width_p(m_axil_data_width_p)
     ,.c_mask_width_p(m_axil_strb_width_lp)

     ,.csr_length_width_p(lg_max_length_p)
     ,.csr_stride_width_p(lg_max_stride_p)

     ,.out_of_order_p(0)
     ,.st_fwd_fifo_els_p(max_outstanding_rd_p)
     ,.max_outstanding_wr_p(max_outstanding_wr_p)
     )
   controller
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.p_addr_i(p_addr_li)
     ,.p_data_i(p_data_li)
     ,.p_w_i(p_w_li)
     ,.p_v_i(p_v_li)
     ,.p_yumi_o(p_yumi_lo)

     ,.p_data_o(p_data_lo)
     ,.p_v_o(p_v_lo)

     ,.c_rd_addr_o(c_rd_addr_lo)
     ,.c_rd_v_o(c_rd_v_lo)
     ,.c_rd_yumi_i(c_rd_yumi_li)

     ,.c_rd_addr_i(c_rd_addr_li)
     ,.c_rd_data_i(c_rd_data_li)
     ,.c_rd_v_i(c_rd_v_li)

     ,.c_wr_addr_o(c_wr_addr_lo)
     ,.c_wr_data_o(c_wr_data_lo)
     ,.c_wr_mask_o(c_wr_mask_lo)
     ,.c_wr_v_o(c_wr_v_lo)
     ,.c_wr_yumi_i(c_wr_yumi_li)

     ,.c_wr_ack_i(c_wr_ack_li)
     ,.interrupt_o(interrupt_o)
     );

  // Peripheral interface
  assign p_addr_li = axil_addr_lo;
  assign p_data_li = axil_data_lo;
  assign p_w_li = axil_w_lo;
  assign p_v_li = axil_v_lo;
  assign axil_yumi_li = p_yumi_lo;

  assign axil_data_li = p_data_lo;
  assign axil_v_li = p_v_lo;

  // Core interface
  assign m_axil_araddr_o = c_rd_addr_lo;
  assign m_axil_arprot_o = e_axi_prot_dsn;
  assign m_axil_arvalid_o = c_rd_v_lo;
  assign c_rd_yumi_li = m_axil_arready_i & m_axil_arvalid_o;

  assign c_rd_addr_li = '0; // Unused because we're in-order
  assign c_rd_data_li = m_axil_rdata_i;
  wire unused0 = &{m_axil_rresp_i};
  assign c_rd_v_li = m_axil_rvalid_i;
  assign m_axil_rready_o = 1'b1;

  assign m_axil_awaddr_o = c_wr_addr_lo;
  assign m_axil_awprot_o = e_axi_prot_dsn;

  assign m_axil_wdata_o = c_wr_data_lo;
  assign m_axil_wstrb_o = c_wr_mask_lo;

  // Comply with AXI handshake
  bsg_mla_valid_yumi_1_to_n
   #(.out_ch_p(2))
   hs
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(c_wr_v_lo)
     ,.yumi_o(c_wr_yumi_li)

     ,.v_o({m_axil_wvalid_o, m_axil_awvalid_o})
     ,.yumi_i({m_axil_wready_i, m_axil_awready_i})
     );

  assign m_axil_bready_o = 1'b1;
  assign c_wr_ack_li = m_axil_bready_o & m_axil_bvalid_i;

endmodule

