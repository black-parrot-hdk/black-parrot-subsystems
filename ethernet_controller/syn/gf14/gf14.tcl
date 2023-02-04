puts "BSG-info: Running script [info script]\n"

#set_app_var sh_continue_on_error false
#error "Let's stop here for a while"

########################################
## Source common scripts
source -echo -verbose $::env(BSG_DESIGNS_TARGET_TCL_DIR)/common/bsg_chip_misc.tcl

########################################
## App Var Setup

# Needed for automatic clock-gate insertions
set_app_var case_analysis_propagate_through_icg true


###################### Clocks ######################

set usr_clk_period_ps 1000
set usr_clk_uncertainty_per 3.0
set usr_clk_uncertainty_ps  [expr min([expr ${usr_clk_period_ps}*(${usr_clk_uncertainty_per}/100.0)], 20)]

set clk250_uncertainty_per 3.0
set clk250_uncertainty_ps  [expr min([expr 4000*(${clk250_uncertainty_per}/100.0)], 20)]

set rgmii_rx_clk_uncertainty_per 3.0
set rgmii_rx_clk_uncertainty_ps  [expr min([expr 8000*(${rgmii_rx_clk_uncertainty_per}/100.0)], 20)]

set gtx_clk_uncertainty_per 3.0
set gtx_clk_uncertainty_ps  [expr min([expr 8000*(${gtx_clk_uncertainty_per}/100.0)], 20)]

# clk250, usr_clk, rgmii_rx_clk, rgmii_tx_clk, gtx_clk
# CLK250 (250 MHZ)
create_clock -period 4000 -name clk250 [get_ports clk250_i]
# User logic (1 GHZ)
create_clock -period ${usr_clk_period_ps} -name usr_clk [get_ports clk_i]
# RGMII RX CLK (125 MHZ)
create_clock -period 8000 -name rgmii_rx_clk [get_ports rgmii_rx_clk_i]

# Generated clocks from clk250: gtx_clk (for DDR data) 
create_generated_clock -name gtx_clk -source [get_ports clk250_i] -divide_by 2 [get_pins mac/eth_mac_1g_rgmii_inst/rgmii_phy_if_inst/tx_clks_gen/gtx_clk_gen/clk_r_o_reg/Q]
# Generated clocks from clk250: rgmii_tx_clk (for DDR clock)
create_generated_clock -name rgmii_tx_clk -source [get_ports clk250_i] -edges {2 4 6} -edge_shift {0.000 0.000 0.000} [get_ports rgmii_tx_clk_o]

# Clock Uncertainty
#set_clock_uncertainty ${usr_clk_uncertainty_ps} [get_clocks usr_clk]
#set_clock_uncertainty ${clk250_uncertainty_ps} [get_clocks clk250]
#set_clock_uncertainty ${rgmii_rx_clk_uncertainty_ps} [get_clocks rgmii_rx_clk]
#set_clock_uncertainty ${gtx_clk_uncertainty_ps} [get_clocks gtx_clk]

set clock_jitter 20.0
set extra_margin 20.0

# The values are based on the clock qor report from pnr
set_clock_uncertainty [expr 30 + ${clock_jitter} + ${extra_margin}] -setup [get_clocks usr_clk]
set_clock_uncertainty [expr 30 + ${extra_margin}]                -hold  [get_clocks usr_clk]
set_clock_uncertainty [expr 60 + ${clock_jitter} + ${extra_margin}] -setup [get_clocks clk250]
set_clock_uncertainty [expr 40 + ${extra_margin}]                -hold  [get_clocks clk250]
set_clock_uncertainty [expr 30 + ${clock_jitter} + ${extra_margin}] -setup [get_clocks rgmii_rx_clk]
set_clock_uncertainty [expr 40 + ${extra_margin}]                -hold  [get_clocks rgmii_rx_clk]
set_clock_uncertainty [expr 40 + ${clock_jitter} + ${extra_margin}] -setup [get_clocks gtx_clk]
set_clock_uncertainty [expr 40 + ${extra_margin}]                -hold  [get_clocks gtx_clk]
#set_clock_uncertainty [expr ${clock_jitter} + ${extra_margin}] -setup [get_clocks usr_clk]
#set_clock_uncertainty [expr ${extra_margin}]                -hold  [get_clocks usr_clk]
#set_clock_uncertainty [expr ${clock_jitter} + ${extra_margin}] -setup [get_clocks clk250]
#set_clock_uncertainty [expr ${extra_margin}]                -hold  [get_clocks clk250]
#set_clock_uncertainty [expr ${clock_jitter} + ${extra_margin}] -setup [get_clocks rgmii_rx_clk]
#set_clock_uncertainty [expr ${extra_margin}]                -hold  [get_clocks rgmii_rx_clk]
#set_clock_uncertainty [expr ${clock_jitter} + ${extra_margin}] -setup [get_clocks gtx_clk]
#set_clock_uncertainty [expr ${extra_margin}]                -hold  [get_clocks gtx_clk]

# No clock uncertainty for rgmii_tx_clk

###################### Set Input Delay ######################

