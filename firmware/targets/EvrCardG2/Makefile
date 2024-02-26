export GIT_BYPASS = 1

# Define target output
target: prom

# Define RELEASE variable
export RELEASE = all

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
#export PRJ_VERSION = CED2001B
#  Add L2SI trigger support by default
#export PRJ_VERSION = CED2001C
#  Fix rate counting interval
#export PRJ_VERSION = CED2001D
#  Add reference clock output option
#export PRJ_VERSION = CED2001E
#  Add "PROM_VERSION" pull down resistor to FPGA.K21 pin
#export PRJ_VERSION = CED2001F
#  BITSTREAM.CONFIG.BPI_SYNC_MODE Disable because Type2 only supported for PC28 PROM. Not supported for MT28 PROM
#export PRJ_VERSION = CED20030
#  Custom PROM firmware for bypassing the CMD writes (required for MT28 PROM's Data Polling Register)
#  Also skipping to CED20030 due to "legacy" target having CED20025/CED20026 values with respect to software version checking in the PromLoader
#export PRJ_VERSION = CED20031
#  Add in TimingExtension decoding of L2SI DAQ for triggering.
#export PRJ_VERSION = CED20032
#  Validate evrBus.strobe with evrBus.valid.  Add DMA drop counter.
#  Match L2SI DAQ generated trigger timestamps to others
#  Auto compensate L2SI DAQ trigger delays for L0Delay
#export PRJ_VERSION = CED20033
# Put Evr core logic on application clock via ClockManager driven from timing clock
export PRJ_VERSION = CED20034
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
