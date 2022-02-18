# Set max delay for speed_reg sync under eth_mac_1g_rgmii_fifo
set src_inst [get_cells -hier -filter {(ORIG_REF_NAME == eth_mac_1g_rgmii || REF_NAME == eth_mac_1g_rgmii)}]
set dst_inst [get_cells -hier -filter {(ORIG_REF_NAME == eth_mac_1g_rgmii_fifo || REF_NAME == eth_mac_1g_rgmii_fifo)}]

set src_clk [get_clocks -of_objects [get_pins $src_inst/speed_reg_reg[0]/C]]
set dst_clk [get_clocks -of_objects [get_pins $dst_inst/speed_sync_reg_1_reg[0]/C]]
set min_period [expr min([get_property -min PERIOD $src_clk], [get_property -min PERIOD $dst_clk])]
set_max_delay -datapath_only -from [get_pins $src_inst/speed_reg_reg[0]/C] -to [get_pins $dst_inst/speed_sync_reg_1_reg[0]/D] $min_period
set_max_delay -datapath_only -from [get_pins $src_inst/speed_reg_reg[1]/C] -to [get_pins $dst_inst/speed_sync_reg_1_reg[1]/D] $min_period

# Set max delay for TX/RX debug info
set inst [get_cells -hier -filter {(ORIG_REF_NAME == eth_mac_1g_rgmii_fifo || REF_NAME == eth_mac_1g_rgmii_fifo)}]
set src_clk [get_clocks -of_objects [get_pins $inst/tx_sync_reg_1_reg[0]/C]]
set dst_clk [get_clocks -of_objects [get_pins $inst/tx_sync_reg_2_reg[0]/C]]
set min_period [expr min([get_property -min PERIOD $src_clk], [get_property -min PERIOD $dst_clk])]
set_max_delay -datapath_only -from [get_pins $inst/tx_sync_reg_1_reg[0]/C] -to [get_pins $inst/tx_sync_reg_2_reg[0]/D] $min_period
set_max_delay -datapath_only -from [get_pins $inst/rx_sync_reg_1_reg[0]/C] -to [get_pins $inst/rx_sync_reg_2_reg[0]/D] $min_period
set_max_delay -datapath_only -from [get_pins $inst/rx_sync_reg_1_reg[1]/C] -to [get_pins $inst/rx_sync_reg_2_reg[1]/D] $min_period
