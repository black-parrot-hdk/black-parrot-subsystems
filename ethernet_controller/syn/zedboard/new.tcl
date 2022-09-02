# clk250 -> clk125
set inst [get_cells -hier -filter {(ORIG_REF_NAME == gtx_clk_and_phy_tx_clk_generator || REF_NAME == gtx_clk_and_phy_tx_clk_generator)}]
create_generated_clock -name gtx_clk -source [get_pins {blackparrot_bd_1_i/processing_system7_0/inst/PS7_i/FCLKCLK[1]}] -divide_by 2 [get_pins $inst/gtx_clk_gen/clk_r_o_reg/Q]
# clk250 -> 90-degree shifted clk125 for rgmii TX clk source
create_generated_clock -name rgmii_tx_clk -source [get_pins {blackparrot_bd_1_i/processing_system7_0/inst/PS7_i/FCLKCLK[1]}] -edges {2 4 6} -edge_shift {0.000 0.000 0.000} [get_ports rgmii_tx_clk_o]
# RX clk source (125M)
create_clock -period 8.000 -name rgmii_rx_clk -waveform {0.000 4.000} [get_ports rgmii_rx_clk_i]

# TODO: look for the bsg_launch_sync_sync module instead
foreach blss_inst [get_cells -hier -filter {(ORIG_REF_NAME == bsg_launch_sync_sync || REF_NAME == bsg_launch_sync_sync)}] {
  puts "blss_inst: $blss_inst"
  #foreach launch_reg [get_cells -regexp {$blss_inst/.*/bsg_SYNC_LNCH_r_reg\\[.*]}]
  foreach launch_reg [get_cells -regexp [format {%s/.*/bsg_SYNC_LNCH_r_reg\\[.*]} $blss_inst]] {
    # Put ASYNC_REG on all three flops:
    regexp {([\w/.\[\]]+)/[\w]+\[([0-9]+)\]} $launch_reg -> path index
    set_property ASYNC_REG TRUE [get_cells $path/bsg_SYNC_LNCH_r_reg[$index]]
    set_property ASYNC_REG TRUE [get_cells $path/bsg_SYNC_1_r_reg[$index]]
    set_property ASYNC_REG TRUE [get_cells $path/bsg_SYNC_2_r_reg[$index]]
    
    set source_cell [get_cells $path/bsg_SYNC_LNCH_r_reg[$index]]
    set dest_cell  [get_cells $path/bsg_SYNC_1_r_reg[$index]]
    set write_clk [get_clocks -of_objects [get_pins $source_cell/C]]
    set read_clk [get_clocks -of_objects [get_pins $dest_cell/C]]
    set read_clk_period  [get_property -min PERIOD $read_clk]
    set write_clk_period [get_property -min PERIOD $write_clk]
    set min_clk_period [expr $read_clk_period < $write_clk_period ? $read_clk_period : $write_clk_period]
    # max delay between launch flop and sync_1 flop
    set_max_delay -from $source_cell -to $dest_cell -datapath_only $min_clk_period
  }
}

if {0} {
foreach async_reset_inst [get_cells -hier -filter {(ORIG_REF_NAME == arst_sync || REF_NAME == arst_sync)}] {
    set_property ASYNC_REG TRUE [get_cells $async_reset_inst/bsg_SYNC_LNCH_1_reg[0]]
    set_property ASYNC_REG TRUE [get_cells $async_reset_inst/bsg_SYNC_LNCH_2_reg[0]]
}
# TODO: RX_MAX_DELAY: 2.8 RX_MIN_DELAY: 1.2
# Set input delay for RX RGMII
set RX_MAX_DELAY 3.500
set RX_MIN_DELAY 1.800

set_input_delay -clock [get_clocks rgmii_rx_clk] -max $RX_MAX_DELAY [get_ports rgmii_rxd*]
set_input_delay -clock [get_clocks rgmii_rx_clk] -min $RX_MIN_DELAY [get_ports rgmii_rxd*]
set_input_delay -clock [get_clocks rgmii_rx_clk] -clock_fall -max -add_delay $RX_MAX_DELAY [get_ports rgmii_rxd*]
set_input_delay -clock [get_clocks rgmii_rx_clk] -clock_fall -min -add_delay $RX_MIN_DELAY [get_ports rgmii_rxd*]

set_input_delay -clock [get_clocks rgmii_rx_clk] -max $RX_MAX_DELAY [get_ports rgmii_rx_ctl_i]
set_input_delay -clock [get_clocks rgmii_rx_clk] -min $RX_MIN_DELAY [get_ports rgmii_rx_ctl_i]
set_input_delay -clock [get_clocks rgmii_rx_clk] -clock_fall -max -add_delay $RX_MAX_DELAY [get_ports rgmii_rx_ctl_i]
set_input_delay -clock [get_clocks rgmii_rx_clk] -clock_fall -min -add_delay $RX_MIN_DELAY [get_ports rgmii_rx_ctl_i]

# Set output delay for TX RGMII 
set TX_MAX_DELAY  1.600
set TX_MIN_DELAY -1.600

set_output_delay -clock [get_clocks rgmii_tx_clk] -max $TX_MAX_DELAY [get_ports rgmii_txd*]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min $TX_MIN_DELAY [get_ports rgmii_txd*]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -max -add_delay $TX_MAX_DELAY [get_ports rgmii_txd*]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -min -add_delay $TX_MIN_DELAY [get_ports rgmii_txd*]

set_output_delay -clock [get_clocks rgmii_tx_clk] -max $TX_MAX_DELAY [get_ports rgmii_tx_ctl_o]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min $TX_MIN_DELAY [get_ports rgmii_tx_ctl_o]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -max -add_delay $TX_MAX_DELAY [get_ports rgmii_tx_ctl_o]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -min -add_delay $TX_MIN_DELAY [get_ports rgmii_tx_ctl_o]

# Set IOB packing for TX RGMII outputs in order to help meet timing
set_property IOB TRUE [get_ports rgmii_tx_clk_o]
set_property IOB TRUE [get_ports rgmii_tx_ctl_o]
set_property IOB TRUE [get_ports rgmii_txd_o[0]]
set_property IOB TRUE [get_ports rgmii_txd_o[1]]
set_property IOB TRUE [get_ports rgmii_txd_o[2]]
set_property IOB TRUE [get_ports rgmii_txd_o[3]]
}
