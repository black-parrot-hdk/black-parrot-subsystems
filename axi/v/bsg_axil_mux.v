
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

  localparam fifo_els_lp = 2;

  logic [addr_width_p-1:0]  s00_axil_awaddr_buffered;
  logic [2:0]               s00_axil_awprot_buffered;
  logic                     s00_axil_awvalid_buffered;
  logic                     s00_axil_awready_buffered;

  logic [data_width_p-1:0]  s00_axil_wdata_buffered;
  logic [mask_width_lp-1:0] s00_axil_wstrb_buffered;
  logic                     s00_axil_wvalid_buffered;
  logic                     s00_axil_wready_buffered;

  logic [addr_width_p-1:0]  s00_axil_araddr_buffered;
  logic [2:0]               s00_axil_arprot_buffered;
  logic                     s00_axil_arvalid_buffered;
  logic                     s00_axil_arready_buffered;


  logic [addr_width_p-1:0]  s01_axil_awaddr_buffered;
  logic [2:0]               s01_axil_awprot_buffered;
  logic                     s01_axil_awvalid_buffered;
  logic                     s01_axil_awready_buffered;

  logic [data_width_p-1:0]  s01_axil_wdata_buffered;
  logic [mask_width_lp-1:0] s01_axil_wstrb_buffered;
  logic                     s01_axil_wvalid_buffered;
  logic                     s01_axil_wready_buffered;

  logic [addr_width_p-1:0]  s01_axil_araddr_buffered;
  logic [2:0]               s01_axil_arprot_buffered;
  logic                     s01_axil_arvalid_buffered;
  logic                     s01_axil_arready_buffered;

  bsg_fifo_1r1w_small
   #(.width_p(addr_width_p+3), .els_p(fifo_els_lp))
   input_awaddr_fifo_0
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({s00_axil_awaddr, s00_axil_awprot})
     ,.v_i(s00_axil_awvalid)
     ,.ready_o(s00_axil_awready)

     ,.data_o({s00_axil_awaddr_buffered, s00_axil_awprot_buffered})
     ,.v_o(s00_axil_awvalid_buffered)
     ,.yumi_i(s00_axil_awvalid_buffered & s00_axil_awready_buffered)
     );
  bsg_fifo_1r1w_small
   #(.width_p(data_width_p+mask_width_lp), .els_p(fifo_els_lp))
   input_wdata_fifo_0
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({s00_axil_wdata, s00_axil_wstrb})
     ,.v_i(s00_axil_wvalid)
     ,.ready_o(s00_axil_wready)

     ,.data_o({s00_axil_wdata_buffered, s00_axil_wstrb_buffered})
     ,.v_o(s00_axil_wvalid_buffered)
     ,.yumi_i(s00_axil_wvalid_buffered & s00_axil_wready_buffered)
     );
  bsg_fifo_1r1w_small
   #(.width_p(addr_width_p+3), .els_p(fifo_els_lp))
   input_araddr_fifo_0
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({s00_axil_araddr, s00_axil_arprot})
     ,.v_i(s00_axil_arvalid)
     ,.ready_o(s00_axil_arready)

     ,.data_o({s00_axil_araddr_buffered, s00_axil_arprot_buffered})
     ,.v_o(s00_axil_arvalid_buffered)
     ,.yumi_i(s00_axil_arvalid_buffered & s00_axil_arready_buffered)
     );

  bsg_fifo_1r1w_small
   #(.width_p(addr_width_p+3), .els_p(fifo_els_lp))
   input_awaddr_fifo_1
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({s01_axil_awaddr, s01_axil_awprot})
     ,.v_i(s01_axil_awvalid)
     ,.ready_o(s01_axil_awready)

     ,.data_o({s01_axil_awaddr_buffered, s01_axil_awprot_buffered})
     ,.v_o(s01_axil_awvalid_buffered)
     ,.yumi_i(s01_axil_awvalid_buffered & s01_axil_awready_buffered)
     );
  bsg_fifo_1r1w_small
   #(.width_p(data_width_p+mask_width_lp), .els_p(fifo_els_lp))
   input_wdata_fifo_1
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({s01_axil_wdata, s01_axil_wstrb})
     ,.v_i(s01_axil_wvalid)
     ,.ready_o(s01_axil_wready)

     ,.data_o({s01_axil_wdata_buffered, s01_axil_wstrb_buffered})
     ,.v_o(s01_axil_wvalid_buffered)
     ,.yumi_i(s01_axil_wvalid_buffered & s01_axil_wready_buffered)
     );
  bsg_fifo_1r1w_small
   #(.width_p(addr_width_p+3), .els_p(fifo_els_lp))
   input_araddr_fifo_1
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({s01_axil_araddr, s01_axil_arprot})
     ,.v_i(s01_axil_arvalid)
     ,.ready_o(s01_axil_arready)

     ,.data_o({s01_axil_araddr_buffered, s01_axil_arprot_buffered})
     ,.v_o(s01_axil_arvalid_buffered)
     ,.yumi_i(s01_axil_arvalid_buffered & s01_axil_arready_buffered)
     );

