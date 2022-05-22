
/*
 *   This module downsamples and right shifts the input clock.
 * In our specific use case, the clk_i is 250 MHZ, and by having
 * differnet clk_setting_i, we can get 2.5 MHZ, 25 MHZ and 125 MHZ
 * right shifted generated clock at runtime.
 *   To see how Alex's Ethernet module achieves this, please see
 * rgmii_tx_clk_1, rgmii_tx_clk_2 in rgmii_phy_if.v.
 *
 */

module oddr_clock_downsample_and_right_shift
  (input                      clk_i
  ,input                      reset_i
  ,input [1:0]                clk_setting_i
  ,output                     ready_o
   // output clock and data
  ,output logic               clk_r_o
  );

  logic odd_r;
  logic [1:0] clk_setting_r;
  logic       clk_setting_r_2;

  // ready to accept new data every two cycles
  assign ready_o = ~odd_r;

  always_ff @(posedge clk_i)
    if (~odd_r)
        clk_setting_r <= clk_setting_i;

  // odd_r signal (mux select bit)
  always_ff @(posedge clk_i)
    if (reset_i)
        odd_r <= 1'b0;
    else
        odd_r <= ~odd_r;

  always_ff @(negedge clk_i)
    if (odd_r)
        clk_setting_r_2 <= clk_setting_r[0];
    else
        clk_setting_r_2 <= clk_setting_r[1];

  always_ff @(negedge clk_i)
    clk_r_o <= clk_setting_r_2;

endmodule
