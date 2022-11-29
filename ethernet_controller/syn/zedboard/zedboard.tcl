
# Currently this contraint file is highly coupled with Zynq-parrot

###################### Clocks ######################
# clk250 -> clk125
set inst [get_cells -hier -filter {(ORIG_REF_NAME == tx_clks_generator || REF_NAME == tx_clks_generator)}]
create_generated_clock -name gtx_clk -source [get_pins {blackparrot_bd_1_i/processing_system7_0/inst/PS7_i/FCLKCLK[1]}] -divide_by 2 [get_pins $inst/gtx_clk_gen/clk_r_o_reg/Q]
# clk250 -> 90-degree shifted clk125 for rgmii TX clk source
create_generated_clock -name rgmii_tx_clk -source [get_pins {blackparrot_bd_1_i/processing_system7_0/inst/PS7_i/FCLKCLK[1]}] -edges {2 4 6} -edge_shift {0.000 0.000 0.000} [get_ports rgmii_tx_clk_o]
# RX clk source (125M)
create_clock -period 8.000 -name rgmii_rx_clk -waveform {0.000 4.000} [get_ports rgmii_rx_clk_i]

###################### Default max delay ######################
# Set default max delay between each async clock groups to 0 in order to catch unnoticed paths
# set_max_delay is used instead of set_clock_groups in order to have safer constraints
# Async groups:
# 1. clk_fpga_0(bp_clk)
# 2. clk_fpga_1 (clk250) (which generates gtx_clk, rgmii_tx_clk)
# 3. clk_fpga_2 (clk200 for iodelay ctl)
# 4. rgmii_rx_clk (from Ethernet PHY)
set_max_delay -from [get_clocks clk_fpga_0] -to [get_clocks {gtx_clk rgmii_tx_clk clk_fpga_1 clk_fpga_2 rgmii_rx_clk}] -datapath_only 0.0
set_max_delay -from [get_clocks gtx_clk] -to [get_clocks {clk_fpga_0 clk_fpga_2 rgmii_rx_clk}] -datapath_only 0.0
set_max_delay -from [get_clocks rgmii_tx_clk] -to [get_clocks {clk_fpga_0 clk_fpga_2 rgmii_rx_clk}] -datapath_only 0.0
set_max_delay -from [get_clocks clk_fpga_1] -to [get_clocks {clk_fpga_0 clk_fpga_2 rgmii_rx_clk}] -datapath_only 0.0
set_max_delay -from [get_clocks clk_fpga_2] -to [get_clocks {clk_fpga_0 gtx_clk rgmii_tx_clk clk_fpga_1 rgmii_rx_clk}] -datapath_only 0.0
set_max_delay -from [get_clocks rgmii_rx_clk] -to [get_clocks {clk_fpga_0 gtx_clk rgmii_tx_clk clk_fpga_1 clk_fpga_2}] -datapath_only 0.0

################# bsg_launch_sync_sync #################
foreach blss_inst [get_cells -hier -filter {(ORIG_REF_NAME == bsg_launch_sync_sync || REF_NAME == bsg_launch_sync_sync)}] {
  puts "blss_inst: $blss_inst"
  #foreach launch_reg [get_cells -regexp {$blss_inst/.*/bsg_SYNC_LNCH_r_reg\\[.*]}]
  foreach launch_reg [get_cells -regexp [format {%s/.*/bsg_SYNC_LNCH_r_reg\\[.*]} $blss_inst]] {
    # ASYNC_REG should have been applied in RTL
    regexp {([\w/.\[\]]+)/[\w]+\[([0-9]+)\]} $launch_reg -> path index

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

################# bsg_tag_client #################
foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == bsg_tag_client || REF_NAME == bsg_tag_client)}] {
    set source_cell [get_cells $inst/tag_data_reg/data_r_reg[0]]
    set dest_cell [get_cells $inst/recv/data_r_reg[0]]
    set write_clk [get_clocks -of_objects [get_pins $source_cell/C]]
    set read_clk [get_clocks -of_objects [get_pins $dest_cell/C]]
    set read_clk_period  [get_property -min PERIOD $read_clk]
    set write_clk_period [get_property -min PERIOD $write_clk]
    set min_clk_period [expr $read_clk_period < $write_clk_period ? $read_clk_period : $write_clk_period]
    set_max_delay -from $source_cell -to $dest_cell -datapath_only $min_clk_period
}

################# iodelay reset #################
# ASYNC_REG should have been applied in RTL
set inst [get_cells -hier -filter {(ORIG_REF_NAME == iodelay_control || REF_NAME == iodelay_control)}]
set dest_cell [get_cells $inst/nosim.reset_iodelay_sync/bsg_SYNC_1_r_reg[0]]
set_false_path -to [get_pins -of_objects $dest_cell -filter {IS_PRESET || IS_RESET}]
set dest_cell [get_cells $inst/nosim.reset_iodelay_sync/bsg_SYNC_2_r_reg[0]]
set_false_path -to [get_pins -of_objects $dest_cell -filter {IS_PRESET || IS_RESET}]

