
`include "bsg_defines.sv"

module bsg_axil_uart_bridge
 #(parameter `BSG_INV_PARAM(uart_axil_data_width_p)
   , parameter `BSG_INV_PARAM(uart_axil_addr_width_p)
   , localparam uart_axil_mask_width_lp = uart_axil_data_width_p/8

   , parameter `BSG_INV_PARAM(ui_axil_data_width_p)
   , parameter `BSG_INV_PARAM(ui_axil_addr_width_p)
   , localparam ui_axil_mask_width_lp = ui_axil_data_width_p/8
   )
   (input                                        clk_i
    , (* mark_debug = "true" *) input                                      reset_i

    // WRITE ADDRESS CHANNEL SIGNALS
    , (* mark_debug = "true" *) output logic [uart_axil_addr_width_p-1:0]  uart_axil_awaddr_o
    , (* mark_debug = "true" *) output logic [2:0]                         uart_axil_awprot_o
    , (* mark_debug = "true" *) output logic                               uart_axil_awvalid_o
    , (* mark_debug = "true" *) input                                      uart_axil_awready_i

    // WRITE DATA CHANNEL SIGNALS
    , (* mark_debug = "true" *) output logic [uart_axil_data_width_p-1:0]  uart_axil_wdata_o
    , (* mark_debug = "true" *) output logic [uart_axil_mask_width_lp-1:0] uart_axil_wstrb_o
    , (* mark_debug = "true" *) output logic                               uart_axil_wvalid_o
    , (* mark_debug = "true" *) input                                      uart_axil_wready_i

    // WRITE RESPONSE CHANNEL SIGNALS
    , (* mark_debug = "true" *) input [1:0]                                uart_axil_bresp_i
    , (* mark_debug = "true" *) input                                      uart_axil_bvalid_i
    , (* mark_debug = "true" *) output logic                               uart_axil_bready_o

    // READ ADDRESS CHANNEL SIGNALS
    , (* mark_debug = "true" *) output logic [uart_axil_addr_width_p-1:0]  uart_axil_araddr_o
    , (* mark_debug = "true" *) output logic [2:0]                         uart_axil_arprot_o
    , (* mark_debug = "true" *) output logic                               uart_axil_arvalid_o
    , (* mark_debug = "true" *) input                                      uart_axil_arready_i

    // READ DATA CHANNEL SIGNALS
    , (* mark_debug = "true" *) input [uart_axil_data_width_p-1:0]         uart_axil_rdata_i
    , (* mark_debug = "true" *) input [1:0]                                uart_axil_rresp_i
    , (* mark_debug = "true" *) input                                      uart_axil_rvalid_i
    , (* mark_debug = "true" *) output logic                               uart_axil_rready_o

    , (* mark_debug = "true" *) input 									   uart_interrupt_i

    // WRITE ADDRESS CHANNEL SIGNALS
    ,  output logic [ui_axil_addr_width_p-1:0]    ui_axil_awaddr_o
    ,  output logic [2:0]                         ui_axil_awprot_o
    ,  output logic                               ui_axil_awvalid_o
    ,  input                                      ui_axil_awready_i

    // WRITE DATA CHANNEL SIGNALS
    ,  output logic [ui_axil_data_width_p-1:0]    ui_axil_wdata_o
    ,  output logic [ui_axil_mask_width_lp-1:0]   ui_axil_wstrb_o
    ,  output logic                               ui_axil_wvalid_o
    ,  input                                      ui_axil_wready_i

    // WRITE RESPONSE CHANNEL SIGNALS
    ,  input [1:0]                                ui_axil_bresp_i
    ,  input                                      ui_axil_bvalid_i
    ,  output logic                               ui_axil_bready_o

    // READ ADDRESS CHANNEL SIGNALS
    ,  output logic [ui_axil_addr_width_p-1:0]    ui_axil_araddr_o
    ,  output logic [2:0]                         ui_axil_arprot_o
    ,  output logic                               ui_axil_arvalid_o
    ,  input                                      ui_axil_arready_i

    // READ DATA CHANNEL SIGNALS
    ,  input [ui_axil_data_width_p-1:0]           ui_axil_rdata_i
    ,  input [1:0]                                ui_axil_rresp_i
    ,  input                                      ui_axil_rvalid_i
    ,  output logic                               ui_axil_rready_o
    );

//  typedef enum logic [3:0]
//  {e_reset,
//   e_sendret,
//   e_sendnew,
//   e_senda,
//   e_sendb,
//   e_sendc,
//   e_sendd } state_e;
//  (* mark_debug = "true" *) state_e state_n, state_r;
//
//  wire is_reset   = (state_r == e_reset);
//  wire is_sendret = (state_r == e_sendret);
//  wire is_sendnew = (state_r == e_sendnew);
//  wire is_senda   = (state_r == e_senda);
//  wire is_sendb   = (state_r == e_sendb);
//  wire is_sendc   = (state_r == e_sendc);
//  wire is_sendd   = (state_r == e_sendd);

  typedef enum logic [3:0]
  {e_reset
   ,e_ready
   ,e_poll_probe
   ,e_poll_check
   ,e_poll_send
   ,e_poll_recv
   ,e_req_send
   ,e_req_wait
   ,e_tx_probe
   ,e_tx_check
   ,e_tx_send
   ,e_tx_drain
   } state_e;
   
  (* mark_debug = "true" *) state_e state_n, state_r;
  wire is_ready      = (state_r == e_ready);
  wire is_poll_probe = (state_r == e_poll_probe);
  wire is_poll_check = (state_r == e_poll_check);
  wire is_poll_send  = (state_r == e_poll_send);
  wire is_poll_recv  = (state_r == e_poll_recv);
  wire is_req_send   = (state_r == e_req_send);
  wire is_req_wait   = (state_r == e_req_wait);
  wire is_tx_probe   = (state_r == e_tx_probe);
  wire is_tx_check   = (state_r == e_tx_check);
  wire is_tx_send    = (state_r == e_tx_send);
  wire is_tx_drain   = (state_r == e_tx_drain);

  // TODO: Can early exit on reads
  // MUST be sync-ed to C driver
  typedef struct packed
  {
    logic [31:0] data;
    logic [29:0] addr30to2;
    logic        wr_not_rd;
    logic        port;
  } bsg_uart_pkt_s;

  //
  // 0x0 RX
  // 0x4 TX
  // 0x8 STAT
  // 0xC CTRL
  //
  localparam rx_addr_lp   = 32'h0;
  localparam tx_addr_lp   = 32'h4;
  localparam stat_addr_lp = 32'h8;
  localparam ctrl_addr_lp = 32'hc;

  logic [uart_axil_data_width_p-1:0] m_wdata_li;
  logic [uart_axil_addr_width_p-1:0] m_addr_li;
  logic m_v_li, m_w_li, m_ready_and_lo;
  logic [uart_axil_mask_width_lp-1:0] m_wmask_li;
  logic [uart_axil_data_width_p-1:0] m_rdata_lo;
  logic m_v_lo, m_ready_and_li;
  bsg_axil_fifo_master
   #(.axil_data_width_p(uart_axil_data_width_p)
     ,.axil_addr_width_p(uart_axil_addr_width_p)
     ,.autoack_wr_p(1)
     )
   fifo_master
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(m_wdata_li)
     ,.addr_i(m_addr_li)
     ,.v_i(m_v_li)
     ,.w_i(m_w_li)
     ,.wmask_i(m_wmask_li)
     ,.ready_and_o(m_ready_and_lo)

     ,.data_o(m_rdata_lo)
     ,.v_o(m_v_lo)
     ,.ready_and_i(m_ready_and_li)

     ,.m_axil_awaddr_o(uart_axil_awaddr_o)
     ,.m_axil_awprot_o(uart_axil_awprot_o)
     ,.m_axil_awvalid_o(uart_axil_awvalid_o)
     ,.m_axil_awready_i(uart_axil_awready_i)

     ,.m_axil_wdata_o(uart_axil_wdata_o)
     ,.m_axil_wstrb_o(uart_axil_wstrb_o)
     ,.m_axil_wvalid_o(uart_axil_wvalid_o)
     ,.m_axil_wready_i(uart_axil_wready_i)

     ,.m_axil_bresp_i(uart_axil_bresp_i)
     ,.m_axil_bvalid_i(uart_axil_bvalid_i)
     ,.m_axil_bready_o(uart_axil_bready_o)

     ,.m_axil_araddr_o(uart_axil_araddr_o)
     ,.m_axil_arprot_o(uart_axil_arprot_o)
     ,.m_axil_arvalid_o(uart_axil_arvalid_o)
     ,.m_axil_arready_i(uart_axil_arready_i)

     ,.m_axil_rdata_i(uart_axil_rdata_i)
     ,.m_axil_rresp_i(uart_axil_rresp_i)
     ,.m_axil_rvalid_i(uart_axil_rvalid_i)
     ,.m_axil_rready_o(uart_axil_rready_o)
     );
  // uart status register
  wire rx_fifo_valid = m_rdata_lo[0];
  wire rx_fifo_full  = m_rdata_lo[1];
  wire tx_fifo_empty = m_rdata_lo[2];
  wire tx_fifo_full  = m_rdata_lo[3];

  bsg_uart_pkt_s uart_pkt_lo;
  logic uart_pkt_v_lo, uart_pkt_yumi_li;
  logic recv_ready_and_lo;
  logic [7:0] recv_data_li;
  logic recv_v_li;
  bsg_serial_in_parallel_out_full
   #(.width_p(8), .els_p($bits(bsg_uart_pkt_s)/8))
   rx_sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(recv_data_li)
     ,.v_i(recv_v_li)
     ,.ready_and_o(recv_ready_and_lo)

     ,.data_o(uart_pkt_lo)
     ,.v_o(uart_pkt_v_lo)
     ,.yumi_i(uart_pkt_yumi_li)
     );

  logic [ui_axil_data_width_p-1:0] gp0_wdata_li;
  logic [ui_axil_addr_width_p-1:0] gp0_addr_li;
  logic gp0_v_li, gp0_w_li, gp0_ready_and_lo;
  logic [ui_axil_mask_width_lp-1:0] gp0_wmask_li;

  logic [ui_axil_data_width_p-1:0] gp0_rdata_lo;
  logic gp0_v_lo, gp0_ready_and_li;
  bsg_axil_fifo_master
   #(.axil_data_width_p(ui_axil_data_width_p)
     ,.axil_addr_width_p(ui_axil_addr_width_p)
     ,.autoack_wr_p(1)
     )
   gp0_master
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(gp0_wdata_li)
     ,.addr_i(gp0_addr_li)
     ,.v_i(gp0_v_li)
     ,.w_i(gp0_w_li)
     ,.wmask_i(gp0_wmask_li)
     ,.ready_and_o(gp0_ready_and_lo)

     ,.data_o(gp0_rdata_lo)
     ,.v_o(gp0_v_lo)
     ,.ready_and_i(gp0_ready_and_li)

     ,.m_axil_awaddr_o(ui_axil_awaddr_o)
     ,.m_axil_awprot_o(ui_axil_awprot_o)
     ,.m_axil_awvalid_o(ui_axil_awvalid_o)
     ,.m_axil_awready_i(ui_axil_awready_i)

     ,.m_axil_wdata_o(ui_axil_wdata_o)
     ,.m_axil_wstrb_o(ui_axil_wstrb_o)
     ,.m_axil_wvalid_o(ui_axil_wvalid_o)
     ,.m_axil_wready_i(ui_axil_wready_i)

     ,.m_axil_bresp_i(ui_axil_bresp_i)
     ,.m_axil_bvalid_i(ui_axil_bvalid_i)
     ,.m_axil_bready_o(ui_axil_bready_o)

     ,.m_axil_araddr_o(ui_axil_araddr_o)
     ,.m_axil_arprot_o(ui_axil_arprot_o)
     ,.m_axil_arvalid_o(ui_axil_arvalid_o)
     ,.m_axil_arready_i(ui_axil_arready_i)

     ,.m_axil_rdata_i(ui_axil_rdata_i)
     ,.m_axil_rresp_i(ui_axil_rresp_i)
     ,.m_axil_rvalid_i(ui_axil_rvalid_i)
     ,.m_axil_rready_o(ui_axil_rready_o)
     );

  logic [ui_axil_data_width_p-1:0] uart_data_li;
  logic uart_v_li, uart_ready_and_lo;
  logic [7:0] tx_data_lo;
  logic tx_v_lo, tx_yumi_li;
  bsg_parallel_in_serial_out
   #(.width_p(8), .els_p(ui_axil_data_width_p/8))
   tx_piso
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(uart_data_li)
     ,.valid_i(uart_v_li)
     ,.ready_and_o(uart_ready_and_lo)

     ,.data_o(tx_data_lo)
     ,.valid_o(tx_v_lo)
     ,.yumi_i(tx_yumi_li)
     );

  // TODO: make poll_state, send_state, recv_state ??
  // This could certainly be more efficient by leveraging bursty transfer patterns
  always_comb
    begin
      m_wdata_li = '0;
      m_addr_li = '0;
      m_v_li = '0;
      m_w_li = '0;
      m_wmask_li = '1;
       
      m_ready_and_li = 1'b0;
      
      recv_data_li = '0;
      recv_v_li = 1'b0;
      uart_pkt_yumi_li = 1'b0;

      uart_data_li = '0;
      uart_v_li = 1'b0;
      tx_yumi_li = 1'b0;

      // default GP0 (UI) master signals to avoid inferred latches
      gp0_wdata_li = '0;
      gp0_addr_li  = '0;
      gp0_v_li     = 1'b0;
      gp0_w_li     = 1'b0;
      gp0_wmask_li = '1;
      gp0_ready_and_li = 1'b0;

      state_n = state_r;

      case (state_r)
        e_reset:
          begin
			state_n = e_poll_probe;
          end
 		e_poll_probe:
          begin
            // If we have a uart wr/rd packet, send it, else poll the rx fifo
            //m_v_li = ~uart_pkt_v_lo;
            m_v_li = 1'b0;
            m_w_li = 1'b0;
            m_addr_li = uart_axil_addr_width_p'(stat_addr_lp);

            state_n = uart_pkt_v_lo
                      ? e_req_send
                      : (m_ready_and_lo & m_v_li)
                        ? e_poll_check
                        : state_r;
          end
       e_poll_check:
		  begin
            m_ready_and_li = 1'b1;

            state_n = (m_ready_and_li & m_v_lo) ? rx_fifo_valid ? e_poll_send : e_poll_probe : state_r;
		  end
	   e_poll_send:
		  begin
            m_v_li = 1'b1;
            m_w_li = 1'b0;
            m_addr_li = uart_axil_addr_width_p'(rx_addr_lp);

            state_n = (m_ready_and_lo & m_v_li) ? e_poll_recv : state_r;
		  end
	   e_poll_recv:
		  begin

		  end
        default: begin end
      endcase
  end

//  // This could certainly be more efficient by leveraging bursty transfer patterns
//  always_comb
//    begin
//      m_wdata_li = '0;
//      m_addr_li = '0;
//      m_v_li = '0;
//      m_w_li = '0;
//      m_wmask_li = '1;
//       
//      m_ready_and_li = 1'b0;
//      
//      recv_data_li = '0;
//      recv_v_li = 1'b0;
//      uart_pkt_yumi_li = 1'b0;
//
//      uart_data_li = '0;
//      uart_v_li = 1'b0;
//      tx_yumi_li = 1'b0;
//
//      // default GP0 (UI) master signals to avoid inferred latches
//      gp0_wdata_li = '0;
//      gp0_addr_li  = '0;
//      gp0_v_li     = 1'b0;
//      gp0_w_li     = 1'b0;
//      gp0_wmask_li = '1;
//      gp0_ready_and_li = 1'b0;
//
//      state_n = state_r;
//
//      case (state_r)
//        e_reset:
//          begin
//            state_n = e_poll_probe;
//          end
//        e_poll_probe:
//          begin
//            // If we have a uart wr/rd packet, send it, else poll the rx fifo
//            m_v_li = ~uart_pkt_v_lo;
//            m_w_li = 1'b0;
//            m_addr_li = stat_addr_lp;
//
//            state_n = uart_pkt_v_lo
//                      ? e_req_send
//                      : (m_ready_and_lo & m_v_li)
//                        ? e_poll_check
//                        : state_r;
//          end
//        e_poll_check:
//          begin
//            m_ready_and_li = 1'b1;
//
//            state_n = (m_ready_and_li & m_v_lo) ? rx_fifo_valid ? e_poll_send : e_poll_probe : state_r;
//          end
//        e_poll_send:
//          begin
//            m_v_li = 1'b1;
//            m_w_li = 1'b0;
//            m_addr_li = rx_addr_lp;
//
//            state_n = (m_ready_and_lo & m_v_li) ? e_poll_recv : state_r;
//          end
//        e_poll_recv:
//          begin
//            recv_data_li = m_rdata_lo;
//            recv_v_li = m_v_lo;
//            m_ready_and_li = recv_ready_and_lo;
//
//            state_n = (m_ready_and_li & m_v_lo) ? e_poll_probe : state_r;
//          end
//        e_req_send:
//          begin
//            gp0_wdata_li = uart_pkt_lo.data;
//            gp0_addr_li = (uart_pkt_lo.addr30to2 << 2'b10);
//            gp0_v_li = uart_pkt_v_lo;
//            gp0_w_li = uart_pkt_lo.wr_not_rd;
//            uart_pkt_yumi_li = gp0_ready_and_lo & gp0_v_li;
//
//            state_n = uart_pkt_yumi_li ? gp0_w_li ? e_poll_probe : e_req_wait : state_r;
//          end
//        e_req_wait:
//          begin
//            uart_v_li = gp0_v_lo;
//            uart_data_li = gp0_rdata_lo;
//            gp0_ready_and_li = uart_ready_and_lo;
//
//            state_n = (gp0_ready_and_li & gp0_v_lo) ? e_tx_probe : state_r;
//          end
//        e_tx_probe:
//          begin
//            m_v_li = 1'b1;
//            m_w_li = 1'b0;
//            m_addr_li = stat_addr_lp;
//
//            state_n = (m_ready_and_lo & m_v_li) ? e_tx_check : state_r;
//          end
//        e_tx_check:
//          begin
//            m_ready_and_li = 1'b1;
//
//            state_n = (m_ready_and_li & m_v_lo) ? tx_fifo_empty ? e_tx_send : e_tx_probe : state_r;
//            end
//        e_tx_send:
//          begin
//            m_v_li = tx_v_lo;
//            m_w_li = 1'b1;
//            m_addr_li = tx_addr_lp;
//            m_wdata_li = tx_data_lo;
//            tx_yumi_li = m_v_li & m_ready_and_lo;
//
//            state_n = ~tx_v_lo ? e_poll_probe : state_r;
//          end
//        e_tx_send:
//          begin
//            m_v_li = tx_v_lo;
//            m_w_li = 1'b1;
//            m_addr_li = tx_addr_lp;
//            m_wdata_li = tx_data_lo;
//            tx_yumi_li = m_ready_and_lo & m_v_li;
//
//            state_n = tx_yumi_li ? e_tx_drain : state_r;
//
//        default: begin end
//      endcase
//    end
//
//  always_comb
//    begin
//      m_wdata_li = '0;
//      m_addr_li = '0;
//      m_v_li = '0;
//      m_w_li = '0;
//      m_wmask_li = '1;
//      m_ready_and_li = '0;
//
//      recv_data_li = '0;
//      recv_v_li = '0;
//      uart_pkt_yumi_li = '0;
//
//      gp0_wdata_li = '0;
//      gp0_addr_li = '0;
//      gp0_v_li = '0;
//      gp0_w_li = '0;
//      gp0_wmask_li = '1;
//      gp0_ready_and_li = '0;
//
//      uart_data_li = '0;
//      uart_v_li = '0;
//      tx_yumi_li = '0;
//
//      case (state_r)
//        // If we have a uart wr/rd packet, send it, else poll the rx fifo
//        e_ready:
//          begin
//            m_v_li = ~uart_pkt_v_lo;
//            m_addr_li = stat_addr_lp;
//
//            state_n = uart_pkt_v_lo
//                      ? e_req_send
//                      : (m_ready_and_lo & m_v_li)
//                        ? e_poll_check
//                        : state_r;
//          end
//        // Check if RX is has byte
//        e_poll_check:
//          begin
//            m_ready_and_li = 1'b1;
//
//            state_n = (m_ready_and_li & m_v_lo) ? m_rdata_lo[0] ? e_poll_send : e_ready : state_r;
//          end
//        // Query the RX byte
//        e_poll_send:
//          begin
//            m_v_li = 1'b1;
//            m_addr_li = rx_addr_lp;
//            
//            state_n = (m_ready_and_lo & m_v_li) ? e_poll_recv : state_r;
//          end
//        // Grab the byte
//        e_poll_recv:
//          begin
//            recv_data_li = m_rdata_lo;
//            recv_v_li = m_v_lo;
//            m_ready_and_li = recv_ready_and_lo;
//
//            state_n = (m_ready_and_li & m_v_lo) ? e_ready : state_r;
//          end
//        // Send a GP0 req
//        e_req_send:
//          begin
//            gp0_wdata_li = uart_pkt_lo.data;
//            gp0_addr_li = (uart_pkt_lo.addr30to2 << 2'b10);
//            gp0_v_li = uart_pkt_v_lo;
//            gp0_w_li = uart_pkt_lo.wr_not_rd;
//
//            state_n = (gp0_ready_and_lo & gp0_v_li) ? e_req_wait : state_r;
//          end
//        // Recv a GP0 response
//        e_req_wait:
//          begin
//            uart_v_li = gp0_v_lo & !uart_pkt_lo.wr_not_rd;
//            uart_data_li = gp0_rdata_lo;
//            gp0_ready_and_li = (uart_pkt_lo.wr_not_rd | uart_ready_and_lo);
//            uart_pkt_yumi_li = gp0_ready_and_li & gp0_v_lo;
//
//            state_n = uart_pkt_yumi_li ? !uart_pkt_lo.wr_not_rd ? e_tx_send : e_ready : state_r;
//          end
//        // Transmit read response (assume TX fifo is drained fast enough for now...)
//        e_tx_send:
//          begin
//            m_v_li = tx_v_lo;
//            m_w_li = 1'b1;
//            m_addr_li = tx_addr_lp;
//            m_wdata_li = tx_data_lo;
//            tx_yumi_li = m_ready_and_lo & m_v_li;
//
//            state_n = tx_yumi_li ? e_tx_drain : state_r;
//          end
//        e_tx_drain:
//          begin
//            m_ready_and_li = 1'b1;
//
//            state_n = (m_ready_and_li & m_v_lo) ? ~tx_v_lo ? e_ready : e_tx_send : state_r;
//          end
//        default: state_n = e_ready;
//      endcase
//    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
        state_r <= e_reset;
    else 
      state_r <= state_n;

endmodule

