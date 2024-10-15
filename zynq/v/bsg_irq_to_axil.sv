
`include "bsg_defines.sv"

module bsg_irq_to_axil
 #(parameter axil_data_width_p = 32
   , parameter axil_addr_width_p = 32
   , parameter irq_sources_p = 2
   , parameter irq_addr_p = 32'h00000000
   )
  (input                                        clk_i
   , input                                      reset_i
   // Interrupt notification
   // register to help meet timing
   , input [irq_sources_p-1:0]                  irq_r_i

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

  logic axil_ready_and_lo, axil_v_li, axil_w_li;
  logic [axil_data_width_p-1:0] axil_data_li;
  logic [axil_data_width_p/8-1:0] axil_wmask_li;
  logic [axil_addr_width_p-1:0] axil_addr_li;

  logic axil_ready_and_li, axil_v_lo;
  logic [axil_data_width_p-1:0] axil_data_lo;
  bsg_axil_fifo_master
   #(.axil_data_width_p(axil_data_width_p), .axil_addr_width_p(axil_addr_width_p))
   axilm
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(axil_v_li)
     ,.w_i(axil_w_li)
     ,.addr_i(axil_addr_li)
     ,.data_i(axil_data_li)
     ,.wmask_i(axil_wmask_li)
     ,.ready_and_o(axil_ready_and_lo)

     ,.data_o(axil_data_lo)
     ,.v_o(axil_v_lo)
     ,.ready_and_i(axil_ready_and_li)

     ,.*
     );

  logic [irq_sources_p-1:0] irq_detected_n, irq_detected_r;
  for (genvar i = 0; i < irq_sources_p; i++)
    begin : src
      assign irq_detected_n[i] = irq_r_i & axil_ready_and_lo;
      bsg_edge_detect
       #(.falling_not_rising_p(0))
       bed
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.sig_i(irq_detected_n[i])
         ,.detect_o(irq_detected_r[i])
         );
    end

  localparam irq_id_width_lp = `BSG_SAFE_CLOG2(irq_sources_p);
  logic [irq_id_width_lp-1:0] irq_sel_lo;
  logic any_irq_lo;
  bsg_priority_encode
   #(.width_p(irq_sources_p), .lo_to_hi_p(1))
   pe
    (.i(irq_detected_r)
     ,.addr_o(irq_sel_lo)
     ,.v_o(any_irq_lo)
     );
  wire [axil_addr_width_p-1:0] irq_offset_lo = irq_sel_lo << 2;

  assign axil_v_li = any_irq_lo;
  assign axil_w_li = 1'b1;
  assign axil_addr_li = irq_addr_p + irq_offset_lo;
  assign axil_data_li = '0;
  assign axil_wmask_li = '1;

  // Drop responses immediately
  assign axil_ready_and_li = 1'b1;

endmodule

