
# Define target output
target: prom

# Define target part
export PRJ_PART = XC7K70TFBG676-1

# List of build core directories.
export MODULE_DIRS = $(PROJ_DIR)/../../modules/StdLib \
                     $(PROJ_DIR)/../../modules/SsiPcieCore \
                     $(PROJ_DIR)/../../modules/MgtLib/gtx7 \
                     $(PROJ_DIR)/../../modules/TimingCore/LCLS-I \
                     $(PROJ_DIR)/../../modules/TimingCore/LCLS-II/core \
                     $(PROJ_DIR)/../../modules/common/general \
                     $(PROJ_DIR)/../../modules/common/LCLS-I \
                     $(PROJ_DIR)/../../modules/common/LCLS-II \
                     $(PROJ_DIR)/../../modules/common/pci \
                     $(PROJ_DIR)/../../modules/AxiMicronP30Core \
                     $(PROJ_DIR)/../../modules/AxiSy56040Core \
                     $(PROJ_DIR)/../../modules/AxiXadcMinimumCore \
                     $(PROJ_DIR)

# Use top level makefile
include ../../modules/StdLib/build/system_vivado_v1.mk
