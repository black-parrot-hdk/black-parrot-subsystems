
`include "bsg_defines.sv"

module bsg_axil_mux
 #(parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)

   , localparam mask_width_lp = data_width_p>>3
   )
  (input                                   clk_i
   , input                                 reset_i

   , input [addr_width_p-1:0]              s00_axil_awaddr
   , input [2:0]                           s00_axil_awprot
   , input                                 s00_axil_awvalid
   , output logic                          s00_axil_awready

   , input [data_width_p-1:0]              s00_axil_wdata
   , input [mask_width_lp-1:0]             s00_axil_wstrb
   , input                                 s00_axil_wvalid
   , output logic                          s00_axil_wready

   , output logic [1:0]                    s00_axil_bresp
   , output logic                          s00_axil_bvalid
   , input                                 s00_axil_bready

   , input [addr_width_p-1:0]              s00_axil_araddr
   , input [2:0]                           s00_axil_arprot
   , input                                 s00_axil_arvalid
   , output logic                          s00_axil_arready

   , output logic [data_width_p-1:0]       s00_axil_rdata
   , output logic [1:0]                    s00_axil_rresp
   , output logic                          s00_axil_rvalid
   , input                                 s00_axil_rready

   , input [addr_width_p-1:0]              s01_axil_awaddr
   , input [2:0]                           s01_axil_awprot
   , input                                 s01_axil_awvalid
   , output logic                          s01_axil_awready

   , input [data_width_p-1:0]              s01_axil_wdata
   , input [mask_width_lp-1:0]             s01_axil_wstrb
   , input                                 s01_axil_wvalid
   , output logic                          s01_axil_wready

   , output logic [1:0]                    s01_axil_bresp
   , output logic                          s01_axil_bvalid
   , input                                 s01_axil_bready

   , input [addr_width_p-1:0]              s01_axil_araddr
   , input [2:0]                           s01_axil_arprot
   , input                                 s01_axil_arvalid
   , output logic                          s01_axil_arready

   , output logic [data_width_p-1:0]       s01_axil_rdata
   , output logic [1:0]                    s01_axil_rresp
   , output logic                          s01_axil_rvalid
   , input                                 s01_axil_rready

   , output logic [addr_width_p-1:0]       m00_axil_awaddr
   , output logic [2:0]                    m00_axil_awprot
   , output logic                          m00_axil_awvalid
   , input                                 m00_axil_awready

   , output logic [data_width_p-1:0]       m00_axil_wdata
   , output logic [mask_width_lp-1:0]      m00_axil_wstrb
   , output logic                          m00_axil_wvalid
   , input                                 m00_axil_wready

   , input [1:0]                           m00_axil_bresp
   , input                                 m00_axil_bvalid
   , output logic                          m00_axil_bready

   , output logic [addr_width_p-1:0]       m00_axil_araddr
   , output logic [2:0]                    m00_axil_arprot
   , output logic                          m00_axil_arvalid
   , input                                 m00_axil_arready

   , input [data_width_p-1:0]              m00_axil_rdata
   , input [1:0]                           m00_axil_rresp
   , input                                 m00_axil_rvalid
   , output logic                          m00_axil_rready
   );

  logic [3:0] reqs_li, grants_lo;
  logic grants_en_li, rr_v_lo;
  bsg_round_robin_arb
   #(.inputs_p(4), .hold_on_valid_p(1))
   rr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.grants_en_i(grants_en_li)
     ,.reqs_i(reqs_li)
     ,.grants_o(grants_lo)
     ,.sel_one_hot_o()
     ,.v_o(rr_v_lo)
     ,.tag_o()
     ,.yumi_i(rr_v_lo)
     );

  logic pending_w_v;
  logic pending_v_n, pending_v_r;
  logic pending_type_n, pending_type_r;
  logic pending_tag_n, pending_tag_r;
  bsg_dff_reset_en
   #(.width_p(3))
   return_flop
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(pending_w_v)
     ,.data_i({pending_v_n, pending_type_n, pending_tag_n})
     ,.data_o({pending_v_r, pending_type_r, pending_tag_r})
     );

  logic [data_width_p-1:0] data_li;
  logic [addr_width_p-1:0] addr_li;
  logic [mask_width_lp-1:0] wmask_li;
  logic v_li, w_li, ready_and_lo;
  logic [data_width_p-1:0] data_lo;
  logic v_lo, ready_and_li;
  bsg_axil_fifo_master
   #(.axil_data_width_p(data_width_p)
     ,.axil_addr_width_p(addr_width_p)
     )
   master
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(data_li)
     ,.addr_i(addr_li)
     ,.v_i(v_li)
     ,.w_i(w_li)
     ,.wmask_i(wmask_li)
     ,.ready_and_o(ready_and_lo)

     ,.data_o(data_lo)
     ,.v_o(v_lo)
     ,.ready_and_i(ready_and_li)

     ,.m_axil_awaddr_o(m00_axil_awaddr)
     ,.m_axil_awprot_o(m00_axil_awprot)
     ,.m_axil_awvalid_o(m00_axil_awvalid)
     ,.m_axil_awready_i(m00_axil_awready)

     ,.m_axil_wdata_o(m00_axil_wdata)
     ,.m_axil_wstrb_o(m00_axil_wstrb)
     ,.m_axil_wvalid_o(m00_axil_wvalid)
     ,.m_axil_wready_i(m00_axil_wready)

     ,.m_axil_bresp_i(m00_axil_bresp)
     ,.m_axil_bvalid_i(m00_axil_bvalid)
     ,.m_axil_bready_o(m00_axil_bready)

     ,.m_axil_araddr_o(m00_axil_araddr)
     ,.m_axil_arprot_o(m00_axil_arprot)
     ,.m_axil_arvalid_o(m00_axil_arvalid)
     ,.m_axil_arready_i(m00_axil_arready)

     ,.m_axil_rdata_i(m00_axil_rdata)
     ,.m_axil_rresp_i(m00_axil_rresp)
     ,.m_axil_rvalid_i(m00_axil_rvalid)
     ,.m_axil_rready_o(m00_axil_rready)
     );

  assign reqs_li = {(s01_axil_awvalid & s01_axil_wvalid)
                    ,s01_axil_arvalid
                    ,(s00_axil_awvalid & s00_axil_wvalid)
                    ,s00_axil_arvalid
                    };

  logic [3:0] grants_r;
  bsg_dff
   #(.width_p(4))
   grants_reg
    (.clk_i(clk_i)
     ,.data_i(grants_lo)
     ,.data_o(grants_r)
     );
  assign grants_en_li = ready_and_lo & ~pending_v_r & ~|grants_r;

  assign s01_axil_awready = grants_r[3];
  assign s01_axil_wready = grants_r[3];
  assign s01_axil_arready = grants_r[2];
  assign s00_axil_awready = grants_r[1];
  assign s00_axil_wready = grants_r[1];
  assign s00_axil_arready = grants_r[0];

  assign v_li = |grants_lo;
  assign w_li = pending_type_n;
  assign wmask_li = pending_tag_n ? s01_axil_wstrb : s00_axil_wstrb;
  assign data_li = pending_tag_n ? s01_axil_wdata : s00_axil_wdata;
  assign addr_li = pending_tag_n ? pending_type_n ? s01_axil_awaddr : s01_axil_araddr
                                 : pending_type_n ? s00_axil_awaddr : s00_axil_araddr;

  assign {s01_axil_rdata, s00_axil_rdata} = {2{data_lo}};
  assign s01_axil_bvalid =  pending_tag_r &  pending_type_r & v_lo;
  assign s01_axil_rvalid =  pending_tag_r & !pending_type_r & v_lo;
  assign s00_axil_bvalid = !pending_tag_r &  pending_type_r & v_lo;
  assign s00_axil_rvalid = !pending_tag_r & !pending_type_r & v_lo;
  assign ready_and_li = pending_tag_r ? pending_type_r ? s01_axil_bready : s01_axil_rready
                                      : pending_type_r ? s00_axil_bready : s00_axil_rready;

  assign pending_w_v = (v_li & ready_and_lo) || (v_lo & ready_and_li);
  assign pending_v_n = (v_li & ready_and_lo);
  assign pending_tag_n = grants_lo[3] | grants_lo[2];
  assign pending_type_n = grants_lo[3] | grants_lo[1];

endmodule

