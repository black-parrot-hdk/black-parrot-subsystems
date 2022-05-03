
`include "bsg_defines.v"

module bsg_axil_demux
 #(parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(split_addr_p)

   , localparam mask_width_lp = data_width_p>>3
   )
  (input                                 clk_i
   , input                               reset_i

   , input [addr_width_p-1:0]            s00_axil_awaddr
   , input [2:0]                         s00_axil_awprot
   , input                               s00_axil_awvalid
   , output logic                        s00_axil_awready

   , input [data_width_p-1:0]            s00_axil_wdata
   , input [mask_width_lp-1:0]           s00_axil_wstrb
   , input                               s00_axil_wvalid
   , output logic                        s00_axil_wready

   , output logic [1:0]                  s00_axil_bresp
   , output logic                        s00_axil_bvalid
   , input                               s00_axil_bready

   , input [addr_width_p-1:0]            s00_axil_araddr
   , input [2:0]                         s00_axil_arprot
   , input                               s00_axil_arvalid
   , output logic                        s00_axil_arready

   , output logic [data_width_p-1:0]     s00_axil_rdata
   , output logic [1:0]                  s00_axil_rresp
   , output logic                        s00_axil_rvalid
   , input                               s00_axil_rready

   , output logic [addr_width_p-1:0]     m00_axil_awaddr
   , output logic [2:0]                  m00_axil_awprot
   , output logic                        m00_axil_awvalid
   , input                               m00_axil_awready

   , output logic [data_width_p-1:0]     m00_axil_wdata
   , output logic [mask_width_lp-1:0]    m00_axil_wstrb
   , output logic                        m00_axil_wvalid
   , input                               m00_axil_wready

   , input [1:0]                         m00_axil_bresp
   , input                               m00_axil_bvalid
   , output logic                        m00_axil_bready

   , output logic [addr_width_p-1:0]     m00_axil_araddr
   , output logic [2:0]                  m00_axil_arprot
   , output logic                        m00_axil_arvalid
   , input                               m00_axil_arready

   , input [data_width_p-1:0]            m00_axil_rdata
   , input [1:0]                         m00_axil_rresp
   , input                               m00_axil_rvalid
   , output logic                        m00_axil_rready

   , output logic [addr_width_p-1:0]     m01_axil_awaddr
   , output logic [2:0]                  m01_axil_awprot
   , output logic                        m01_axil_awvalid
   , input                               m01_axil_awready

   , output logic [data_width_p-1:0]     m01_axil_wdata
   , output logic [mask_width_lp-1:0]    m01_axil_wstrb
   , output logic                        m01_axil_wvalid
   , input                               m01_axil_wready

   , input [1:0]                         m01_axil_bresp
   , input                               m01_axil_bvalid
   , output logic                        m01_axil_bready

   , output logic [addr_width_p-1:0]     m01_axil_araddr
   , output logic [2:0]                  m01_axil_arprot
   , output logic                        m01_axil_arvalid
   , input                               m01_axil_arready

   , input [data_width_p-1:0]            m01_axil_rdata
   , input [1:0]                         m01_axil_rresp
   , input                               m01_axil_rvalid
   , output logic                        m01_axil_rready
   );

  wire m00_rvld = (s00_axil_arvalid && (s00_axil_araddr < split_addr_p));
  wire m00_wvld = (s00_axil_awvalid && (s00_axil_awaddr < split_addr_p));
  wire m01_rvld = (s00_axil_arvalid && (s00_axil_araddr >= split_addr_p));
  wire m01_wvld = (s00_axil_awvalid && (s00_axil_awaddr >= split_addr_p));

  wire m00_rrsp = (m00_axil_rready & m00_axil_rvalid);
  wire m00_wrsp = (m00_axil_bready & m00_axil_bvalid);
  wire m01_rrsp = (m01_axil_rready & m01_axil_rvalid);
  wire m01_wrsp = (m01_axil_bready & m01_axil_bvalid);
  wire any_rsp = |{m00_rrsp, m00_wrsp, m01_rrsp, m01_wrsp};

  logic m00_rreq, m00_wreq, m01_rreq, m01_wreq;
  bsg_dff_reset_set_clear
   #(.width_p(4))
   req_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i({m01_wvld, m01_rvld, m00_wvld, m00_rvld})
     ,.clear_i({m01_wrsp, m01_rrsp, m00_wrsp, m00_rrsp})
     ,.data_o({m01_wreq, m01_rreq, m00_wreq, m00_rreq})
     );

  logic m00_rgnt, m00_wgnt, m01_rgnt, m01_wgnt;
  bsg_arb_round_robin
   #(.width_p(4))
   rr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reqs_i({m01_wreq, m01_rreq, m00_wreq, m00_rreq})
     ,.grants_o({m01_wgnt, m01_rgnt, m00_wgnt, m00_rgnt})
     ,.yumi_i(any_rsp)
     );

  assign {m01_axil_awaddr, m00_axil_awaddr} = {2{s00_axil_awaddr}};
  assign {m01_axil_awprot, m00_axil_awprot} = {2{s00_axil_awprot}};
  assign m00_axil_awvalid = m00_wgnt & s00_axil_awvalid;
  assign m01_axil_awvalid = m01_wgnt & s00_axil_awvalid;
  assign s00_axil_awready = (m00_wgnt & m00_axil_awready) | (m01_wgnt & m01_axil_awready);

  assign {m01_axil_wdata, m00_axil_wdata} = {2{s00_axil_wdata}};
  assign {m01_axil_wstrb, m00_axil_wstrb} = {2{s00_axil_wstrb}};
  assign m00_axil_wvalid = m00_wgnt & s00_axil_wvalid;
  assign m01_axil_wvalid = m01_wgnt & s00_axil_wvalid;
  assign s00_axil_wready = (m00_wgnt & m00_axil_wready) | (m01_wgnt & m01_axil_wready);

  assign s00_axil_bresp  = m01_wgnt ? m01_axil_bresp : m00_axil_bresp;
  assign s00_axil_bvalid = (m00_wgnt & m00_axil_bvalid) | (m01_wgnt & m01_axil_bvalid);
  assign m00_axil_bready = m00_wgnt & s00_axil_bready;
  assign m01_axil_bready = m01_wgnt & s00_axil_bready;

  assign {m01_axil_araddr, m00_axil_araddr} = {2{s00_axil_araddr}};
  assign {m01_axil_arprot, m00_axil_arprot} = {2{s00_axil_arprot}};
  assign m00_axil_arvalid = m00_rgnt & s00_axil_arvalid;
  assign m01_axil_arvalid = m01_rgnt & s00_axil_arvalid;
  assign s00_axil_arready = (m00_rgnt & m00_axil_arready) | (m01_rgnt & m01_axil_arready);

  assign s00_axil_rdata = m01_rgnt ? m01_axil_rdata : m00_axil_rdata;
  assign s00_axil_rresp = m01_rgnt ? m01_axil_rresp : m00_axil_rresp;
  assign s00_axil_rvalid = (m00_rgnt & m00_axil_rvalid) | (m01_rgnt & m01_axil_rvalid);
  assign m00_axil_rready = m00_rgnt & s00_axil_rready;
  assign m01_axil_rready = m01_rgnt & s00_axil_rready;

endmodule

`BSG_ABSTRACT_MODULE(bsg_axil_demux)

