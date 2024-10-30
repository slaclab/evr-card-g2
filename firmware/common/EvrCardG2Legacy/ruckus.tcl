# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir  "$::DIR_PATH/general/rtl"
#loadIpCore -dir  "$::DIR_PATH/general/coregen"
loadSource -dir  "$::DIR_PATH/LCLS-I/rtl"
loadSource -dir  "$::DIR_PATH/pci/rtl"
loadIpCore -dir  "$::DIR_PATH/pci/coregen"
loadSource -path "$::DIR_PATH/../EvrCardG2/general/rtl/BpiPromCore.vhd"
loadSource -path "$::DIR_PATH/../EvrCardG2/general/rtl/BpiPromReg.vhd"
