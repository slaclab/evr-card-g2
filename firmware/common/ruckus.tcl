# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Core
loadRuckusTcl "$::DIR_PATH/EvrCardG2"
loadRuckusTcl "$::DIR_PATH/SsiPcieCore"
