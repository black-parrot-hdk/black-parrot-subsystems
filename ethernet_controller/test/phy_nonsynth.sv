`default_nettype none

`timescale 1ns/1ps



// Change the PHY speed here: SPEED_10/100/1000
`define SPEED_1000 // MHZ

//         MAC dest + SRC dest + EtherType + Payload:
// 7 + 1 + 6        + 6        + 2         + 1500 + 4
`define PACKET_MAX_SIZE 1526

// Currently phy_nonsynth only sends 1 RGMII packet
module phy_nonsynth (
      output bit                         rgmii_rx_clk_o
    , input  bit                         rgmii_rx_rst_i
    , output logic [3:0]                 rgmii_rxd_o
    , output logic                       rgmii_rx_ctl_o
    , input  bit                         rgmii_tx_clk_i
    , input  logic [3:0]                 rgmii_txd_i
    , input  logic                       rgmii_tx_ctl_i
    , input  logic [1:0]                 speed_i
);
  int unsigned crctable[256] = {
    32'h00000000, 32'h77073096, 32'hEE0E612C, 32'h990951BA,
    32'h076DC419, 32'h706AF48F, 32'hE963A535, 32'h9E6495A3,
    32'h0EDB8832, 32'h79DCB8A4, 32'hE0D5E91E, 32'h97D2D988,
    32'h09B64C2B, 32'h7EB17CBD, 32'hE7B82D07, 32'h90BF1D91,
    32'h1DB71064, 32'h6AB020F2, 32'hF3B97148, 32'h84BE41DE,
    32'h1ADAD47D, 32'h6DDDE4EB, 32'hF4D4B551, 32'h83D385C7,
    32'h136C9856, 32'h646BA8C0, 32'hFD62F97A, 32'h8A65C9EC,
    32'h14015C4F, 32'h63066CD9, 32'hFA0F3D63, 32'h8D080DF5,
    32'h3B6E20C8, 32'h4C69105E, 32'hD56041E4, 32'hA2677172,
    32'h3C03E4D1, 32'h4B04D447, 32'hD20D85FD, 32'hA50AB56B,
    32'h35B5A8FA, 32'h42B2986C, 32'hDBBBC9D6, 32'hACBCF940,
    32'h32D86CE3, 32'h45DF5C75, 32'hDCD60DCF, 32'hABD13D59,
    32'h26D930AC, 32'h51DE003A, 32'hC8D75180, 32'hBFD06116,
    32'h21B4F4B5, 32'h56B3C423, 32'hCFBA9599, 32'hB8BDA50F,
    32'h2802B89E, 32'h5F058808, 32'hC60CD9B2, 32'hB10BE924,
    32'h2F6F7C87, 32'h58684C11, 32'hC1611DAB, 32'hB6662D3D,
    32'h76DC4190, 32'h01DB7106, 32'h98D220BC, 32'hEFD5102A,
    32'h71B18589, 32'h06B6B51F, 32'h9FBFE4A5, 32'hE8B8D433,
    32'h7807C9A2, 32'h0F00F934, 32'h9609A88E, 32'hE10E9818,
    32'h7F6A0DBB, 32'h086D3D2D, 32'h91646C97, 32'hE6635C01,
    32'h6B6B51F4, 32'h1C6C6162, 32'h856530D8, 32'hF262004E,
    32'h6C0695ED, 32'h1B01A57B, 32'h8208F4C1, 32'hF50FC457,
    32'h65B0D9C6, 32'h12B7E950, 32'h8BBEB8EA, 32'hFCB9887C,
    32'h62DD1DDF, 32'h15DA2D49, 32'h8CD37CF3, 32'hFBD44C65,
    32'h4DB26158, 32'h3AB551CE, 32'hA3BC0074, 32'hD4BB30E2,
    32'h4ADFA541, 32'h3DD895D7, 32'hA4D1C46D, 32'hD3D6F4FB,
    32'h4369E96A, 32'h346ED9FC, 32'hAD678846, 32'hDA60B8D0,
    32'h44042D73, 32'h33031DE5, 32'hAA0A4C5F, 32'hDD0D7CC9,
    32'h5005713C, 32'h270241AA, 32'hBE0B1010, 32'hC90C2086,
    32'h5768B525, 32'h206F85B3, 32'hB966D409, 32'hCE61E49F,
    32'h5EDEF90E, 32'h29D9C998, 32'hB0D09822, 32'hC7D7A8B4,
    32'h59B33D17, 32'h2EB40D81, 32'hB7BD5C3B, 32'hC0BA6CAD,
    32'hEDB88320, 32'h9ABFB3B6, 32'h03B6E20C, 32'h74B1D29A,
    32'hEAD54739, 32'h9DD277AF, 32'h04DB2615, 32'h73DC1683,
    32'hE3630B12, 32'h94643B84, 32'h0D6D6A3E, 32'h7A6A5AA8,
    32'hE40ECF0B, 32'h9309FF9D, 32'h0A00AE27, 32'h7D079EB1,
    32'hF00F9344, 32'h8708A3D2, 32'h1E01F268, 32'h6906C2FE,
    32'hF762575D, 32'h806567CB, 32'h196C3671, 32'h6E6B06E7,
    32'hFED41B76, 32'h89D32BE0, 32'h10DA7A5A, 32'h67DD4ACC,
    32'hF9B9DF6F, 32'h8EBEEFF9, 32'h17B7BE43, 32'h60B08ED5,
    32'hD6D6A3E8, 32'hA1D1937E, 32'h38D8C2C4, 32'h4FDFF252,
    32'hD1BB67F1, 32'hA6BC5767, 32'h3FB506DD, 32'h48B2364B,
    32'hD80D2BDA, 32'hAF0A1B4C, 32'h36034AF6, 32'h41047A60,
    32'hDF60EFC3, 32'hA867DF55, 32'h316E8EEF, 32'h4669BE79,
    32'hCB61B38C, 32'hBC66831A, 32'h256FD2A0, 32'h5268E236,
    32'hCC0C7795, 32'hBB0B4703, 32'h220216B9, 32'h5505262F,
    32'hC5BA3BBE, 32'hB2BD0B28, 32'h2BB45A92, 32'h5CB36A04,
    32'hC2D7FFA7, 32'hB5D0CF31, 32'h2CD99E8B, 32'h5BDEAE1D,
    32'h9B64C2B0, 32'hEC63F226, 32'h756AA39C, 32'h026D930A,
    32'h9C0906A9, 32'hEB0E363F, 32'h72076785, 32'h05005713,
    32'h95BF4A82, 32'hE2B87A14, 32'h7BB12BAE, 32'h0CB61B38,
    32'h92D28E9B, 32'hE5D5BE0D, 32'h7CDCEFB7, 32'h0BDBDF21,
    32'h86D3D2D4, 32'hF1D4E242, 32'h68DDB3F8, 32'h1FDA836E,
    32'h81BE16CD, 32'hF6B9265B, 32'h6FB077E1, 32'h18B74777,
    32'h88085AE6, 32'hFF0F6A70, 32'h66063BCA, 32'h11010B5C,
    32'h8F659EFF, 32'hF862AE69, 32'h616BFFD3, 32'h166CCF45,
    32'hA00AE278, 32'hD70DD2EE, 32'h4E048354, 32'h3903B3C2,
    32'hA7672661, 32'hD06016F7, 32'h4969474D, 32'h3E6E77DB,
    32'hAED16A4A, 32'hD9D65ADC, 32'h40DF0B66, 32'h37D83BF0,
    32'hA9BCAE53, 32'hDEBB9EC5, 32'h47B2CF7F, 32'h30B5FFE9,
    32'hBDBDF21C, 32'hCABAC28A, 32'h53B39330, 32'h24B4A3A6,
    32'hBAD03605, 32'hCDD70693, 32'h54DE5729, 32'h23D967BF,
    32'hB3667A2E, 32'hC4614AB8, 32'h5D681B02, 32'h2A6F2B94,
    32'hB40BBE37, 32'hC30C8EA1, 32'h5A05DF1B, 32'h2D02EF8D
  };

  function automatic int unsigned CalcCRC32(
        byte unsigned packet[1513:0],
        int unsigned len);
    int unsigned crc = 32'hffffffff;

    for (int j = 0; j < len; j++) begin
      crc = crctable[(crc ^ packet[j]) & 32'hFF] ^ (crc >> 8);
    end
    return crc ^ 32'hffffffff;
  endfunction

  bit clk250_internal;
  bit clk250_reset_internal;
  always #2 clk250_internal = ~clk250_internal;

  initial begin
    rgmii_rxd_o = '0;
    rgmii_rx_ctl_o = 1'b0;
    clk250_reset_internal = 1'b1;
    @(negedge clk250_internal)
    clk250_reset_internal = 1'b0;
  end

`ifdef SPEED_1000
  wire [6:0] val_li = 7'd0;
`elsif SPEED_100
  wire [6:0] val_li = 7'd4;
`elsif SPEED_10
  wire [6:0] val_li = 7'd49;
`endif
  bit rgmii_txd_reference_clk;
  // X / 2 - 1
  bsg_counter_clock_downsample #(
     .width_p(7)
  ) rgmii_txd_reference_clk_downsample (
     .clk_i(clk250_internal)
    ,.reset_i(clk250_reset_internal)
    ,.val_i(val_li)
    ,.clk_r_o(rgmii_txd_reference_clk)
  );

  task automatic rx_clk_generator();
    forever begin
      @(posedge rgmii_txd_reference_clk);
      @(negedge clk250_internal);
      rgmii_rx_clk_o = ~rgmii_rx_clk_o;
      @(negedge rgmii_txd_reference_clk)
      @(negedge clk250_internal);
      rgmii_rx_clk_o = ~rgmii_rx_clk_o;
    end
  endtask

  task automatic rx_signals_generator(
      byte unsigned packet [`PACKET_MAX_SIZE - 1:0],
      int unsigned packet_size);
    int unsigned packet_idx = 0;
    bit [7:0] next_byte;
    bit second_half = 1'b0;

    forever begin
      @(posedge rgmii_txd_reference_clk);
      if(packet_idx == packet_size + 12) begin
        rgmii_rx_ctl_o = 1'b0;
        break;
      end
      next_byte = packet[packet_idx];
`ifdef SPEED_1000
      rgmii_rxd_o = next_byte[3:0];
`else
      if(second_half)
        rgmii_rxd_o = next_byte[7:4];
      else
        rgmii_rxd_o = next_byte[3:0];

`endif
      rgmii_rx_ctl_o = 1'b1;
      @(negedge rgmii_txd_reference_clk)
`ifdef SPEED_1000
      rgmii_rxd_o = next_byte[7:4];
`endif
      rgmii_rx_ctl_o = 1'b1;
`ifndef SPEED_1000
      if(second_half) begin
`endif
        // sent out a byte
        packet_idx++;
`ifndef SPEED_1000
      end
      second_half = ~second_half;
`endif
    end

  endtask

  // Send procedure
  initial begin
    byte unsigned next_char = 0;
    // Change the RGMII packet size here:
    int unsigned packet_size = 64;
    byte unsigned packet [`PACKET_MAX_SIZE - 1:0];
    int unsigned crc;
    assert(packet_size <= 1514);
    rgmii_rx_ctl_o = 1'b0;

    @(negedge rgmii_rx_rst_i);
    // Start sending
    // Sending preamble & SFD
    for(int i = 0;i < 7;i++) begin
      packet[i] = 8'h55;
    end
    packet[7] = 8'hd5;
    // Sending packet content
    for(int i = 0;i < packet_size;i++)
      packet[i + 8] = next_char++;
    // Sending FCS
    crc = CalcCRC32(packet[`PACKET_MAX_SIZE - 5:8], packet_size);
    for(int i = 0;i < 4;i++)
      packet[packet_size + 8 + i] = (crc >> (i * 8)) & 32'hff;
    // wait until the speed indicator has been changed accordingly
`ifdef SPEED_1000
    wait(speed_i == 2'b10);
`elsif SPEED_100
    wait(speed_i == 2'b01);
`elsif SPEED_10
    wait(speed_i == 2'b00);
`endif
    rx_signals_generator(packet, packet_size);
  end
  initial begin
    @(negedge clk250_reset_internal);
    rx_clk_generator();
  end

  // Recv procedure
  initial begin
    int receiving_flag = 0;
    bit second_half = 1'b0;
    byte unsigned packet [`PACKET_MAX_SIZE - 1:0];
    logic [7:0] txd;
    logic tx_en, tx_er;
    int unsigned packet_idx = 0, crc_dut, crc;
    forever begin
      @(posedge rgmii_tx_clk_i);
      tx_en = rgmii_tx_ctl_i;
`ifdef SPEED_1000
      txd[3:0] = rgmii_txd_i;
`else
      if(second_half)
        txd[7:4] = rgmii_txd_i;
      else
        txd[3:0] = rgmii_txd_i;
`endif
      @(negedge rgmii_tx_clk_i)
      tx_er = tx_en ^ rgmii_tx_ctl_i;
`ifdef SPEED_1000
      txd[7:4] = rgmii_txd_i;
`endif
      if(tx_er == 1'b0 && tx_en == 1'b1) begin
`ifdef SPEED_1000
        packet[packet_idx++] = txd;
        receiving_flag = 1;
`else
        if(second_half) begin
          packet[packet_idx++] = txd;
          receiving_flag = 1;
        end
        second_half = ~second_half;
`endif
      end
      else begin
        // receive a packet
        if(receiving_flag) begin
          assert(packet_idx >= 12);
          // Check Preamble
          for(int i = 0;i < 7;i++)
            assert(packet[i] == 8'h55);
          // Check SFD
          assert(packet[7] == 8'hd5);
          crc_dut = 0;
          for(int i = 0;i < 4;i++) begin
            crc_dut <<= 8;
            crc_dut += packet[packet_idx-1-i];
          end
          // Check FCS
          crc = CalcCRC32(packet[`PACKET_MAX_SIZE - 5:8], packet_idx - 12);
          assert(crc == crc_dut);
          $display("PHY received a packet without corruption:");
          $display("size(including preamble and CRC): 0x%x", packet_idx);
          for(int i = 0;i < packet_idx;i++)
            $display("%x", packet[i]);
          second_half = 1'b0;
          packet_idx = 0;
          receiving_flag = 0;
        end
      end
    end
  end

endmodule
