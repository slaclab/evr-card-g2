export GIT_BYPASS = 1

# Define target output
target: prom

# Define Firmware Version Number
#export PRJ_VERSION = CED20015
#  EvrV2BsaChannel tags with channel mask rather than channel int
#  EvrV2BsaControl adds PID into message
#  EvrV2Core : Add 2 soft channels
#  Add EvrV2Reg module (interrupt and full management)
#  Add EvrV2BsaChannelSummary : 
#  Remove EvrV2Axi, EvrV2TrigReg
#  Add EvrV2TriggerReg : register management for trigger outputs
#  Add EvrV2ChannelReg : register management for channel event selection
#export PRJ_VERSION = CED20016
#  Add DRP bus
#export PRJ_VERSION = CED20017
#  Add DAQ trigger bits
#export PRJ_VERSION = CED20018
#  Add EvrV2TriggerCompl for standby triggers
#export PRJ_VERSION = CED20019
#  Add timing clockSelect/modeSelect distinction
#export PRJ_VERSION = CED2001A
#  Fix modesel and delayTap
export PRJ_VERSION = CED2001B

# Define target part
export PRJ_PART = XC7K70TFBG676-1

export COMMON_FILE = 

export REMOVE_UNUSED_CODE = 1

export TIMING_EXT_PKG = 1

# Using a non-standard target directory structure, 
# which requires me to define the TOP_DIR path
export TOP_DIR = $(abspath $(PWD)/../..)

# Use top level makefile
include $(TOP_DIR)/submodules/ruckus/system_vivado.mk
