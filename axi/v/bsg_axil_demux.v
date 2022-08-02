
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

  localparam fifo_els_lp = 2;

  logic write_resp_fifo_ready_lo;
  logic write_resp_m00_select;
  logic write_resp_fifo_v_lo;
  logic write_resp_fifo_yumi_li;

  logic read_resp_fifo_v_li;
  logic read_resp_fifo_ready_lo;
  logic read_resp_m00_select;
  logic read_resp_fifo_v_lo;
  logic read_resp_fifo_yumi_li;

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

  bsg_fifo_1r1w_small
   #(.width_p(addr_width_p+3), .els_p(fifo_els_lp))
   input_awaddr_fifo
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
   input_wdata_fifo
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
   input_araddr_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({s00_axil_araddr, s00_axil_arprot})
     ,.v_i(s00_axil_arvalid)
     ,.ready_o(s00_axil_arready)

     ,.data_o({s00_axil_araddr_buffered, s00_axil_arprot_buffered})
     ,.v_o(s00_axil_arvalid_buffered)
     ,.yumi_i(s00_axil_arvalid_buffered & s00_axil_arready_buffered)
     );


  wire write_m00_select = s00_axil_awaddr_buffered < split_addr_p;
  assign {m01_axil_awaddr, m00_axil_awaddr} = {2{s00_axil_awaddr_buffered}};
  assign {m01_axil_awprot, m00_axil_awprot} = {2{s00_axil_awprot_buffered}};
  assign {m01_axil_wdata, m00_axil_wdata} = {2{s00_axil_wdata_buffered}};
  assign {m01_axil_wstrb, m00_axil_wstrb} = {2{s00_axil_wstrb_buffered}};

  wire read_m00_select = s00_axil_araddr_buffered < split_addr_p;
  assign {m01_axil_araddr, m00_axil_araddr} = {2{s00_axil_araddr_buffered}};
  assign {m01_axil_arprot, m00_axil_arprot} = {2{s00_axil_arprot_buffered}};
  assign m00_axil_arvalid = read_resp_fifo_ready_lo &
        (read_m00_select & s00_axil_arvalid_buffered);
  assign m01_axil_arvalid = read_resp_fifo_ready_lo &
        (~read_m00_select & s00_axil_arvalid_buffered);
  assign s00_axil_arready_buffered = read_resp_fifo_ready_lo &
                (read_m00_select ? m00_axil_arready : m01_axil_arready);

  /////////////////////////////////////////////////////////////////////////////
  //   "wvalid_completed_r", "awvalid_completed_r" track the corresponding
  // completed handshaking, so that waddr and wdata channels can have separate
  // handshaking. If both waddr and wdata handshakings will be completed in
  // next cycle, both of them will be clear. This implies that the two
  // *completed_r signals will never be held high at the same time.

  logic wvalid_completed_n, awvalid_completed_n;
  logic wvalid_completed_r, awvalid_completed_r;
  logic next_write_req;

  bsg_dff_reset
   #(.width_p(2))
   write_valid_completed_regs
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({wvalid_completed_n, awvalid_completed_n})
     ,.data_o({wvalid_completed_r, awvalid_completed_r})
     );

  wire axil_awvalid = write_m00_select ? m00_axil_awvalid : m01_axil_awvalid;
  wire axil_awready = s00_axil_awvalid_buffered & (write_m00_select ? m00_axil_awready : m01_axil_awready);
  wire axil_wvalid  = write_m00_select ? m00_axil_wvalid : m01_axil_wvalid;
  wire axil_wready  = s00_axil_awvalid_buffered & (write_m00_select ? m00_axil_wready : m01_axil_wready);

  always_comb begin
    wvalid_completed_n  = wvalid_completed_r;
    awvalid_completed_n = awvalid_completed_r;
    if(next_write_req) begin
      wvalid_completed_n  = 1'b0;
      awvalid_completed_n = 1'b0;
    end
    else begin
      if(axil_awvalid & axil_awready)
        awvalid_completed_n = 1'b1;
      if(axil_wvalid & axil_wready)
        wvalid_completed_n = 1'b1;
    end
  end

  assign next_write_req = (((axil_awvalid & axil_awready) | awvalid_completed_r) &
    ((axil_wvalid & axil_wready) | wvalid_completed_r)) & write_resp_fifo_ready_lo;


  assign m00_axil_awvalid =  write_m00_select & s00_axil_awvalid_buffered &
        ~awvalid_completed_r;
  assign m01_axil_awvalid = ~write_m00_select & s00_axil_awvalid_buffered &
        ~awvalid_completed_r;

  assign m00_axil_wvalid =  write_m00_select & s00_axil_awvalid_buffered &
        s00_axil_wvalid_buffered & ~wvalid_completed_r;
  assign m01_axil_wvalid = ~write_m00_select & s00_axil_awvalid_buffered &
        s00_axil_wvalid_buffered & ~wvalid_completed_r;

  assign s00_axil_awready_buffered = next_write_req;
  assign s00_axil_wready_buffered  = next_write_req;


  bsg_fifo_1r1w_small
   #(.width_p(1), .els_p(fifo_els_lp), .ready_THEN_valid_p(1))
   write_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(write_m00_select)
     ,.v_i(next_write_req)
     ,.ready_o(write_resp_fifo_ready_lo)

     ,.data_o(write_resp_m00_select)
     ,.v_o(write_resp_fifo_v_lo)
     ,.yumi_i(write_resp_fifo_yumi_li)
     );
  assign write_resp_fifo_yumi_li = s00_axil_bvalid & s00_axil_bready;

  bsg_fifo_1r1w_small
   #(.width_p(1), .els_p(fifo_els_lp), .ready_THEN_valid_p(1))
   read_resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(read_m00_select)
     ,.v_i(read_resp_fifo_v_li)
     ,.ready_o(read_resp_fifo_ready_lo)

     ,.data_o(read_resp_m00_select)
     ,.v_o(read_resp_fifo_v_lo)
     ,.yumi_i(read_resp_fifo_yumi_li)
     );

  assign read_resp_fifo_v_li = s00_axil_arvalid_buffered & s00_axil_arready_buffered;
  assign read_resp_fifo_yumi_li = s00_axil_rvalid & s00_axil_rready;

  assign s00_axil_bresp  = write_resp_m00_select ? m00_axil_bresp : m01_axil_bresp;
  assign s00_axil_bvalid = write_resp_fifo_v_lo &
        (write_resp_m00_select ? m00_axil_bvalid : m01_axil_bvalid);
  assign m00_axil_bready = write_resp_fifo_v_lo &
        (write_resp_m00_select & s00_axil_bready);
  assign m01_axil_bready = write_resp_fifo_v_lo &
        (~write_resp_m00_select & s00_axil_bready);


  assign s00_axil_rdata = read_resp_m00_select ? m00_axil_rdata : m01_axil_rdata;
  assign s00_axil_rresp = read_resp_m00_select ? m00_axil_rresp : m01_axil_rresp;
  assign s00_axil_rvalid = read_resp_fifo_v_lo &
        (read_resp_m00_select ? m00_axil_rvalid : m01_axil_rvalid);
  assign m00_axil_rready = read_resp_fifo_v_lo &  read_resp_m00_select & s00_axil_rready;
  assign m01_axil_rready = read_resp_fifo_v_lo & ~read_resp_m00_select & s00_axil_rready;

endmodule

`BSG_ABSTRACT_MODULE(bsg_axil_demux)
