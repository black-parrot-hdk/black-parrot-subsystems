/*

Copyright (c) 2015-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

/*************************************************************************************

clk250_i:
    +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +-
        |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
        +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+


clk250_rst_i:
    +--------+
             |
             +-----------------------------------------------------------------------+


phy_rgmii_tx_clk:
                                                 +-------+       +-------+       +---+
                                                 |       |       |       |       |
    +--------------------------------------------+       +-------+       +-------+


mac_gmii_tx_clk:
                     +-------+       +-------+       +-------+       +-------+
                     |       |       |       |       |       |       |       |
    +----------------+       +-------+       +-------+       +-------+       +-------+


gmii_txd, gmii_tx_en, gmii_tx_er:
    +---------------------------------+---------------+---------------+--------------+
                                      |      d1d0     |      d1d0     |      d1d0
    +---------------------------------+---------------+---------------+--------------+


rgmii_txd, rgmii_tx_ctl:
    +--------------------------------------------------------+-------+-------+-------+
                                                             |  d0   |  d1   |  d0   |
    +--------------------------------------------------------+-------+-------+-------+

*************************************************************************************/


`timescale 1ns / 1ps

/*
 * RGMII PHY interface
 */
module rgmii_phy_if (
    input  wire        clk250,
    input  wire        clk250_rst,

    /*
     * GMII interface to MAC
     */
    output wire        mac_gmii_rx_clk,
    input  wire        mac_gmii_rx_rst,
    output wire [7:0]  mac_gmii_rxd,
    output wire        mac_gmii_rx_dv,
    output wire        mac_gmii_rx_er,
    output wire        mac_gmii_tx_clk,
    input  wire        mac_gmii_tx_rst,
    output wire        mac_gmii_tx_clk_en,
    input  wire [7:0]  mac_gmii_txd,
    input  wire        mac_gmii_tx_en,
    input  wire        mac_gmii_tx_er,

    /*
     * RGMII interface to PHY
     */
    input  wire        phy_rgmii_rx_clk,
    input  wire [3:0]  phy_rgmii_rxd,
    input  wire        phy_rgmii_rx_ctl,
    output wire        phy_rgmii_tx_clk,
    output wire [3:0]  phy_rgmii_txd,
    output wire        phy_rgmii_tx_ctl,

    /*
     * Control
     */
    input  wire [1:0]  speed
);

// receive

wire rgmii_rx_ctl_1;
wire rgmii_rx_ctl_2;

ssio_ddr_in #
(
    .WIDTH(5)
)
rx_ssio_ddr_inst (
    .input_clk(phy_rgmii_rx_clk),
    .input_d({phy_rgmii_rxd, phy_rgmii_rx_ctl}),
    .output_clk(mac_gmii_rx_clk),
    .output_q1({mac_gmii_rxd[3:0], rgmii_rx_ctl_1}),
    .output_q2({mac_gmii_rxd[7:4], rgmii_rx_ctl_2})
);

assign mac_gmii_rx_dv = rgmii_rx_ctl_1;
assign mac_gmii_rx_er = rgmii_rx_ctl_1 ^ rgmii_rx_ctl_2;

// transmit

reg rgmii_tx_clk_1;
reg rgmii_tx_clk_2;
reg rgmii_tx_clk_rise;
reg rgmii_tx_clk_fall;

reg [5:0] count_reg;

always @(posedge mac_gmii_tx_clk) begin
    if (mac_gmii_tx_rst) begin
        rgmii_tx_clk_1 <= 1'b1;
        rgmii_tx_clk_2 <= 1'b0;
        rgmii_tx_clk_rise <= 1'b1;
        rgmii_tx_clk_fall <= 1'b1;
        count_reg <= 0;
    end else begin
        rgmii_tx_clk_1 <= rgmii_tx_clk_2;

        if (speed == 2'b00) begin
            // 10M
            count_reg <= count_reg + 1;
            rgmii_tx_clk_rise <= 1'b0;
            rgmii_tx_clk_fall <= 1'b0;
            if (count_reg == 24) begin
                rgmii_tx_clk_1 <= 1'b1;
                rgmii_tx_clk_2 <= 1'b1;
                rgmii_tx_clk_rise <= 1'b1;
            end else if (count_reg >= 49) begin
                rgmii_tx_clk_1 <= 1'b0;
                rgmii_tx_clk_2 <= 1'b0;
                rgmii_tx_clk_fall <= 1'b1;
                count_reg <= 0;
            end
        end else if (speed == 2'b01) begin
            // 100M
            count_reg <= count_reg + 1;
            rgmii_tx_clk_rise <= 1'b0;
            rgmii_tx_clk_fall <= 1'b0;
            if (count_reg == 2) begin
                rgmii_tx_clk_1 <= 1'b1;
                rgmii_tx_clk_2 <= 1'b1;
                rgmii_tx_clk_rise <= 1'b1;
            end else if (count_reg >= 4) begin
                rgmii_tx_clk_2 <= 1'b0;
                rgmii_tx_clk_fall <= 1'b1;
                count_reg <= 0;
            end
        end else begin
            // 1000M
            rgmii_tx_clk_1 <= 1'b1;
            rgmii_tx_clk_2 <= 1'b0;
            rgmii_tx_clk_rise <= 1'b1;
            rgmii_tx_clk_fall <= 1'b1;
        end
    end
end

reg [3:0] rgmii_txd_1;
reg [3:0] rgmii_txd_2;
reg rgmii_tx_ctl_1;
reg rgmii_tx_ctl_2;

reg gmii_clk_en;

always @* begin
    if (speed == 2'b00) begin
        // 10M
        rgmii_txd_1 = mac_gmii_txd[3:0];
        rgmii_txd_2 = mac_gmii_txd[3:0];
        if (rgmii_tx_clk_2) begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en;
            rgmii_tx_ctl_2 = mac_gmii_tx_en;
        end else begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en ^ mac_gmii_tx_er;
            rgmii_tx_ctl_2 = mac_gmii_tx_en ^ mac_gmii_tx_er;
        end
        gmii_clk_en = rgmii_tx_clk_fall;
    end else if (speed == 2'b01) begin
        // 100M
        rgmii_txd_1 = mac_gmii_txd[3:0];
        rgmii_txd_2 = mac_gmii_txd[3:0];
        if (rgmii_tx_clk_2) begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en;
            rgmii_tx_ctl_2 = mac_gmii_tx_en;
        end else begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en ^ mac_gmii_tx_er;
            rgmii_tx_ctl_2 = mac_gmii_tx_en ^ mac_gmii_tx_er;
        end
        gmii_clk_en = rgmii_tx_clk_fall;
    end else begin
        // 1000M
        rgmii_txd_1 = mac_gmii_txd[3:0];
        rgmii_txd_2 = mac_gmii_txd[7:4];
        rgmii_tx_ctl_1 = mac_gmii_tx_en;
        rgmii_tx_ctl_2 = mac_gmii_tx_en ^ mac_gmii_tx_er;
        gmii_clk_en = 1;
    end
end

tx_clks_generator
 tx_clks_gen
  (.clk250_i(clk250)
   ,.clk250_rst_i(clk250_rst)

   ,.phy_rgmii_tx_clk_setting_i({rgmii_tx_clk_2, rgmii_tx_clk_1})
   ,.phy_rgmii_tx_clk_o(phy_rgmii_tx_clk)
   ,.mac_gmii_tx_clk_o(mac_gmii_tx_clk));

bsg_link_oddr_phy #(.width_p(5))
 data_oddr_inst
  (.reset_i(clk250_rst)
   ,.clk_i(clk250)
   ,.data_i({{rgmii_txd_2, rgmii_tx_ctl_2}, {rgmii_txd_1, rgmii_tx_ctl_1}})
   ,.ready_o(/* UNUSED */)

   ,.data_r_o({phy_rgmii_txd, phy_rgmii_tx_ctl})
   ,.clk_r_o(/* UNUSED */)
  );

assign mac_gmii_tx_clk_en = gmii_clk_en;

endmodule