// Write Channel

  /////////////////////////////////////////////////////////////////////////////
  //   "wvalid_completed_r", "awvalid_completed_r" track the corresponding
  // completed handshaking, so that waddr and wdata channels can have separate
  // handshaking. If both waddr and wdata handshakings will be completed in
  // next cycle, both of them will be clear. This implies that the two
  // *completed_r signals will never be held high at the same time.

  logic wvalid_completed_n, awvalid_completed_n;
  logic wvalid_completed_r, awvalid_completed_r;
  wire write_complete = (((m00_axil_awvalid & m00_axil_awready) | awvalid_completed_r) &
    ((m00_axil_wvalid & m00_axil_wready) | wvalid_completed_r));

  bsg_dff_reset
   #(.width_p(2))
   write_valid_completed_regs
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({wvalid_completed_n, awvalid_completed_n})
     ,.data_o({wvalid_completed_r, awvalid_completed_r})
     );

  always_comb begin
    wvalid_completed_n  = wvalid_completed_r;
    awvalid_completed_n = awvalid_completed_r;
    if(write_complete) begin
      wvalid_completed_n  = 1'b0;
      awvalid_completed_n = 1'b0;
    end
    else begin
      if(m00_axil_awvalid & m00_axil_awready)
        awvalid_completed_n = 1'b1;
      if(m00_axil_wvalid & m00_axil_wready)
        wvalid_completed_n = 1'b1;
    end
  end

  logic s00_wgnt, s01_wgnt;
  logic write_resp_ready_lo;

  bsg_round_robin_arb
   #(.inputs_p(2), .hold_on_valid_p(1))
   write_rr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.grants_en_i(write_resp_ready_lo)
     ,.reqs_i({(s00_axil_awvalid_buffered & s00_axil_wvalid_buffered) & write_resp_ready_lo,
               (s01_axil_awvalid_buffered & s01_axil_wvalid_buffered) & write_resp_ready_lo})
     ,.grants_o({s00_wgnt, s01_wgnt})
     ,.sel_one_hot_o(/* UNUSED */)
     ,.v_o(/* UNUSED */)
     ,.tag_o(/* UNUSED */)
     ,.yumi_i(write_complete)
    );

  logic s00_wgnt_resp;
  logic s00_wgnt_resp_v_lo;
  wire s00_wgnt_resp_yumi_li = m00_axil_bvalid & m00_axil_bready;
  bsg_fifo_1r1w_small
   #(.width_p(1), .els_p(fifo_els_lp), .ready_THEN_valid_p(1))
   write_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(s00_wgnt)
     ,.v_i(write_complete)
     ,.ready_o(write_resp_ready_lo)

     ,.data_o(s00_wgnt_resp)
     ,.v_o(s00_wgnt_resp_v_lo)
     ,.yumi_i(s00_wgnt_resp_yumi_li)
     );
  assign m00_axil_awaddr = s01_wgnt ? s01_axil_awaddr_buffered : s00_axil_awaddr_buffered;
  assign m00_axil_awprot = s01_wgnt ? s01_axil_awprot_buffered : s00_axil_awprot_buffered;
  assign m00_axil_awvalid = ((s00_wgnt & s00_axil_awvalid_buffered) |
        (s01_wgnt & s01_axil_awvalid_buffered)) & ~awvalid_completed_r;
  assign s00_axil_awready_buffered = write_complete & s00_wgnt;
  assign s01_axil_awready_buffered = write_complete & s01_wgnt;

  assign m00_axil_wdata  = s01_wgnt ? s01_axil_wdata_buffered : s00_axil_wdata_buffered;
  assign m00_axil_wstrb  = s01_wgnt ? s01_axil_wstrb_buffered : s00_axil_wstrb_buffered;
  assign m00_axil_wvalid  = ((s00_wgnt & s00_axil_wvalid_buffered) |
        (s01_wgnt & s01_axil_wvalid_buffered)) & ~wvalid_completed_r;
  assign s00_axil_wready_buffered  = write_complete & s00_wgnt;
  assign s01_axil_wready_buffered  = write_complete & s01_wgnt;

  assign {s01_axil_bresp, s00_axil_bresp} = {2{m00_axil_bresp}};
  assign s00_axil_bvalid = s00_wgnt_resp_v_lo ?  (s00_wgnt_resp & m00_axil_bvalid) : 1'b0;
  assign s01_axil_bvalid = s00_wgnt_resp_v_lo ? (~s00_wgnt_resp & m00_axil_bvalid) : 1'b0;
  assign m00_axil_bready = s00_wgnt_resp_v_lo ? (s00_wgnt_resp ?
        s00_axil_bready : s01_axil_bready) : 1'b0;

