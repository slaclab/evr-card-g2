# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for version 2016.4 of Vivado
if { [VersionCheck 2016.4] < 0 } {
   close_project
   exit -1
}

# Load ruckus files
#loadRuckusTcl $::DIR_PATH/submodules/surf
#loadRuckusTcl $::DIR_PATH/submodules/lcls-timing-core
loadRuckusTcl /u1/weaver/surf
loadRuckusTcl /u1/weaver/lcls-timing-core

loadRuckusTcl "$::DIR_PATH/common"
