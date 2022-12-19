`default_nettype none

`include "bsg_defines.v"

//   This testbench contains two parts: user_signals and phy_nonsynth.
// user_signals sends and receives packets at user level while phy_nonsynth
// sends and receives packets at RGMII level.

//   Currently user_signals sends only one packet.
// Therefore the expected output should be that both
// MAC and PHY side receive a packet with payload
// 00, 01, ...

// The write op size can be set to different value
// 2'b00: 1 byte, 2'b01: 2 bytes, 2'b10: 4 bytes
`define WRITE_OP_SIZE 2'b10
program user_signals #(
    parameter data_width_p
  , localparam addr_width_lp = 14
)
(
      input  bit                         clk_i
    , output bit                         reset_o
    , input  bit                         clk250_i
    , output bit                         clk250_reset_o
    , input  bit                         tx_clk_i
    , output bit                         tx_reset_o
    , input  bit                         rx_clk_i
    , output bit                         rx_reset_o

    , output logic [addr_width_lp-1:0]   addr_o
    , output logic                       write_en_o
    , output logic                       read_en_o
    , output logic [data_width_p/8-1:0]  write_mask_o
    , output logic [data_width_p-1:0]    write_data_o
    , input  logic [data_width_p-1:0]    read_data_i

    , input  logic                       rx_interrupt_pending_i
    , input  logic                       tx_interrupt_pending_i
);

  int unsigned op_size_lo;

  function automatic int unsigned op_size_to_mask(
       int unsigned op_size_i);
    int unsigned mask_o;
    case(op_size_i)
      'b00:    mask_o = 'h1;
      'b01:    mask_o = 'h3;
      'b10:    mask_o = 'hF;
      'b11:    mask_o = 'hFF;
      default: begin mask_o = 'x; $display("%m: invalid op_size"); end
    endcase
    return mask_o;
  endfunction


  task automatic write_addr (
       input int unsigned address
      ,input int unsigned data
      ,input int unsigned op_size);
    assert((address % ('b1 << op_size)) == 0);
//    op_size_o    = op_size;
    write_mask_o = op_size_to_mask(op_size);
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
//    op_size_o = op_size;
    write_mask_o = op_size_to_mask(op_size);
    addr_o    = address;
    read_en_o = 1'b1;
    @(posedge clk_i)
    read_data = read_data_i;
    read_en_o = 1'b0;
  endtask

  task automatic send_packet (
       input int unsigned size
      ,input int unsigned op_size);
    bit [7:0] next_char = '0;
    int unsigned word, wait_cnt, read_data;
    bit [data_width_p-1:0] write_data;
    assert((size % ('b1 << op_size)) == 0);
    assert((data_width_p / 8) >= ('b1 << op_size));
    word = size / ('b1 << op_size);
    // Sending packet with size 'size'
    // wait until TX is ready
    wait_cnt = 0;
    forever begin
      read_addr(32'h101C, read_data, 32'b10);
      if(read_data == 32'd1)
        break;
      if(wait_cnt > 10000) begin
        $display("MAC TX Timeout");
        $finish;
      end
      wait_cnt = wait_cnt + 1;
    end
    for(int unsigned i = 0;i < word;i++) begin
      write_data = '0;
      for(int j = 0;j < (1 << op_size);j++)
        write_data[j * 8+:8] = next_char++;
      write_data = write_data << (i * ('d1 << op_size) * 8 % data_width_p);
      write_addr('h0800 + (i * ('d1 << op_size)), write_data, op_size);
    end

    // write size
    write_addr(32'h1028, size, 32'b10);
    // send
    write_addr(32'h1018, 32'b0, 32'b10);
  endtask

  task automatic receive_packet ();
    int unsigned read_data, size;
    int unsigned word;
    int unsigned op_size = $clog2(data_width_p/8);

    int unsigned ret, i, wait_cnt = 0;
    // wait, read packets
    forever begin
      read_addr(32'h1010, read_data, 32'b10);
      if(read_data == 32'd1)
        break;
      if(wait_cnt > 10000) begin
        $display("MAC RX Timeout");
        $finish;
      end
      wait_cnt = wait_cnt + 1;
    end
    read_addr(32'h1004, size, 32'b10);
    assert((size % ('b1 << op_size)) == 0);
    $display("MAC received a packet:");
    $display("size: 0x%x", size);
    $display("payload:");

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
  bit [1:0] write_op_size;
  initial begin
    write_en_o = 1'b0;
    read_en_o = 1'b0;
    clk250_reset_o = 1'b1;
    reset_o        = 1'b1;
    rx_reset_o     = 1'b1;
    tx_reset_o    = 1'b1;
    // Assuming rx_clk can be the slowest clock
    // Wait for 3 * 2.5MHZ cycle starting from a rx_clk posedge clk
    // This should be long enough for flushing all the unknown values
    // in bsg_launch_sync_sync
    @(posedge rx_clk_i);
    #1200; // ((1/2.5) * 1000) * 3
    // Reset Deassertion order:
    // clk250_reset_o -> tx_reset_o -+-> reset_o
    //                                ^
    // -------- rx_reset_o -----------+
    @(posedge clk250_i);
    clk250_reset_o = 1'b0;
    @(posedge tx_clk_i);
    @(posedge tx_clk_i);
    @(posedge tx_clk_i);
    tx_reset_o = 1'b0;
    @(posedge rx_clk_i)
    @(posedge rx_clk_i)
    @(posedge rx_clk_i)
    rx_reset_o = 1'b0;
    @(posedge clk_i)
    reset_o = 1'b0;

    // test starts
    // Set the write op size here:
    write_op_size = `WRITE_OP_SIZE;
    send_packet(32'd128, write_op_size);
    receive_packet();
    // Wait for some period of time
    for(int i = 0;i < 4096;i++)
      @(posedge clk_i);
    $display("Test completed");
    $finish;
  end
endprogram


module wrapper();
  parameter data_width_p = 32;
  localparam addr_width_lp = 14;
  initial begin
    $vcdplusfile("dump.vpd");
    $vcdpluson();
  end
  bit clk_li;
  bit reset_li;
  bit clk250_li;
  bit clk250_reset_li;
  bit tx_clk_lo;
  bit tx_reset_li;
  bit rx_clk_lo;
  bit rx_reset_li;

  logic [addr_width_lp-1:0]   addr_li;
  logic                       write_en_li;
  logic                       read_en_li;
  logic [data_width_p/8-1:0]  write_mask_li;
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

  always #25 clk_li  = ~clk_li; // 20 MHZ
  always #2  clk250_li = ~clk250_li; // 250 MHZ

  user_signals #(
     .data_width_p(data_width_p)
  ) user_signals (
     .clk_i(clk_li)
    ,.reset_o(reset_li)
    ,.clk250_i(clk250_li)
    ,.clk250_reset_o(clk250_reset_li)
    ,.tx_clk_i(tx_clk_lo)
    ,.tx_reset_o(tx_reset_li)
    ,.rx_clk_i(rx_clk_lo)
    ,.rx_reset_o(rx_reset_li)

    ,.addr_o(addr_li)
    ,.write_en_o(write_en_li)
    ,.read_en_o(read_en_li)
    ,.write_mask_o(write_mask_li)
    ,.write_data_o(write_data_li)
    ,.read_data_i(read_data_lo)

    ,.rx_interrupt_pending_i(rx_interrupt_pending_lo)
    ,.tx_interrupt_pending_i(tx_interrupt_pending_lo)

  );

  phy_nonsynth phy (
     .rgmii_rx_clk_o(rgmii_rx_clk_li)
    ,.rgmii_rx_rst_i(rx_reset_li)
    ,.rgmii_rxd_o(rgmii_rxd_li)
    ,.rgmii_rx_ctl_o(rgmii_rx_ctl_li)
    ,.rgmii_tx_clk_i(rgmii_tx_clk_lo)
    ,.rgmii_txd_i(rgmii_txd_lo)
    ,.rgmii_tx_ctl_i(rgmii_tx_ctl_lo)
    ,.speed_i(dut.mac.speed)
  );

  ethernet_controller #(
     .data_width_p(data_width_p)
  ) dut (
     .clk_i(clk_li)
    ,.reset_i(reset_li)
    ,.clk250_i(clk250_li)
    ,.clk250_reset_i(clk250_reset_li)
    ,.tx_clk_o(tx_clk_lo)
    ,.tx_reset_i(tx_reset_li)
    ,.rx_clk_o(rx_clk_lo)
    ,.rx_reset_i(rx_reset_li)

    ,.addr_i(addr_li)
    ,.write_en_i(write_en_li)
    ,.read_en_i(read_en_li)
    ,.write_mask_i(write_mask_li)
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