// Read Channel
  logic s00_rgnt, s01_rgnt;
  logic read_resp_ready_lo;
  wire read_complete = m00_axil_arvalid & m00_axil_arready;

  bsg_round_robin_arb
   #(.inputs_p(2), .hold_on_valid_p(1))
   read_rr
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.grants_en_i(read_resp_ready_lo)
     ,.reqs_i({s00_axil_arvalid_buffered & read_resp_ready_lo,
               s01_axil_arvalid_buffered & read_resp_ready_lo})
     ,.grants_o({s00_rgnt, s01_rgnt})
     ,.sel_one_hot_o(/* UNUSED */)
     ,.v_o(/* UNUSED */)
     ,.tag_o(/* UNUSED */)
     ,.yumi_i(read_complete)
    );

  logic s00_rgnt_resp;
  logic s00_rgnt_resp_v_lo;
  wire s00_rgnt_resp_yumi_li = m00_axil_rvalid & m00_axil_rready;
  bsg_fifo_1r1w_small
   #(.width_p(1), .els_p(fifo_els_lp), .ready_THEN_valid_p(1))
   read_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(s00_rgnt)
     ,.v_i(read_complete)
     ,.ready_o(read_resp_ready_lo)

     ,.data_o(s00_rgnt_resp)
     ,.v_o(s00_rgnt_resp_v_lo)
     ,.yumi_i(s00_rgnt_resp_yumi_li)
     );

  assign m00_axil_araddr  = s01_rgnt ? s01_axil_araddr_buffered : s00_axil_araddr_buffered;
  assign m00_axil_arprot  = s01_rgnt ? s01_axil_arprot_buffered : s00_axil_arprot_buffered;
  assign m00_axil_arvalid = (s00_rgnt & s00_axil_arvalid_buffered) |
                            (s01_rgnt & s01_axil_arvalid_buffered);
  assign s00_axil_arready_buffered = s00_rgnt & m00_axil_arready;
  assign s01_axil_arready_buffered = s01_rgnt & m00_axil_arready;

  assign {s01_axil_rdata, s00_axil_rdata} = {2{m00_axil_rdata}};
  assign {s01_axil_rresp, s00_axil_rresp} = {2{m00_axil_rresp}};
  assign s00_axil_rvalid = s00_rgnt_resp_v_lo ?  (s00_rgnt_resp & m00_axil_rvalid) : 1'b0;
  assign s01_axil_rvalid = s00_rgnt_resp_v_lo ? (~s00_rgnt_resp & m00_axil_rvalid) : 1'b0;
  assign m00_axil_rready = s00_rgnt_resp_v_lo ? (s00_rgnt_resp ?
        s00_axil_rready : s01_axil_rready) : 1'b0;


endmodule

`BSG_ABSTRACT_MODULE(bsg_axil_mux)

