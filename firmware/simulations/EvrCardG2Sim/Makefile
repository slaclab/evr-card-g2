# Define target output
target: gui

# Define Firmware Version Number
export PRJ_VERSION = CED20014

# Define target part
export PRJ_PART = XC7K70TFBG676-1

# Using a non-standard target directory structure, 
# which requires me to define the TOP_DIR path
export TOP_DIR = $(abspath $(PWD)/../..)

export REMOVE_UNUSED_CODE = 1

export TIMING_EXT_PKG = 1

# Use top level makefile
include $(TOP_DIR)/submodules/ruckus/system_vivado.mk

