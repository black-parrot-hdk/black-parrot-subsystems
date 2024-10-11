
`include "bsg_defines.sv"

module iodelay_control #(
)
(
      input  logic       clk_i
    , input  logic       reset_i
    , input  logic       iodelay_clk_i
    , input  logic       iodelay_reset_i
    , input  logic [3:0] rgmii_rxd_i
    , input  logic       rgmii_rx_ctl_i
    , output logic [3:0] rgmii_rxd_delayed_o
    , output logic       rgmii_rx_ctl_delayed_o
);

  assign rgmii_rxd_delayed_o    = rgmii_rxd_i;
  assign rgmii_rx_ctl_delayed_o = rgmii_rx_ctl_i;

endmodule

