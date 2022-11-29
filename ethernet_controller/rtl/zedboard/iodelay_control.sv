
`include "bsg_defines.v"

module iodelay_control #(
      parameter `BSG_INV_PARAM(simulation_p)
)
(
      input  logic clk_i
    , input  logic reset_i
    , input  logic iodelay_ref_clk_i
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


  BUFG iodelay_ref_clk_bufg(
    .I(iodelay_ref_clk_i)
   ,.O(iodelay_ref_clk_lo)
  );

  logic reset_iodelay_li;

  // reset sync logic for iodelay control
/*
  logic [3:0] reset_iodelay_sync_r;
  always @(posedge iodelay_ref_clk_lo or posedge reset_r_i) begin
    if(reset_r_i)
      reset_iodelay_sync_r <= '1;
    else
      reset_iodelay_sync_r <= {1'b0, reset_iodelay_sync_r[3:1]};
  end
  assign reset_iodelay_li = reset_iodelay_sync_r[0];
*/
  arst_sync reset_iodelay_sync (
     .arst_i(reset_i)
    ,.bclk_i(iodelay_ref_clk_lo)
    ,.brst_o(reset_iodelay_li)
  );

  logic reset_iodelay_hold_r;
  logic [3:0] reset_iodelay_hold_cnt_r;
  wire down_li = (reset_iodelay_hold_cnt_r != '0);
  bsg_counter_set_down #(
    .width_p(4)
    ,.init_val_p(4'b1111)) // hold high for more than 60ns
   reset_iodelay_hold_cnt_reg (
    .clk_i(iodelay_ref_clk_lo)
    ,.reset_i(reset_iodelay_li)
    ,.set_i(1'b0) /* UNUSED */
    ,.val_i('0) /* UNUSED */
    ,.down_i(down_li)
    ,.count_r_o(reset_iodelay_hold_cnt_r)
    );

  wire data_li = (reset_iodelay_hold_cnt_r != '0);
  bsg_dff_reset #(
    .width_p(1)
    ,.reset_val_p(1'b1))
   reset_iodelay_hold_reg (
    .clk_i(iodelay_ref_clk_lo)
    ,.reset_i(reset_iodelay_li)
    ,.data_i(data_li)
    ,.data_o(reset_iodelay_hold_r)
    );

  IDELAYCTRL idelayctrl_inst (
    .RDY(/* UNUSED */)
    ,.REFCLK(iodelay_ref_clk_lo)
    ,.RST(reset_iodelay_hold_r) // active-high reset
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
