

`include "bsg_manycore_defines.vh"

module bsg_manycore_axil_bridge
 import bsg_manycore_pkg::*;
 #(parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(icache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(axil_addr_width_p)
   , parameter `BSG_INV_PARAM(axil_data_width_p)

   , localparam axil_mask_width_lp = axil_data_width_p>>3
   , localparam link_sif_width_lp =
       `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
   )
  (input                                        clk_i
   , input                                      reset_i

   , input [link_sif_width_lp-1:0]              link_sif_i
   , output logic [link_sif_width_lp-1:0]       link_sif_o

   , input [x_cord_width_p-1:0]                 my_x_i
   , input [y_cord_width_p-1:0]                 my_y_i

   , input [x_cord_width_p-1:0]                 dest_x_i
   , input [y_cord_width_p-1:0]                 dest_y_i

   //====================== AXI-4 LITE Master =========================
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

   //====================== AXI-4 LITE =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_awaddr_i
   , input [2:0]                                s_axil_awprot_i
   , input                                      s_axil_awvalid_i
   , output logic                               s_axil_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [axil_data_width_p-1:0]              s_axil_wdata_i
   , input [axil_mask_width_lp-1:0]             s_axil_wstrb_i
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

  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  bsg_manycore_link_sif_s link_sif_cast_i, link_sif_cast_o;
  assign link_sif_cast_i = link_sif_i;
  assign link_sif_o = link_sif_cast_o;

  logic in_v_lo;
  logic in_we_lo;
  logic [addr_width_p-1:0] in_addr_lo;
  logic [data_width_p-1:0] in_data_lo;
  logic [(data_width_p>>3)-1:0] in_mask_lo;
  logic in_yumi_li;
  bsg_manycore_load_info_s in_load_info_lo;

  logic returning_data_v_li;
  logic [data_width_p-1:0] returning_data_li;

  bsg_manycore_packet_s out_packet_li;
  logic out_v_li;
  logic out_credit_or_ready_lo;
  logic link_credit_lo;

  logic returned_v_r_lo, returned_credit_v_r_lo;
  logic returned_yumi_li;
  logic [data_width_p-1:0] returned_data_r_lo;
  bsg_manycore_return_packet_type_e returned_pkt_type_r_lo;
  logic [bsg_manycore_reg_id_width_gp-1:0] returned_reg_id_r_lo;
  logic returned_fifo_full_lo;

  bsg_manycore_endpoint_standard
   #(.x_cord_width_p(x_cord_width_p)
     ,.y_cord_width_p(y_cord_width_p)
     ,.data_width_p(data_width_p)
     ,.addr_width_p(addr_width_p)
     ,.icache_block_size_in_words_p(icache_block_size_in_words_p)

     // Reasonable defaults
     ,.fifo_els_p(2)
     ,.credit_counter_width_p(2)
     ,.rev_fifo_els_p(2)
     ,.use_credits_for_local_fifo_p(1)
     )
   endp
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.link_sif_i(link_sif_cast_i)
     ,.link_sif_o(link_sif_cast_o)

     ,.global_x_i(my_x_i)
     ,.global_y_i(my_y_i)

     // rx
     ,.in_v_o(in_v_lo)
     ,.in_we_o(in_we_lo)
     ,.in_addr_o(in_addr_lo)
     ,.in_data_o(in_data_lo)
     ,.in_mask_o(in_mask_lo)
     ,.in_yumi_i(in_yumi_li)
     ,.in_load_info_o(in_load_info_lo)

     ,.returning_v_i(returning_data_v_li)
     ,.returning_data_i(returning_data_li)

     // tx
     ,.out_packet_i(out_packet_li)
     ,.out_v_i(out_v_li)
     ,.out_credit_or_ready_o(out_credit_or_ready_lo)

     ,.returned_v_r_o(returned_v_r_lo)
     ,.returned_credit_v_r_o(returned_credit_v_r_lo)
     ,.returned_data_r_o(returned_data_r_lo)
     ,.returned_reg_id_r_o(returned_reg_id_r_lo)
     ,.returned_pkt_type_r_o(returned_pkt_type_r_lo)
     ,.returned_fifo_full_o(returned_fifo_full_lo)
     ,.returned_yumi_i(returned_yumi_li)

     /* Unused */
     ,.in_src_x_cord_o()
     ,.in_src_y_cord_o()
     ,.returned_credit_reg_id_r_o()
     ,.out_credits_used_o()
     );


  logic [axil_data_width_p-1:0] c_wdata_lo;
  logic [axil_addr_width_p-1:0] c_addr_lo;
  logic c_v_lo, c_w_lo, c_ready_and_li;
  logic [axil_mask_width_lp-1:0] c_wmask_lo;

  logic [axil_data_width_p-1:0] c_rdata_li;
  logic c_v_li, c_ready_and_lo;
  bsg_axil_fifo_client
   #(.axil_data_width_p(axil_data_width_p)
     ,.axil_addr_width_p(axil_addr_width_p)
     )
   axil_client
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_o(c_wdata_lo)
     ,.addr_o(c_addr_lo)
     ,.v_o(c_v_lo)
     ,.w_o(c_w_lo)
     ,.wmask_o(c_wmask_lo)
     ,.ready_and_i(c_ready_and_li)

     ,.data_i(c_rdata_li)
     ,.v_i(c_v_li)
     ,.ready_and_o(c_ready_and_lo)

     ,.*
     );

  bsg_manycore_packet_op_e out_op_v2;
  bsg_manycore_packet_reg_id_u out_reg_id;
  bsg_manycore_packet_payload_u out_payload;
  bsg_manycore_load_info_s out_load_info;

  assign out_load_info =
    '{is_unsigned_op: 1'b1
      ,is_byte_op   : (c_wmask_lo == 4'b0001)
                      | (c_wmask_lo == 4'b0010)
                      | (c_wmask_lo == 4'b0100)
                      | (c_wmask_lo == 4'b1000)
      ,is_hex_op    : (c_wmask_lo == 4'b0011)
                      | (c_wmask_lo == 4'b1100)
      ,part_sel     : c_addr_lo[0+:2]
      ,default : '0
      };

  bsg_manycore_packet_op_e out_st_op;
  bsg_manycore_packet_payload_u out_st_payload;
  bsg_manycore_packet_reg_id_u out_st_reg_id;
  bsg_manycore_reg_id_encode
   #(.data_width_p(data_width_p))
   reg_id_encode
    (.data_i(c_wdata_lo)
     ,.mask_i(c_wmask_lo)
     ,.reg_id_i('0)
     ,.data_o(out_st_payload)
     ,.reg_id_o(out_st_reg_id)
     ,.op_o(out_st_op)
     );

  assign out_op_v2 = c_w_lo ? out_st_op : e_remote_load;
  assign out_reg_id = c_w_lo ? out_st_reg_id : '0;
  assign out_payload = c_w_lo ? out_st_payload : out_load_info;

  assign out_packet_li.addr       = (c_addr_lo >> 2'b10);
  assign out_packet_li.op_v2      = out_op_v2;
  assign out_packet_li.reg_id     = out_reg_id;
  assign out_packet_li.payload    = out_payload;
  assign out_packet_li.src_x_cord = my_x_i;
  assign out_packet_li.src_y_cord = my_y_i;
  assign out_packet_li.y_cord     = dest_x_i;
  assign out_packet_li.x_cord     = dest_y_i;
  assign out_v_li = c_v_lo;
  assign c_ready_and_li = out_credit_or_ready_lo;

  assign c_rdata_li = returned_data_r_lo;
  assign c_v_li = returned_v_r_lo | returned_credit_v_r_lo;
  assign returned_yumi_li = c_ready_and_lo & c_v_li;

  logic [axil_data_width_p-1:0] m_wdata_li;
  logic [axil_addr_width_p-1:0] m_addr_li;
  logic m_v_li, m_w_li, m_ready_and_lo;
  logic [axil_mask_width_lp-1:0] m_wmask_li;

  logic [axil_data_width_p-1:0] m_rdata_lo;
  logic m_v_lo, m_ready_and_li;
  bsg_axil_fifo_master
   #(.axil_data_width_p(axil_data_width_p)
     ,.axil_addr_width_p(axil_addr_width_p)
     )
   axil_master
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(m_v_li)
     ,.w_i(m_w_li)
     ,.addr_i(m_addr_li)
     ,.data_i(m_wdata_li)
     ,.wmask_i(m_wmask_li)
     ,.ready_and_o(m_ready_and_lo)

     ,.data_o(m_rdata_lo)
     ,.v_o(m_v_lo)
     ,.ready_and_i(m_ready_and_li)

     ,.*
     );

  assign m_v_li = in_v_lo;
  assign m_w_li = in_we_lo;
  assign m_addr_li = (in_addr_lo << 2'b10);
  assign m_wdata_li = in_data_lo;
  assign m_wmask_li = in_mask_lo;
  assign in_yumi_li = m_ready_and_lo & m_v_li;

  assign returning_data_li = m_rdata_lo;
  assign returning_data_v_li = m_v_lo;
  assign m_ready_and_li = 1'b1;

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_axil_bridge)

