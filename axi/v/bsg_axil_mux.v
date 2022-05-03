
`include "bsg_defines.v"

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

  wire s00_rvld = s00_axil_arvalid;
  wire s00_wvld = s00_axil_awvalid;
  wire s01_rvld = s01_axil_arvalid;
  wire s01_wvld = s01_axil_awvalid;

  wire s00_rrsp = (s00_axil_rready & s00_axil_rvalid);
  wire s00_wrsp = (s00_axil_bready & s00_axil_bvalid);
  wire s01_rrsp = (s00_axil_rready & s00_axil_rvalid);
  wire s01_wrsp = (s00_axil_bready & s00_axil_bvalid);
  wire any_rsp = |{s00_rrsp, s00_wrsp, s01_rrsp, s01_wrsp};

  logic s00_rreq, s00_wreq, s01_rreq, s01_wreq;
  bsg_dff_reset_set_clear
   #(.width_p(4))
   req_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i({s01_wvld, s01_rvld, s00_wvld, s00_rvld})
     ,.clear_i({s01_wrsp, s01_rrsp, s00_wrsp, s00_rrsp})
     ,.data_o({s01_wreq, s01_rreq, s00_wreq, s00_rreq})
     );

  logic s00_rgnt, s00_wgnt, s01_rgnt, s01_wgnt;
  bsg_arb_round_robin
   #(.width_p(4))
   rr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.reqs_i({s01_wreq, s01_rreq, s00_wreq, s00_rreq})
     ,.grants_o({s01_wgnt, s01_rgnt, s00_wgnt, s00_rgnt})
     ,.yumi_i(any_rsp)
     );

  assign m00_axil_awaddr  = s01_wgnt ? s01_axil_awaddr : s00_axil_awaddr;
  assign m00_axil_awprot  = s01_wgnt ? s01_axil_awprot : s00_axil_awprot;
  assign m00_axil_awvalid = (s00_wgnt & s00_axil_awvalid) || (s01_wgnt & s01_axil_awvalid);
  assign s00_axil_awready = m00_axil_awready & s00_wgnt;
  assign s01_axil_awready = m00_axil_awready & s01_wgnt;

  assign m00_axil_wdata  = s01_wgnt ? s01_axil_wdata : s00_axil_wdata;
  assign m00_axil_wstrb  = s01_wgnt ? s01_axil_wstrb : s00_axil_wstrb;
  assign m00_axil_wvalid = (s00_wgnt & s00_axil_wvalid) | (s01_wgnt & s01_axil_wvalid);
  assign s00_axil_wready = m00_axil_wready & s00_wgnt;
  assign s01_axil_wready = m00_axil_wready & s01_wgnt;

  assign {s01_axil_bresp, s00_axil_bresp} = {2{m00_axil_bresp}};
  assign s00_axil_bvalid = s00_wgnt & m00_axil_bvalid;
  assign s00_axil_bvalid = s01_wgnt & m00_axil_bvalid;
  assign m00_axil_bready = (s00_wgnt & s00_axil_bready) | (s01_wgnt & s01_axil_bready);

  assign m00_axil_araddr  = s01_rgnt ? s01_axil_araddr : s00_axil_araddr;
  assign m00_axil_arprot  = s01_rgnt ? s01_axil_arprot : s00_axil_arprot;
  assign m00_axil_arvalid = (s00_rgnt & s00_axil_arvalid) | (s01_rgnt & s01_axil_arvalid);
  assign s00_axil_arready = s00_rgnt & m00_axil_arready;
  assign s01_axil_arready = s01_rgnt & m00_axil_arready;

  assign {s01_axil_rdata, s00_axil_rdata} = {2{m00_axil_rdata}};
  assign {s01_axil_rresp, s00_axil_rresp} = {2{m00_axil_rresp}};
  assign s00_axil_rvalid = s00_rgnt & m00_axil_rvalid;
  assign s01_axil_rvalid = s01_rgnt & m00_axil_rvalid;
  assign m00_axil_rready = (s00_rgnt & s00_axil_rready) | (s01_rgnt & s01_axil_rready);

endmodule

`BSG_ABSTRACT_MODULE(bsg_axil_mux)

