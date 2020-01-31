# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/surf"
loadRuckusTcl "$::DIR_PATH/lcls-timing-core"
loadRuckusTcl "$::DIR_PATH/l2si-core"
#loadRuckusTcl "$::DIR_PATH/../common/$::env(COMMON_FILE)"
