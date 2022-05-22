
# Set false paths for clk250 reset sync chain
set inst [get_cells -hier -filter {(ORIG_REF_NAME == ethernet_controller_wrapper || REF_NAME == ethernet_controller_wrapper)}]
set reset_ffs [get_cells -hier -regexp ".*/reset_clk250_sync_r_reg\\\[\\d\\\]" -filter "PARENT == $inst"]
set_false_path -to [get_pins -of_objects $reset_ffs -filter {IS_PRESET || IS_RESET}]


# Set false paths for idelayctrl reset sync chain
set inst [get_cells -hier -filter {(ORIG_REF_NAME == iodelay_control || REF_NAME == iodelay_control)}]
set reset_ffs [get_cells -hier -regexp ".*/reset_iodelay_sync_r_reg\\\[\\d\\\]" -filter "PARENT == $inst"]
set_false_path -to [get_pins -of_objects $reset_ffs -filter {IS_PRESET || IS_RESET}]