# Make input min delay so large that even with zero network propagation delay at input ports is fine
set input_delay_min_per 30.0
set input_delay_max_per 70.0
set usr_clk_input_delay_min_ps  [expr ${usr_clk_period_ps}*(${input_delay_min_per}/100.0)]
set usr_clk_input_delay_max_ps  [expr ${usr_clk_period_ps}*(${input_delay_max_per}/100.0)]
set clk250_input_delay_min_ps  [expr 4000*(${input_delay_min_per}/100.0)]
set clk250_input_delay_max_ps  [expr 4000*(${input_delay_max_per}/100.0)]
set tx_clk_input_delay_min_ps  [expr 8000*(${input_delay_min_per}/100.0)]
set tx_clk_input_delay_max_ps  [expr 8000*(${input_delay_max_per}/100.0)]
set rx_clk_input_delay_min_ps  [expr 8000*(${input_delay_min_per}/100.0)]
set rx_clk_input_delay_max_ps  [expr 8000*(${input_delay_max_per}/100.0)]


set usr_inputs {reset_i addr_i write_en_i read_en_i write_mask_i write_data_i}
set_input_delay -network_latency_included -min ${usr_clk_input_delay_min_ps} -clock usr_clk ${usr_inputs}
set_input_delay -network_latency_included -max ${usr_clk_input_delay_max_ps} -clock usr_clk ${usr_inputs}
set_input_delay -network_latency_included -min ${clk250_input_delay_min_ps} -clock clk250 {clk250_reset_i tx_clk_gen_reset_i}
set_input_delay -network_latency_included -max ${clk250_input_delay_max_ps} -clock clk250 {clk250_reset_i tx_clk_gen_reset_i}
set_input_delay -network_latency_included -min ${tx_clk_input_delay_min_ps} -clock gtx_clk {tx_reset_i}
set_input_delay -network_latency_included -max ${tx_clk_input_delay_max_ps} -clock gtx_clk {tx_reset_i}
set_input_delay -network_latency_included -min ${rx_clk_input_delay_min_ps} -clock rgmii_rx_clk {rx_reset_i}
set_input_delay -network_latency_included -max ${rx_clk_input_delay_max_ps} -clock rgmii_rx_clk {rx_reset_i}

set_driving_cell -min -no_design_rule -lib_cell $LIB_CELLS(invx2) [all_inputs]
set_driving_cell -max -no_design_rule -lib_cell $LIB_CELLS(invx8) [all_inputs]


###################### Set Output Delay ######################

set output_delay_min_per 2.0
set output_delay_max_per 20.0
set output_delay_min_ps  [expr (-1)*${usr_clk_period_ps}*(${output_delay_min_per}/100.0)]
set output_delay_max_ps  [expr ${usr_clk_period_ps}*(${output_delay_max_per}/100.0)]

set usr_outputs {read_data_o rx_interrupt_pending_o tx_interrupt_pending_o}
set_output_delay -network_latency_included -min ${output_delay_min_ps} -clock usr_clk ${usr_outputs}
set_output_delay -network_latency_included -max ${output_delay_max_ps} -clock usr_clk ${usr_outputs}

set_load -min [load_of [get_lib_pin */$LIB_CELLS(invx2,load_pin)]] [all_outputs]
set_load -max [load_of [get_lib_pin */$LIB_CELLS(invx8,load_pin)]] [all_outputs]


###################### Default max delay ######################
# Set default max delay between each async clock groups to 0 in order to catch unnoticed paths
# set_max_delay is used instead of set_clock_groups in order to have safer constraints
# Async groups:
# 1. usr_clk
# 2. clk250 (which generates gtx_clk, rgmii_tx_clk)
# 3. rgmii_rx_clk (from Ethernet PHY)
set_clock_groups -asynchronous -allow_paths -name g1 -group {clk250 gtx_clk rgmii_tx_clk} -group {rgmii_rx_clk} -group {usr_clk}

set_max_delay -from [get_clocks usr_clk] -to [get_clocks {gtx_clk rgmii_tx_clk clk250 rgmii_rx_clk}] -ignore_clock_latency 0.0
set_max_delay -from [get_clocks gtx_clk] -to [get_clocks {usr_clk rgmii_rx_clk}] -ignore_clock_latency 0.0
set_max_delay -from [get_clocks rgmii_tx_clk] -to [get_clocks {usr_clk rgmii_rx_clk}] -ignore_clock_latency 0.0
set_max_delay -from [get_clocks clk250] -to [get_clocks {usr_clk rgmii_rx_clk}] -ignore_clock_latency 0.0
set_max_delay -from [get_clocks rgmii_rx_clk] -to [get_clocks {usr_clk gtx_clk rgmii_tx_clk clk250}] -ignore_clock_latency 0.0

################# bsg_launch_sync_sync #################