################# bsg_async_fifo #################
# Set max delay from write clock to read port in bsg_mem_1r1w in bsg_async_fifo
foreach fifo_inst [get_cells -hier -filter {(ORIG_REF_NAME == bsg_async_fifo || REF_NAME == bsg_async_fifo)}] {
    set write_clk [get_clocks -of_objects [get_pins $fifo_inst/bapg_wr/*/*/bsg_SYNC_LNCH_r_reg[0]/C]]
    set read_clk  [get_clocks -of_objects [get_pins $fifo_inst/bapg_rd/*/*/bsg_SYNC_LNCH_r_reg[0]/C]]
    set write_clk_period [get_property -min PERIOD $write_clk]
    set read_clk_period [get_property -min PERIOD $read_clk]
    set min_clk_period [expr $read_clk_period < $write_clk_period ? $read_clk_period : $write_clk_period]
    foreach ram_inst [get_cells $fifo_inst/MSYNC_1r1w/synth/nz.mem*/RAM*] {
        set_max_delay -from $write_clk -through [get_pins $ram_inst/O] $min_clk_period -datapath_only
    }
}

################# Input/Ouput delay #################
# Constant: 8ns
set CLK125_PERIOD 8

#
#    +--------------+              +--------------+
#    |              |              |              |      RGMII RX CLK
# ---+              +--------------+              +-----
#                _________      _________
#            XXXX__Data___XXXXXX___Data__XXXXX           RGMII RX Data/Control
#                <--|---->      <--|---->
#                BFE  AFE       BFE  AFE
#
# NOTE: According to RGMII timing spec,
#   the typical values of both RX_BFE_DELAY and RX_AFE_DELAY
#   are 2.0, but both can be as low as 1.2, which means both
#   of them should <= 1.2. However, it is hard to meet timing
#   on Zedboard if RX_AFE_DELAY is too low. Fortunately, the
#   Avnet Ethernet FMC module offers larger RX_AFE_DELAY.
# Set input delay for RX RGMII
set RX_BFE_DELAY 0.5
set RX_AFE_DELAY 1.8

set RX_MAX_DELAY [expr {$CLK125_PERIOD/2 - $RX_BFE_DELAY}]
set RX_MIN_DELAY $RX_AFE_DELAY

set_input_delay -clock [get_clocks rgmii_rx_clk] -max $RX_MAX_DELAY [get_ports rgmii_rxd*]
set_input_delay -clock [get_clocks rgmii_rx_clk] -min $RX_MIN_DELAY [get_ports rgmii_rxd*]
set_input_delay -clock [get_clocks rgmii_rx_clk] -clock_fall -max -add_delay $RX_MAX_DELAY [get_ports rgmii_rxd*]
set_input_delay -clock [get_clocks rgmii_rx_clk] -clock_fall -min -add_delay $RX_MIN_DELAY [get_ports rgmii_rxd*]

set_input_delay -clock [get_clocks rgmii_rx_clk] -max $RX_MAX_DELAY [get_ports rgmii_rx_ctl_i]
set_input_delay -clock [get_clocks rgmii_rx_clk] -min $RX_MIN_DELAY [get_ports rgmii_rx_ctl_i]
set_input_delay -clock [get_clocks rgmii_rx_clk] -clock_fall -max -add_delay $RX_MAX_DELAY [get_ports rgmii_rx_ctl_i]
set_input_delay -clock [get_clocks rgmii_rx_clk] -clock_fall -min -add_delay $RX_MIN_DELAY [get_ports rgmii_rx_ctl_i]

#    +--------------+              +--------------+
#    |              |              |              |      CLK
# ---+              +--------------+              +-----
#                _________      _________
#            XXXX__Data___XXXXXX___Data__XXXXX
#                <--|---->      <--|---->
#                BFE  AFE       BFE  AFE
# Set output delay for TX RGMII
# According to RGMII timing spec, both TX_BFE_DELAY and
#   TX_AFE_DELAY should >= 1.2
set TX_BFE_DELAY 1.6
set TX_AFE_DELAY 1.6

set TX_MAX_DELAY  $TX_BFE_DELAY
set TX_MIN_DELAY [expr -$TX_AFE_DELAY]

set_output_delay -clock [get_clocks rgmii_tx_clk] -max $TX_MAX_DELAY [get_ports rgmii_txd*]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min $TX_MIN_DELAY [get_ports rgmii_txd*]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -max -add_delay $TX_MAX_DELAY [get_ports rgmii_txd*]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -min -add_delay $TX_MIN_DELAY [get_ports rgmii_txd*]

set_output_delay -clock [get_clocks rgmii_tx_clk] -max $TX_MAX_DELAY [get_ports rgmii_tx_ctl_o]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min $TX_MIN_DELAY [get_ports rgmii_tx_ctl_o]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -max -add_delay $TX_MAX_DELAY [get_ports rgmii_tx_ctl_o]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -min -add_delay $TX_MIN_DELAY [get_ports rgmii_tx_ctl_o]

################# IOB packing #################
# Set IOB packing for TX RGMII outputs in order to help meet timing
set_property IOB TRUE [get_ports rgmii_tx_clk_o]
set_property IOB TRUE [get_ports rgmii_tx_ctl_o]
set_property IOB TRUE [get_ports rgmii_txd_o[0]]
set_property IOB TRUE [get_ports rgmii_txd_o[1]]
set_property IOB TRUE [get_ports rgmii_txd_o[2]]
set_property IOB TRUE [get_ports rgmii_txd_o[3]]

############# Ethernet reset path #############
set_false_path -to [get_ports eth_phy_resetn_o[0]]
