`default_nettype none

`include "bsg_defines.v"

`timescale 1ns/1ps


program user_signals #(
    parameter data_width_p
  , localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p/8))
  , localparam addr_width_lp = 14
)
(
      input  bit                         clk_i
    , output bit                         reset_o
    , input  bit                         clk250_i
    , output bit                         reset_clk250_o
    , input  bit                         reset_clk125_i

    , output logic [addr_width_lp-1:0]   addr_o
    , output logic                       write_en_o
    , output logic                       read_en_o
    , output logic [size_width_lp-1:0]   op_size_o
    , output logic [data_width_p-1:0]    write_data_o
    , input  logic [data_width_p-1:0]    read_data_i

    , input  logic                       rx_interrupt_pending_i
    , input  logic                       tx_interrupt_pending_i
);
  // clk250_i, reset_clk250_i init
  initial begin
    reset_clk250_o = 1'b1;
    @(posedge clk250_i)
    @(posedge clk250_i)
    reset_clk250_o = 1'b0;
  end

  // clk_i, reset_i init
  initial begin
    reset_o = 1'b1;
    @(posedge clk_i)
    @(posedge clk_i)
    @(posedge wrapper.dut.mac.rx_clk)
    @(posedge clk_i)
    @(posedge clk_i)
    reset_o = 1'b0;
  end

  task automatic write_addr (
       input int unsigned address
      ,input int unsigned data
      ,input int unsigned op_size);
    assert((address % ('b1 << op_size)) == 0);
    op_size_o    = op_size;
    addr_o       = address;
    write_data_o = data;
    write_en_o   = 1'b1;
    @(posedge clk_i)
    write_en_o   = 1'b0;
  endtask

  task automatic read_addr (
       input int unsigned address
      ,output int unsigned read_data
      ,input int unsigned op_size);
    assert((address % ('b1 << op_size)) == 0);
    op_size_o = op_size;
    addr_o    = address;
    read_en_o = 1'b1;
    @(posedge clk_i)
    read_data = read_data_i;
    read_en_o = 1'b0;
  endtask

  task automatic send_packet (
       input int unsigned size
      ,input int unsigned op_size);
    static bit [7:0] next_char;
    int unsigned word, wait_cnt, read_data;
    bit [31:0] write_data;
    assert((size % ('b1 << op_size)) == 0);
    word = size / ('b1 << op_size);
    $display("Sending packet with size 0x%x:", size);
    // wait until TX is ready
    wait_cnt = 0;
    forever begin
      read_addr(32'h101C, read_data, 32'b10);
      if(read_data == 32'd1)
        break;
      if(wait_cnt > 10000) begin
        $display("TX Timeout");
        $finish;
      end
      wait_cnt = wait_cnt + 1;
    end
    for(int unsigned i = 0;i < word;i++) begin
      write_data = '0;
      for(int j = 0;j < (1 << op_size);j++)
        write_data[j * 8+:8] = next_char++;

      write_addr('h0800 + (i * ('d1 << op_size)), write_data, op_size);
    end

    // write size
    write_addr(32'h1028, size, 32'b10);
    // send
    write_addr(32'h1018, 32'b0, 32'b10);
  endtask

  task automatic receive_packet (input int unsigned op_size);
    int unsigned read_data, size;
    int unsigned word;

    int unsigned ret, i, wait_cnt = 0;
    // wait, read packets
    forever begin
      read_addr(32'h1010, read_data, 32'b10);
      if(read_data == 32'd1)
        break;
      if(wait_cnt > 10000) begin
        $display("RX Timeout");
        $finish;
      end
      wait_cnt = wait_cnt + 1;
    end
    read_addr(32'h1004, size, 32'b10);
    assert((size % ('b1 << op_size)) == 0);
    $display("RX received packet size: 0x%x", size);
    $display("The recieved packet:");

    word = size / ('b1 << op_size);
    for(i = 0;i < word;i = i + 1) begin
        read_addr(32'h0000 + i * (1 << op_size), read_data, op_size);
        $display("%x", read_data);
    end
    // clear RX pending
    write_addr(32'h1010, 32'd1, 32'b10);
  endtask

/*
  // Set timeout
  initial begin
    #1000000
    $fclose(tx_fd);
    $fclose(rx_fd);
    $display("Timeout");
    $finish;
  end
*/
  initial begin
    write_en_o = 1'b0;
    read_en_o = 1'b0;

    @(negedge reset_clk125_i);
    // test starts
    send_packet(32'd128, 2'b10);
    receive_packet(2);
    for(int i = 0;i < 4096;i++)
      @(posedge clk_i);
    $display("Test completed");
    $finish;
  end
endprogram


module wrapper();
  parameter data_width_p = 32;
  localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p/8));
  localparam addr_width_lp = 14;
  initial begin
//    $dumpfile("dump.vcd");
//    $dumpvars;
    $vcdplusfile("dump.vpd");
    $vcdpluson();
  end
  bit clk_i;
  bit reset_i;
  bit clk250_i;
  bit reset_clk250_i;

  bit                         reset_clk125_lo;

  logic [addr_width_lp-1:0]   addr_li;
  logic                       write_en_li;
  logic                       read_en_li;
  logic [size_width_lp-1:0]   op_size_li;
  logic [data_width_p-1:0]    write_data_li;
  logic [data_width_p-1:0]    read_data_lo;

  logic                       rx_interrupt_pending_lo;
  logic                       tx_interrupt_pending_lo;

  logic                       rgmii_rx_clk_li;
  logic [3:0]                 rgmii_rxd_li;
  logic                       rgmii_rx_ctl_li;
  logic                       rgmii_tx_clk_lo;
  logic [3:0]                 rgmii_txd_lo;
  logic                       rgmii_tx_ctl_lo;

  always #25 clk_i  = ~clk_i; // 20 MHZ
  always #2  clk250_i = ~clk250_i; // 250 MHZ


  user_signals #(
     .data_width_p(data_width_p)
  ) user_signals (
     .clk_i(clk_i)
    ,.reset_o(reset_i)
    ,.clk250_i(clk250_i)
    ,.reset_clk250_o(reset_clk250_i)
    ,.reset_clk125_i(reset_clk125_lo)
                            
    ,.addr_o(addr_li)
    ,.write_en_o(write_en_li)
    ,.read_en_o(read_en_li)
    ,.op_size_o(op_size_li)
    ,.write_data_o(write_data_li)
    ,.read_data_i(read_data_lo)
                            
    ,.rx_interrupt_pending_i(rx_interrupt_pending_lo)
    ,.tx_interrupt_pending_i(tx_interrupt_pending_lo)
                            
  );

  phy_nonsynth phy (
     .rgmii_rx_clk_o(rgmii_rx_clk_li)
    ,.rgmii_rxd_o(rgmii_rxd_li)
    ,.rgmii_rx_ctl_o(rgmii_rx_ctl_li)
    ,.rgmii_tx_clk_i(rgmii_tx_clk_lo)
    ,.rgmii_txd_i(rgmii_txd_lo)
    ,.rgmii_tx_ctl_i(rgmii_tx_ctl_lo)
    ,.reset_clk125_i(reset_clk125_lo)
    ,.speed_i(dut.mac.speed)
  );

  ethernet_controller #(
     .data_width_p(data_width_p)
  ) dut (
     .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clk250_i(clk250_i)
    ,.reset_clk250_i(reset_clk250_i)
    ,.reset_clk125_o(reset_clk125_lo)

    ,.addr_i(addr_li)
    ,.write_en_i(write_en_li)
    ,.read_en_i(read_en_li)
    ,.op_size_i(op_size_li)
    ,.write_data_i(write_data_li)
    ,.read_data_o(read_data_lo)

    ,.rx_interrupt_pending_o(rx_interrupt_pending_lo)
    ,.tx_interrupt_pending_o(tx_interrupt_pending_lo)

    ,.rgmii_rx_clk_i(rgmii_rx_clk_li)
    ,.rgmii_rxd_i(rgmii_rxd_li)
    ,.rgmii_rx_ctl_i(rgmii_rx_ctl_li)
    ,.rgmii_tx_clk_o(rgmii_tx_clk_lo)
    ,.rgmii_txd_o(rgmii_txd_lo)
    ,.rgmii_tx_ctl_o(rgmii_tx_ctl_lo)
  );

endmodule