foreach inst [get_object_name [get_cells -hier -filter {hdl_template == bsg_launch_sync_sync}]] {
  set_boundary_optimization [get_cells $inst] false
  foreach launch_reg [get_object_name [get_cells -regexp [format {%s/.*/bsg_SYNC_LNCH_r_reg\\[.*]} $inst]]] {
    regexp {([\w/.\[\]]+)/[\w]+\[([0-9]+)\]} $launch_reg -> path index
    set source_cell [get_cells $path/bsg_SYNC_LNCH_r_reg[$index]]
    set dest_cell  [get_cells $path/genblk1[$index].hard_sync_int]
    # max delay between launch flop and sync_1 flop
    # Some random small limit is applied. As long as the RP groups work, this constraint is not really necessary
    # TODO: use set_max_delay
#    set_max_delay -from $source_cell -to $dest_cell -ignore_clock_latency 200.0
    set_false_path -from $source_cell -to $dest_cell
#    set_false_path -hold -from $source_cell -to $dest_cell
  }
}

################# bsg_async_fifo #################
# Set false path from write clock port to read data in bsg_mem_1r1w in bsg_async_fifo
#foreach fifo_inst [get_object_name [get_cells -hier -filter {hdl_template == bsg_async_fifo}]] {
#  set_false_path -from $fifo_inst/MSYNC_1r1w/synth/w_clk_i -to $fifo_inst/MSYNC_1r1w/synth/r_data_o
#}
set_false_path -from usr_clk -through mac/tx_fifo/fifo_inst/cdc/MSYNC_1r1w/synth/r_data_o 
set_false_path -from rgmii_rx_clk -through mac/rx_fifo/fifo_inst/cdc/MSYNC_1r1w/synth/r_data_o

################# Input/Ouput delay #################
# Constant: 8ns
set CLK125_PERIOD 8000

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
set RX_BFE_DELAY 500
set RX_AFE_DELAY 1200

set RX_MAX_DELAY [expr {$CLK125_PERIOD/2 - $RX_BFE_DELAY}]
set RX_MIN_DELAY $RX_AFE_DELAY

set_input_delay -network_latency_included -clock [get_clocks rgmii_rx_clk] -max $RX_MAX_DELAY [get_ports rgmii_rxd*]
set_input_delay -network_latency_included -clock [get_clocks rgmii_rx_clk] -min $RX_MIN_DELAY [get_ports rgmii_rxd*]
set_input_delay -network_latency_included -clock [get_clocks rgmii_rx_clk] -clock_fall -max -add_delay $RX_MAX_DELAY [get_ports rgmii_rxd*]
set_input_delay -network_latency_included -clock [get_clocks rgmii_rx_clk] -clock_fall -min -add_delay $RX_MIN_DELAY [get_ports rgmii_rxd*]

set_input_delay -network_latency_included -clock [get_clocks rgmii_rx_clk] -max $RX_MAX_DELAY [get_ports rgmii_rx_ctl_i]
set_input_delay -network_latency_included -clock [get_clocks rgmii_rx_clk] -min $RX_MIN_DELAY [get_ports rgmii_rx_ctl_i]
set_input_delay -network_latency_included -clock [get_clocks rgmii_rx_clk] -clock_fall -max -add_delay $RX_MAX_DELAY [get_ports rgmii_rx_ctl_i]
set_input_delay -network_latency_included -clock [get_clocks rgmii_rx_clk] -clock_fall -min -add_delay $RX_MIN_DELAY [get_ports rgmii_rx_ctl_i]

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
set TX_BFE_DELAY 1600
set TX_AFE_DELAY 1600

set TX_MAX_DELAY  $TX_BFE_DELAY
set TX_MIN_DELAY [expr -$TX_AFE_DELAY]
# TODO: Add -source_latency_included?
set_output_delay -network_latency_included -clock [get_clocks rgmii_tx_clk] -max $TX_MAX_DELAY [get_ports rgmii_txd*]
set_output_delay -network_latency_included -clock [get_clocks rgmii_tx_clk] -min $TX_MIN_DELAY [get_ports rgmii_txd*]
set_output_delay -network_latency_included -clock [get_clocks rgmii_tx_clk] -clock_fall -max -add_delay $TX_MAX_DELAY [get_ports rgmii_txd*]
set_output_delay -network_latency_included -clock [get_clocks rgmii_tx_clk] -clock_fall -min -add_delay $TX_MIN_DELAY [get_ports rgmii_txd*]
                                         
set_output_delay -network_latency_included -clock [get_clocks rgmii_tx_clk] -max $TX_MAX_DELAY [get_ports rgmii_tx_ctl_o]
set_output_delay -network_latency_included -clock [get_clocks rgmii_tx_clk] -min $TX_MIN_DELAY [get_ports rgmii_tx_ctl_o]
set_output_delay -network_latency_included -clock [get_clocks rgmii_tx_clk] -clock_fall -max -add_delay $TX_MAX_DELAY [get_ports rgmii_tx_ctl_o]
set_output_delay -network_latency_included -clock [get_clocks rgmii_tx_clk] -clock_fall -min -add_delay $TX_MIN_DELAY [get_ports rgmii_tx_ctl_o]

#set_timing_derate -cell_delay -early 0.95
#set_timing_derate -cell_delay -late 1.05

set_max_transition -data_path 75 [all_clocks]

puts "BSG-info: Completed script [info script]\n"

