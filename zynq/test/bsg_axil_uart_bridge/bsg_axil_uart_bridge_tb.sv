`include "bsg_defines.sv"

module bsg_axil_uart_bridge_tb
  import bsg_axi_pkg::*;
  #(parameter uart_axil_data_width_p = 32
    , parameter uart_axil_addr_width_p = 32
    , parameter ui_axil_data_width_p = 32
    , parameter ui_axil_addr_width_p = 32

    , parameter mem_els_p = 128
    , parameter mem_addr_width_lp = `BSG_SAFE_CLOG2(mem_els_p)

    , localparam uart_axil_mask_width_lp = uart_axil_data_width_p/8
    , localparam ui_axil_mask_width_lp = ui_axil_data_width_p/8
    );

  // Clock and reset
  logic clk;
  logic reset;

  // ==================================================
  // UART AXIL Interface (DUT as Master)
  // ==================================================
  logic [uart_axil_addr_width_p-1:0]  uart_axil_awaddr;
  logic [2:0]                         uart_axil_awprot;
  logic                               uart_axil_awvalid;
  logic                               uart_axil_awready;

  logic [uart_axil_data_width_p-1:0]  uart_axil_wdata;
  logic [uart_axil_mask_width_lp-1:0] uart_axil_wstrb;
  logic                               uart_axil_wvalid;
  logic                               uart_axil_wready;

  logic [1:0]                         uart_axil_bresp;
  logic                               uart_axil_bvalid;
  logic                               uart_axil_bready;

  logic [uart_axil_addr_width_p-1:0]  uart_axil_araddr;
  logic [2:0]                         uart_axil_arprot;
  logic                               uart_axil_arvalid;
  logic                               uart_axil_arready;

  logic [uart_axil_data_width_p-1:0]  uart_axil_rdata;
  logic [1:0]                         uart_axil_rresp;
  logic                               uart_axil_rvalid;
  logic                               uart_axil_rready;

  // ==================================================
  // UI AXIL Interface (DUT as Master)
  // ==================================================
  logic [ui_axil_addr_width_p-1:0]    ui_axil_awaddr;
  logic [2:0]                         ui_axil_awprot;
  logic                               ui_axil_awvalid;
  logic                               ui_axil_awready;

  logic [ui_axil_data_width_p-1:0]    ui_axil_wdata;
  logic [ui_axil_mask_width_lp-1:0]   ui_axil_wstrb;
  logic                               ui_axil_wvalid;
  logic                               ui_axil_wready;

  logic [1:0]                         ui_axil_bresp;
  logic                               ui_axil_bvalid;
  logic                               ui_axil_bready;

  logic [ui_axil_addr_width_p-1:0]    ui_axil_araddr;
  logic [2:0]                         ui_axil_arprot;
  logic                               ui_axil_arvalid;
  logic                               ui_axil_arready;

  logic [ui_axil_data_width_p-1:0]    ui_axil_rdata;
  logic [1:0]                         ui_axil_rresp;
  logic                               ui_axil_rvalid;
  logic                               ui_axil_rready;

  // ==================================================
  // DUT Instantiation
  // ==================================================
  bsg_axil_uart_bridge
    #(.uart_axil_data_width_p(uart_axil_data_width_p)
      ,.uart_axil_addr_width_p(uart_axil_addr_width_p)
      ,.ui_axil_data_width_p(ui_axil_data_width_p)
      ,.ui_axil_addr_width_p(ui_axil_addr_width_p)
      )
    dut
      (.clk_i(clk)
       ,.reset_i(reset)

       // UART AXIL Interface
       ,.uart_axil_awaddr_o(uart_axil_awaddr)
       ,.uart_axil_awprot_o(uart_axil_awprot)
       ,.uart_axil_awvalid_o(uart_axil_awvalid)
       ,.uart_axil_awready_i(uart_axil_awready)

       ,.uart_axil_wdata_o(uart_axil_wdata)
       ,.uart_axil_wstrb_o(uart_axil_wstrb)
       ,.uart_axil_wvalid_o(uart_axil_wvalid)
       ,.uart_axil_wready_i(uart_axil_wready)

       ,.uart_axil_bresp_i(uart_axil_bresp)
       ,.uart_axil_bvalid_i(uart_axil_bvalid)
       ,.uart_axil_bready_o(uart_axil_bready)

       ,.uart_axil_araddr_o(uart_axil_araddr)
       ,.uart_axil_arprot_o(uart_axil_arprot)
       ,.uart_axil_arvalid_o(uart_axil_arvalid)
       ,.uart_axil_arready_i(uart_axil_arready)

       ,.uart_axil_rdata_i(uart_axil_rdata)
       ,.uart_axil_rresp_i(uart_axil_rresp)
       ,.uart_axil_rvalid_i(uart_axil_rvalid)
       ,.uart_axil_rready_o(uart_axil_rready)

       // UI AXIL Interface
       ,.ui_axil_awaddr_o(ui_axil_awaddr)
       ,.ui_axil_awprot_o(ui_axil_awprot)
       ,.ui_axil_awvalid_o(ui_axil_awvalid)
       ,.ui_axil_awready_i(ui_axil_awready)

       ,.ui_axil_wdata_o(ui_axil_wdata)
       ,.ui_axil_wstrb_o(ui_axil_wstrb)
       ,.ui_axil_wvalid_o(ui_axil_wvalid)
       ,.ui_axil_wready_i(ui_axil_wready)

       ,.ui_axil_bresp_i(ui_axil_bresp)
       ,.ui_axil_bvalid_i(ui_axil_bvalid)
       ,.ui_axil_bready_o(ui_axil_bready)

       ,.ui_axil_araddr_o(ui_axil_araddr)
       ,.ui_axil_arprot_o(ui_axil_arprot)
       ,.ui_axil_arvalid_o(ui_axil_arvalid)
       ,.ui_axil_arready_i(ui_axil_arready)

       ,.ui_axil_rdata_i(ui_axil_rdata)
       ,.ui_axil_rresp_i(ui_axil_rresp)
       ,.ui_axil_rvalid_i(ui_axil_rvalid)
       ,.ui_axil_rready_o(ui_axil_rready)
       );

  // ==================================================
  // GP0 Backend: bsg_axil_fifo_client + bsg_mem_1rw
  // ==================================================
  logic [ui_axil_data_width_p-1:0] gp0_wdata;
  logic [ui_axil_addr_width_p-1:0] gp0_addr;
  logic gp0_v;
  logic gp0_w;
  logic [ui_axil_mask_width_lp-1:0] gp0_wmask;
  logic gp0_ready_and;

  logic [ui_axil_data_width_p-1:0] gp0_rdata;
  logic gp0_v_read;
  logic gp0_ready_and_read;

  // AXIL FIFO Client - bridges from AXI-Lite to simplified interface
  bsg_axil_fifo_client
    #(.axil_data_width_p(ui_axil_data_width_p)
      ,.axil_addr_width_p(ui_axil_addr_width_p)
      )
    gp0_client
      (.clk_i(clk)
       ,.reset_i(reset)

       // Simplified interface
       ,.data_o(gp0_wdata)
       ,.addr_o(gp0_addr)
       ,.v_o(gp0_v)
       ,.w_o(gp0_w)
       ,.wmask_o(gp0_wmask)
       ,.ready_and_i(gp0_ready_and)

       ,.data_i(gp0_rdata)
       ,.v_i(gp0_v_read)
       ,.ready_and_o(gp0_ready_and_read)

       // AXI-Lite interface
       ,.s_axil_awaddr_i(ui_axil_awaddr)
       ,.s_axil_awprot_i(ui_axil_awprot)
       ,.s_axil_awvalid_i(ui_axil_awvalid)
       ,.s_axil_awready_o(ui_axil_awready)

       ,.s_axil_wdata_i(ui_axil_wdata)
       ,.s_axil_wstrb_i(ui_axil_wstrb)
       ,.s_axil_wvalid_i(ui_axil_wvalid)
       ,.s_axil_wready_o(ui_axil_wready)

       ,.s_axil_bresp_o(ui_axil_bresp)
       ,.s_axil_bvalid_o(ui_axil_bvalid)
       ,.s_axil_bready_i(ui_axil_bready)

       ,.s_axil_araddr_i(ui_axil_araddr)
       ,.s_axil_arprot_i(ui_axil_arprot)
       ,.s_axil_arvalid_i(ui_axil_arvalid)
       ,.s_axil_arready_o(ui_axil_arready)

       ,.s_axil_rdata_o(ui_axil_rdata)
       ,.s_axil_rresp_o(ui_axil_rresp)
       ,.s_axil_rvalid_o(ui_axil_rvalid)
       ,.s_axil_rready_i(ui_axil_rready)
       );

  // Memory backend
  logic [mem_addr_width_lp-1:0] mem_addr;
  logic [ui_axil_data_width_p-1:0] mem_read_data;
  
  assign mem_addr = gp0_addr[mem_addr_width_lp-1:0];

  bsg_mem_1rw_sync
    #(.width_p(ui_axil_data_width_p)
      ,.els_p(mem_els_p)
      )
    memory
      (.clk_i(clk)
       ,.reset_i(reset)
       ,.data_i(gp0_wdata)
       ,.addr_i(mem_addr)
       ,.v_i(gp0_v)
       ,.w_i(gp0_w)
       ,.data_o(mem_read_data)
       );

  // Read data path
  logic gp0_read_valid_r;
  logic [ui_axil_data_width_p-1:0] gp0_read_data_r;

  always_ff @(posedge clk) begin
    if (reset) begin
      gp0_read_valid_r <= 1'b0;
      gp0_read_data_r <= '0;
    end else begin
      gp0_read_valid_r <= gp0_v & ~gp0_w;
      gp0_read_data_r <= mem_read_data;
    end
  end

  assign gp0_rdata = gp0_read_data_r;
  assign gp0_v_read = gp0_read_valid_r;
  
  // Write path ready signal
  assign gp0_ready_and = 1'b1;

  // ==================================================
  // UART RX Queue (simulating 16550-style UART device)
  // ==================================================
  logic [7:0] uart_rx_queue [0:255];  // Fixed-size queue
  int uart_rx_queue_head;
  int uart_rx_queue_tail;
  
  logic [7:0] uart_rx_fifo_data;
  logic uart_rx_fifo_valid;

  // ==================================================
  // UART AXIL Responder (returns status/data from UART)
  // ==================================================
  enum logic [1:0] { WAIT_ADDR, SEND_DATA } uart_resp_state;

  logic [31:0] uart_status_reg;

  // UART status bits
  localparam [31:0] RX_FIFO_VALID = 1 << 0;
  localparam [31:0] RX_FIFO_FULL  = 1 << 1;
  localparam [31:0] TX_FIFO_EMPTY = 1 << 2;
  localparam [31:0] TX_FIFO_FULL  = 1 << 3;

  // UART control register (stores incoming data before sending to GP0)
  logic [31:0] uart_data_reg;
  logic uart_rx_fifo_has_data;
  logic [8:0] uart_rx_byte_counter;

  // UART request packet structure (32-bit data + 30-bit addr + write bit + port bit = 64 bits total)
  // We'll store this in the fifo

  // Track if we have a complete UART packet
  logic uart_pkt_ready;
  logic [31:0] uart_pkt_data;
  logic [31:0] uart_pkt_addr;
  logic uart_pkt_is_write;

  // ==================================================
  // Clock generation
  // ==================================================
  localparam cycle_time_lp = 10;

  always begin
    clk = 1'b0;
    #(cycle_time_lp/2);
    clk = 1'b1;
    #(cycle_time_lp/2);
  end

  // ==================================================
  // Test Stimulus
  // ==================================================
  initial begin
    reset = 1'b1;
    uart_axil_awready = 1'b1;
    uart_axil_wready = 1'b1;
    uart_axil_arready = 1'b1;
    uart_axil_rdata = '0;
    uart_axil_rvalid = 1'b0;
    uart_axil_bvalid = 1'b0;
    uart_axil_bresp = e_axi_resp_okay;
    uart_axil_rresp = e_axi_resp_okay;

    repeat(5) @(posedge clk);
    reset = 1'b0;
    repeat(5) @(posedge clk);

    $display("========================================");
    $display("Starting bsg_axil_uart_bridge Test");
    $display("========================================");

    // Test 1: Write to memory at address 0x00 with data 0xDEADBEEF
    $display("\n[TEST 1] Write 0xDEADBEEF to address 0x00");
    test_uart_write(32'h00000000, 32'hDEADBEEF);
    repeat(100) @(posedge clk);

    // Test 2: Read from address 0x00 (should get 0xDEADBEEF back)
    $display("\n[TEST 2] Read from address 0x00");
    test_uart_read(32'h00000000);
    repeat(100) @(posedge clk);

    // Test 3: Write to address 0x04 with data 0xCAFEBABE
    $display("\n[TEST 3] Write 0xCAFEBABE to address 0x04");
    test_uart_write(32'h00000004, 32'hCAFEBABE);
    repeat(100) @(posedge clk);

    // Test 4: Read from address 0x04
    $display("\n[TEST 4] Read from address 0x04");
    test_uart_read(32'h00000004);
    repeat(100) @(posedge clk);

    // Test 5: Write to address 0x10 with data 0x12345678
    $display("\n[TEST 5] Write 0x12345678 to address 0x10");
    test_uart_write(32'h00000010, 32'h12345678);
    repeat(100) @(posedge clk);

    // Test 6: Read back address 0x00 again (verify persistence)
    $display("\n[TEST 6] Read from address 0x00 (verify)");
    test_uart_read(32'h00000000);
    repeat(100) @(posedge clk);

    $display("\n========================================");
    $display("All tests completed!");
    $display("========================================\n");
    $finish;
  end

  // ==================================================
  // Helper task: UART Write
  // ==================================================
  task test_uart_write(input logic [31:0] addr, input logic [31:0] data);
    logic [63:0] packet;
    
    // Packet format: [data(31:0)][addr(29:0)][wr_not_rd(1)][port(1)]
    packet = {data[31:0], addr[29:0], 1'b1, 1'b0}; // write=1, port=0
    
    queue_uart_packet(packet);
    $display("  Written 0x%08h to address 0x%08h", data, addr);
  endtask

  // ==================================================
  // Helper task: UART Read
  // ==================================================
  task test_uart_read(input logic [31:0] addr);
    logic [63:0] packet;
    
    // Packet format: [data(31:0)][addr(29:0)][wr_not_rd(0)][port(1)]
    packet = {32'h00000000, addr[29:0], 1'b0, 1'b0}; // write=0, port=0
    
    queue_uart_packet(packet);
    $display("  Read from address 0x%08h", addr);
  endtask

  // ==================================================
  // Helper task: Queue UART Packet for RX
  // ==================================================
  task queue_uart_packet(input logic [63:0] packet);
    int byte_idx;
    
    // Queue 8 bytes (64 bits total, little-endian)
    for (byte_idx = 0; byte_idx < 8; byte_idx++) begin
      uart_rx_queue[uart_rx_queue_tail] = packet[byte_idx*8 +: 8];
      $display("    Queued UART byte[%d]: 0x%02h", byte_idx, packet[byte_idx*8 +: 8]);
      uart_rx_queue_tail = (uart_rx_queue_tail + 1) % 256;
    end
  endtask

  // ==================================================
  // Simulated 16550-style UART Device
  // ==================================================

  // Update RX FIFO valid bit based on queue
  always_comb begin
    uart_rx_fifo_valid = (uart_rx_queue_head != uart_rx_queue_tail);
    uart_rx_fifo_data = uart_rx_queue[uart_rx_queue_head];
  end

  // UART AXIL Read/Write Handler
  always @(posedge clk) begin
    if (reset) begin
      uart_axil_rvalid <= 1'b0;
      uart_axil_bvalid <= 1'b0;
    end else begin
      
      // Handle read requests on UART AXIL
      if (uart_axil_arvalid && uart_axil_arready) begin
        case (uart_axil_araddr[3:0])
          4'h0: begin  // RX register (0x0)
            // Return next byte from RX queue
            uart_axil_rdata <= {24'h000000, uart_rx_fifo_data};
            if (uart_rx_fifo_valid) begin
              uart_rx_queue_head = (uart_rx_queue_head + 1) % 256;
              $display("    [UART RX READ] 0x%02h", uart_rx_fifo_data);
            end
          end
          4'h4: begin  // TX register (0x4)
            uart_axil_rdata <= 32'h00;
          end
          4'h8: begin  // STAT register (0x8)
            // Build status register
            uart_status_reg <= {28'h0, 
                                1'b0,   // bit 3: TX FIFO full (always 0)
                                1'b1,   // bit 2: TX FIFO empty (always 1)
                                1'b0,   // bit 1: RX FIFO full (0 for now)
                                uart_rx_fifo_valid}; // bit 0: RX FIFO valid
            uart_axil_rdata <= uart_status_reg;
            $display("    [UART STAT READ] RX_VALID=%b", uart_rx_fifo_valid);
          end
          4'hC: begin  // CTRL register (0xC)
            uart_axil_rdata <= 32'h00;
          end
          default: uart_axil_rdata <= 32'h00;
        endcase
        uart_axil_rvalid <= 1'b1;
      end else if (uart_axil_rvalid && uart_axil_rready) begin
        uart_axil_rvalid <= 1'b0;
      end

      // Handle write requests on UART AXIL
      if (uart_axil_awvalid && uart_axil_awready && uart_axil_wvalid && uart_axil_wready) begin
        case (uart_axil_awaddr[3:0])
          4'h4: begin  // TX register (0x4)
            // Data being transmitted through UART
            $display("    [UART TX WRITE] 0x%02h", uart_axil_wdata[7:0]);
          end
        endcase
        uart_axil_bvalid <= 1'b1;
      end else if (uart_axil_bvalid && uart_axil_bready) begin
        uart_axil_bvalid <= 1'b0;
      end
    end
  end

endmodule
