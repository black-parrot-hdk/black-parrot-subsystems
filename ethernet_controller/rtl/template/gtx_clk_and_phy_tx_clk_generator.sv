
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


gtx_clk_r_o:
                     +-------+       +-------+       +-------+       +-------+
                     |       |       |       |       |       |       |       |
    +----------------+       +-------+       +-------+       +-------+       +-------+

*************************************************************************************/



module gtx_clk_and_phy_tx_clk_generator
(
      input  logic       clk250_i
    , input  logic       clk250_rst_i

    // phy_rgmii_tx_clk_setting_i:
    // It is used for determining the frequency of
    // phy_rgmii_tx_clk_o. With this, we can support
    // various modes: 10M, 100M, 1000M Ethernet.
    , input  logic [1:0] phy_rgmii_tx_clk_setting_i
    , output logic       phy_rgmii_tx_clk_o

    , output logic       gtx_clk_r_o
    , output logic       gtx_rst_r_o
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
  ,.reset_i(clk250_rst_i)
  ,.val_i(2'b0) // divided by 2
  ,.clk_r_o(gtx_clk_r_o));

/** gtx_clk_rst generation **/

// The minimal value for max_val_lp should be 100,
// because when phy_rgmii_rx_clk is 2.5MHZ,
// we need to hold the gtx_rst for at least
// 250MHZ / 2.5MHZ == 100 cycles to guarantee the
// reset signal will be sampled at least once.
localparam max_val_lp = 128;
localparam ptr_width_lp = `BSG_SAFE_CLOG2(max_val_lp+1);
logic [ptr_width_lp-1:0] reset_cycle_r;
wire up_li = (reset_cycle_r != max_val_lp);

bsg_counter_clear_up #(
  .max_val_p(max_val_lp)
  ,.init_val_p(0))
 reset_cycle_counter (
  .clk_i(clk250_i)
  ,.reset_i(clk250_rst_i)
  ,.clear_i(1'b0)
  ,.up_i(up_li)
  ,.count_o(reset_cycle_r));

wire gtx_rst_n = (reset_cycle_r != max_val_lp);
bsg_dff #(.width_p(1))
 reset_buf (
  .clk_i(clk250_i)
  ,.data_i(gtx_rst_n)
  ,.data_o(gtx_rst_r_o));

endmodule
