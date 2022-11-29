
`include "bsg_defines.v"


module ethernet_controller_wrapper #
(
      parameter  `BSG_INV_PARAM(data_width_p)
    , parameter  `BSG_INV_PARAM(simulation_p)
    , localparam addr_width_lp = 14
    , localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p/8))
)
(
      input  logic                              clk_i
    , input  logic                              reset_i
    , input  logic                              clk250_i
    , input  logic                              clk250_reset_i

    , output logic                              tx_clk_o
    , input  logic                              tx_reset_i

    , output logic                              rx_clk_o
    , input  logic                              rx_reset_i

    // zynq-7000 specific: 200 MHZ for IDELAY tap value
    , input  logic                              iodelay_ref_clk_i

    , input  logic [addr_width_lp-1:0]          addr_i
    , input  logic                              write_en_i
    , input  logic                              read_en_i
    , input  logic [data_width_p/8-1:0]         write_mask_i
    , input  logic [data_width_p-1:0]           write_data_i
    , output logic [data_width_p-1:0]           read_data_o // sync read

    , output logic                              rx_interrupt_pending_o
    , output logic                              tx_interrupt_pending_o

    , input  logic                              rgmii_rx_clk_i
    , input  logic [3:0]                        rgmii_rxd_i
    , input  logic                              rgmii_rx_ctl_i
    , output logic                              rgmii_tx_clk_o
    , output logic [3:0]                        rgmii_txd_o
    , output logic                              rgmii_tx_ctl_o
);

  logic       reset_r_lo;
  logic [3:0] rgmii_rxd_delayed_lo;
  logic       rgmii_rx_ctl_delayed_lo;

  iodelay_control #(
     .simulation_p(simulation_p))
   iodelay_control (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.iodelay_ref_clk_i(iodelay_ref_clk_i)
    ,.rgmii_rxd_i(rgmii_rxd_i)
    ,.rgmii_rx_ctl_i(rgmii_rx_ctl_i)
    ,.rgmii_rxd_delayed_o(rgmii_rxd_delayed_lo)
    ,.rgmii_rx_ctl_delayed_o(rgmii_rx_ctl_delayed_lo)
  );

  ethernet_controller #(
     .data_width_p(data_width_p))
   eth_ctr (
    .clk_i
    ,.reset_i
    ,.clk250_i
    ,.clk250_reset_i
    ,.tx_clk_o(tx_clk_o)
    ,.tx_reset_i(tx_reset_i)
    ,.rx_clk_o(rx_clk_o)
    ,.rx_reset_i(rx_reset_i)

    ,.addr_i
    ,.write_en_i
    ,.read_en_i
    ,.write_mask_i
    ,.write_data_i
    ,.read_data_o // sync read

    ,.rx_interrupt_pending_o
    ,.tx_interrupt_pending_o

    ,.rgmii_rx_clk_i
    ,.rgmii_rxd_i(rgmii_rxd_delayed_lo)
    ,.rgmii_rx_ctl_i(rgmii_rx_ctl_delayed_lo)
    ,.rgmii_tx_clk_o
    ,.rgmii_txd_o
    ,.rgmii_tx_ctl_o
   );

endmodule

`BSG_ABSTRACT_MODULE(ethernet_controller_wrapper)
