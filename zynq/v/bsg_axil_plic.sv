
`include "bsg_defines.sv"

module bsg_axil_plic
 import top_pkg::*;
 import rv_plic_reg_pkg::*;
 #(parameter m_axil_data_width_p = 32
   , parameter m_axil_addr_width_p = 32
   , localparam m_axil_strb_width_lp = m_axil_data_width_p >> 3

   , parameter s_axil_data_width_p = 32
   , parameter s_axil_addr_width_p = 32
   , localparam s_axil_strb_width_lp = s_axil_data_width_p >> 3

   , parameter base_addr_p = 32'h300000
   , parameter num_src_p = 2
   , parameter num_tgt_p = 1
   )
  (input                                        clk_i
   , input                                      reset_i

   // Interrupt Sources
   , input [num_src_p-1:0]                      intr_src_i
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
   );

  logic axil_v_lo, axil_w_lo, axil_ready_and_li;
  logic [s_axil_addr_width_p-1:0] axil_addr_lo;
  logic [s_axil_data_width_p-1:0] axil_data_lo;
  logic [s_axil_strb_width_lp-1:0] axil_wmask_lo;

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
     ,.ready_and_i(axil_ready_and_li)

     ,.data_i(axil_data_li)
     ,.v_i(axil_v_li)
     ,.ready_and_o(axil_ready_and_lo)

     ,.*
     );

  // Interrupt notification to targets
  localparam plic_id_width_lp = `BSG_SAFE_CLOG2(num_src_p);
  logic [num_src_p-1:0] irq_lo;
  logic [plic_id_width_lp-1:0] irq_id_lo [num_tgt_p];

  bsg_irq_to_axil
   #(.axil_data_width_p(m_axil_data_width_p)
     ,.axil_addr_width_p(m_axil_addr_width_p)
     ,.irq_sources_p(num_src_p)
     ,.irq_addr_p(base_addr_p)
     )
   irq2axil
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.irq_r_i(irq_lo)

     ,.*
     );

  logic reg_we, reg_re, reg_error;
  logic [top_pkg::TL_AW-1:0] reg_addr;
  logic [top_pkg::TL_DW-1:0] reg_wdata;
  logic [top_pkg::TL_DBW-1:0] reg_be;
  logic [top_pkg::TL_DW-1:0] reg_rdata;

  wire rst_ni = ~reset_i;
  rv_plic plic
    (.clk_i(clk_i)
     ,.rst_ni(rst_ni)

     ,.reg_we(reg_we)
     ,.reg_re(reg_re)
     ,.reg_addr(reg_addr)
     ,.reg_wdata(reg_wdata)
     ,.reg_be(reg_be)
     ,.reg_rdata(reg_rdata)
     ,.reg_error(reg_error)

      // Interrupt Sources
     ,.intr_src_i(intr_src_i)

      // Interrupt notification to targets
     ,.irq_o(irq_lo)
     ,.irq_id_o(irq_id_lo)
     );

  // loopback responses
  bsg_one_fifo
   #(.width_p(s_axil_data_width_p))
   output_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(axil_data_lo)
     ,.v_i(axil_v_lo)
     ,.ready_and_o(axil_ready_and_li)

     ,.data_o(axil_data_li)
     ,.v_o(axil_v_li)
     ,.yumi_i(axil_ready_and_lo & axil_v_li)
     );

  assign reg_we = axil_ready_and_li & axil_v_lo &  axil_w_lo;
  assign reg_re = axil_ready_and_li & axil_v_lo & ~axil_w_lo;
  assign reg_addr = axil_addr_lo;
  assign reg_wdata = axil_data_lo;
  assign reg_be = axil_wmask_lo;

  wire unused = &{reg_rdata, reg_error};

  if (m_axil_data_width_p > top_pkg::TL_DW || s_axil_data_width_p > top_pkg::TL_DW)
    $error("TL data too small");

  if (m_axil_addr_width_p > top_pkg::TL_AW || s_axil_addr_width_p > top_pkg::TL_AW)
    $error("TL address too small");

endmodule

