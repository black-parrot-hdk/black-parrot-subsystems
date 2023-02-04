
`include "bsg_defines.v"


/*************************************************************************************

clk250_i:
    +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +-
        |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
        +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+   +---+


clk250_rst_i:
    +--------+
             |
             +-----------------------------------------------------------------------+


phy_rgmii_tx_clk_o(when ETH operating in 1000M mode):
                                                 +-------+       +-------+       +---+
                                                 |       |       |       |       |
    +--------------------------------------------+       +-------+       +-------+


mac_gmii_tx_clk_o:
                     +-------+       +-------+       +-------+       +-------+
                     |       |       |       |       |       |       |       |
    +----------------+       +-------+       +-------+       +-------+       +-------+

*************************************************************************************/



module tx_clks_generator
(
      input  logic       clk250_i
    , input  logic       clk250_rst_i
    , input  logic       tx_clk_gen_rst_i

    // phy_rgmii_tx_clk_setting_i:
    // It is used for determining the frequency of
    // phy_rgmii_tx_clk_o. With this, we can support
    // various modes: 10M, 100M, 1000M Ethernet.
    , input  logic [1:0] phy_rgmii_tx_clk_setting_i
    , output logic       phy_rgmii_tx_clk_o
    , output logic       mac_gmii_tx_clk_o
);

/*
 * phy_rgmii_tx_clk_gen and gtx_clk_gen should use the same
 * reset_i signal. Otherwise the PHY TX clk might not be
 * logically in sync with the gtx clk, i.e. the first data
 * sent in TX RGMII must be followed by a pos edge of RGMII
 * TX clk instead of a neg edge.
 */

/** phy_rgmii_tx_clk generation **/
oddr_clock_downsample_and_right_shift
 phy_rgmii_tx_clk_gen (
  .clk_i(clk250_i)
  ,.reset_i(clk250_rst_i)
  ,.clk_setting_i(phy_rgmii_tx_clk_setting_i)
  ,.ready_o(/* UNUSED */)
  ,.clk_r_o(phy_rgmii_tx_clk_o));


/** gtx_clk generation **/
bsg_counter_clock_downsample #(.width_p(2))
 gtx_clk_gen (
  .clk_i(clk250_i)
  ,.reset_i(tx_clk_gen_rst_i)
  ,.val_i(2'b0) // divided by 2
  ,.clk_r_o(mac_gmii_tx_clk_o));

endmodule
