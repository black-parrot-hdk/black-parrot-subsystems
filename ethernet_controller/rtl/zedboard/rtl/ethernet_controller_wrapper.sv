
`include "bsg_defines.v"

module ethernet_controller_wrapper #
(
      parameter  data_width_p  = 32
    , localparam addr_width_lp = 14
    , localparam size_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(data_width_p/8))
)
(
      input  logic                              clk_i
    , input  logic                              reset_i
    , input  logic                              clk250_i
    , output logic                              reset_clk125_o
    // zynq-7000 specific: 200 MHZ for IDELAY tap value
    , input  logic                              iodelay_ref_clk_i

    , input  logic [addr_width_lp-1:0]          addr_i
    , input  logic                              write_en_i
    , input  logic                              read_en_i
    , output logic                              ready_and_o
    , input  logic [size_width_lp-1:0]          op_size_i
    , input  logic [data_width_p-1:0]           write_data_i

    , output logic                              valid_o
    , input  logic                              ready_and_i
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

  bsg_dff #(.width_p(1))
    reset_reg (
      .clk_i(clk_i)
      ,.data_i(reset_i)
      ,.data_o(reset_r_lo)
      );
  iodelay_control iodelay_control(
    .clk_i(clk_i)
    ,.reset_r_i(reset_r_lo)
    ,.iodelay_ref_clk_i(iodelay_ref_clk_i)
    ,.rgmii_rxd_i(rgmii_rxd_i)
    ,.rgmii_rx_ctl_i(rgmii_rx_ctl_i)
    ,.rgmii_rxd_delayed_o(rgmii_rxd_delayed_lo)
    ,.rgmii_rx_ctl_delayed_o(rgmii_rx_ctl_delayed_lo)
  );

  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
  logic [3:0] reset_clk250_sync_r;

  // reset sync logic for clk250
  always @(posedge clk250_i or posedge reset_r_lo) begin
    if(reset_r_lo)
      reset_clk250_sync_r <= '1;
    else
      reset_clk250_sync_r <= {1'b0, reset_clk250_sync_r[3:1]};
  end
  wire reset_clk250_li  = reset_clk250_sync_r[0];

  ethernet_controller #(
     .data_width_p(data_width_p))
   eth_ctr (
    .clk_i
    ,.reset_i
    ,.clk250_i
    ,.reset_clk250_i(reset_clk250_li)
    ,.reset_clk125_o(reset_clk125_o)

    ,.addr_i
    ,.write_en_i
    ,.read_en_i
    ,.ready_and_o
    ,.op_size_i
    ,.write_data_i

    ,.valid_o
    ,.ready_and_i
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
