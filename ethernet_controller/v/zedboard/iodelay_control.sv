
`include "bsg_defines.v"

module iodelay_control #(
      parameter `BSG_INV_PARAM(simulation_p)
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

logic iodelay_ref_clk_lo;

if(simulation_p == 1) begin: sim
  assign rgmii_rxd_delayed_o    = rgmii_rxd_i;
  assign rgmii_rx_ctl_delayed_o = rgmii_rx_ctl_i;
end else begin: nosim


  BUFG iodelay_clk_bufg(
    .I(iodelay_clk_i)
   ,.O(iodelay_clk_lo)
  );

  IDELAYCTRL idelayctrl_inst (
    .RDY(/* UNUSED */)
    ,.REFCLK(iodelay_clk_lo)
    ,.RST(iodelay_reset_i) // active-high reset; should be held high for more than 60ns
    );

  wire  [4:0] input_d   = {rgmii_rxd_i, rgmii_rx_ctl_i};
  logic [4:0] delayed_d;

  genvar n;
  for ( n = 0; n < 5; n = n + 1) begin: idelaye2
    // We need IDELAYE2 to meet the timing
    //   requirement for RX side of the RGMII signals

    IDELAYE2 #(
        .DELAY_SRC("IDATAIN")
       ,.IDELAY_TYPE("FIXED")
       ,.IDELAY_VALUE(0)
       ,.REFCLK_FREQUENCY(200.0)
       ,.SIGNAL_PATTERN("DATA")
    ) idelaye2_inst (
        .CNTVALUEOUT() // UNUSED
       ,.DATAOUT(delayed_d[n])
       ,.C(1'b0)
       ,.CE(1'b0)
       ,.CINVCTRL(1'b0)
       ,.CNTVALUEIN('0)
       ,.DATAIN() // UNUSED
       ,.IDATAIN(input_d[n])
       ,.INC(1'b0)
       ,.LD(1'b0)
       ,.LDPIPEEN(1'b0)
       ,.REGRST(1'b0)
    );
  end
  assign {rgmii_rxd_delayed_o, rgmii_rx_ctl_delayed_o} = delayed_d;
end
endmodule

`BSG_ABSTRACT_MODULE(iodelay_control)
