##############################################################################
## This file is part of 'SLAC EVR Gen2'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC EVR Gen2', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
# I/O Port Mapping

set_property -dict { PACKAGE_PIN B24 IOSTANDARD LVCMOS25 } [get_ports { flashData[0] }]
set_property -dict { PACKAGE_PIN A25 IOSTANDARD LVCMOS25 } [get_ports { flashData[1] }]
set_property -dict { PACKAGE_PIN B22 IOSTANDARD LVCMOS25 } [get_ports { flashData[2] }]
set_property -dict { PACKAGE_PIN A22 IOSTANDARD LVCMOS25 } [get_ports { flashData[3] }]
set_property -dict { PACKAGE_PIN A23 IOSTANDARD LVCMOS25 } [get_ports { flashData[4] }]
set_property -dict { PACKAGE_PIN A24 IOSTANDARD LVCMOS25 } [get_ports { flashData[5] }]
set_property -dict { PACKAGE_PIN D26 IOSTANDARD LVCMOS25 } [get_ports { flashData[6] }]
set_property -dict { PACKAGE_PIN C26 IOSTANDARD LVCMOS25 } [get_ports { flashData[7] }]
set_property -dict { PACKAGE_PIN C24 IOSTANDARD LVCMOS25 } [get_ports { flashData[8] }]
set_property -dict { PACKAGE_PIN D21 IOSTANDARD LVCMOS25 } [get_ports { flashData[9] }]
set_property -dict { PACKAGE_PIN C22 IOSTANDARD LVCMOS25 } [get_ports { flashData[10] }]
set_property -dict { PACKAGE_PIN B20 IOSTANDARD LVCMOS25 } [get_ports { flashData[11] }]
set_property -dict { PACKAGE_PIN A20 IOSTANDARD LVCMOS25 } [get_ports { flashData[12] }]
set_property -dict { PACKAGE_PIN E22 IOSTANDARD LVCMOS25 } [get_ports { flashData[13] }]
set_property -dict { PACKAGE_PIN C21 IOSTANDARD LVCMOS25 } [get_ports { flashData[14] }]
set_property -dict { PACKAGE_PIN B21 IOSTANDARD LVCMOS25 } [get_ports { flashData[15] }]

set_property -dict { PACKAGE_PIN J23 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[0] }]
set_property -dict { PACKAGE_PIN K23 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[1] }]
set_property -dict { PACKAGE_PIN K22 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[2] }]
set_property -dict { PACKAGE_PIN L22 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[3] }]
set_property -dict { PACKAGE_PIN J25 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[4] }]
set_property -dict { PACKAGE_PIN J24 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[5] }]
set_property -dict { PACKAGE_PIN H22 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[6] }]
set_property -dict { PACKAGE_PIN H24 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[7] }]
set_property -dict { PACKAGE_PIN H23 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[8] }]
set_property -dict { PACKAGE_PIN G21 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[9] }]
set_property -dict { PACKAGE_PIN H21 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[10] }]
set_property -dict { PACKAGE_PIN H26 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[11] }]
set_property -dict { PACKAGE_PIN J26 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[12] }]
set_property -dict { PACKAGE_PIN E26 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[13] }]
set_property -dict { PACKAGE_PIN F25 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[14] }]
set_property -dict { PACKAGE_PIN G26 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[15] }]
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[16] }]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[17] }]
set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[18] }]
set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[19] }]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[20] }]
set_property -dict { PACKAGE_PIN J20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[21] }]
set_property -dict { PACKAGE_PIN K20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[22] }]
set_property -dict { PACKAGE_PIN G20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[23] }]

# set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS25 } [get_ports { flashRs[0] }]
# set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS25 } [get_ports { flashRs[1] }]

set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS25 } [get_ports { flashWait }]
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS25 } [get_ports { flashAdv }]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS25 } [get_ports { flashWe }]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS25 } [get_ports { flashOe }]
set_property -dict { PACKAGE_PIN C23 IOSTANDARD LVCMOS25 } [get_ports { flashCe }]

set_property -dict { PACKAGE_PIN E23 IOSTANDARD LVCMOS25 } [get_ports { testPoint }]

set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS25 } [get_ports { xBarSin[0] }]
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS25 } [get_ports { xBarSin[1] }]
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS25 } [get_ports { xBarSout[0] }]
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS25 } [get_ports { xBarSout[1] }]
set_property -dict { PACKAGE_PIN A19 IOSTANDARD LVCMOS25 } [get_ports { xBarConfig }]
set_property -dict { PACKAGE_PIN B17 IOSTANDARD LVCMOS25 } [get_ports { xBarLoad }]

set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports { ledRedL[0] }]
set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS33 } [get_ports { ledRedL[1] }]
set_property -dict { PACKAGE_PIN A9 IOSTANDARD LVCMOS33 } [get_ports { ledBlueL[0] }]
set_property -dict { PACKAGE_PIN A8 IOSTANDARD LVCMOS33 } [get_ports { ledBlueL[1] }]
set_property -dict { PACKAGE_PIN C9 IOSTANDARD LVCMOS33 } [get_ports { ledGreenL[0] }]
set_property -dict { PACKAGE_PIN B9 IOSTANDARD LVCMOS33 } [get_ports { ledGreenL[1] }]

set_property -dict { PACKAGE_PIN E10 IOSTANDARD LVCMOS33 } [get_ports { syncL }]

set_property -dict { PACKAGE_PIN C13 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[0] }]
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[1] }]
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[2] }]
set_property -dict { PACKAGE_PIN B14 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[3] }]
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[4] }]
set_property -dict { PACKAGE_PIN B10 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[5] }]
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[6] }]
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[7] }]
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[8] }]
set_property -dict { PACKAGE_PIN A13 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[9] }]
set_property -dict { PACKAGE_PIN A12 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[10] }]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports { trigOut[11] }]

set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { debugIn[0] }]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports { debugIn[1] }]
set_property -dict { PACKAGE_PIN E11 IOSTANDARD LVCMOS33 } [get_ports { debugIn[2] }]
set_property -dict { PACKAGE_PIN D11 IOSTANDARD LVCMOS33 } [get_ports { debugIn[3] }]
set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33 } [get_ports { debugIn[4] }]
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports { debugIn[5] }]
set_property -dict { PACKAGE_PIN G12 IOSTANDARD LVCMOS33 } [get_ports { debugIn[6] }]
set_property -dict { PACKAGE_PIN F12 IOSTANDARD LVCMOS33 } [get_ports { debugIn[7] }]
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports { debugIn[8] }]
set_property -dict { PACKAGE_PIN D13 IOSTANDARD LVCMOS33 } [get_ports { debugIn[9] }]
set_property -dict { PACKAGE_PIN E13 IOSTANDARD LVCMOS33 } [get_ports { debugIn[10] }]
set_property -dict { PACKAGE_PIN E12 IOSTANDARD LVCMOS33 } [get_ports { debugIn[11] }]

set_property PACKAGE_PIN F2 [get_ports pciTxP[3]]
set_property PACKAGE_PIN F1 [get_ports pciTxN[3]]
set_property PACKAGE_PIN G4 [get_ports pciRxP[3]]
set_property PACKAGE_PIN G3 [get_ports pciRxN[3]]

set_property PACKAGE_PIN D2 [get_ports pciTxP[2]]
set_property PACKAGE_PIN D1 [get_ports pciTxN[2]]
set_property PACKAGE_PIN E4 [get_ports pciRxP[2]]
set_property PACKAGE_PIN E3 [get_ports pciRxN[2]]

set_property PACKAGE_PIN B2 [get_ports pciTxP[1]]
set_property PACKAGE_PIN B1 [get_ports pciTxN[1]]
set_property PACKAGE_PIN C4 [get_ports pciRxP[1]]
set_property PACKAGE_PIN C3 [get_ports pciRxN[1]]

set_property PACKAGE_PIN A4 [get_ports pciTxP[0]]
set_property PACKAGE_PIN A3 [get_ports pciTxN[0]]
set_property PACKAGE_PIN B6 [get_ports pciRxP[0]]
set_property PACKAGE_PIN B5 [get_ports pciRxN[0]]

set_property PACKAGE_PIN D6  [get_ports pciRefClkP]
set_property PACKAGE_PIN D5  [get_ports pciRefClkN]

set_property -dict { PACKAGE_PIN J8 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pciRstL }]
set_false_path -from [get_ports pciRstL]

set_property PACKAGE_PIN P2 [get_ports evrTxP[0]]
set_property PACKAGE_PIN P1 [get_ports evrTxN[0]]
set_property PACKAGE_PIN R4 [get_ports evrRxP[0]]
set_property PACKAGE_PIN R3 [get_ports evrRxN[0]]

set_property PACKAGE_PIN M2 [get_ports evrTxP[1]]
set_property PACKAGE_PIN M1 [get_ports evrTxN[1]]
set_property PACKAGE_PIN N4 [get_ports evrRxP[1]]
set_property PACKAGE_PIN N3 [get_ports evrRxN[1]]

set_property PACKAGE_PIN H6 [get_ports evrRefClkP[0]]
set_property PACKAGE_PIN H5 [get_ports evrRefClkN[0]]

set_property PACKAGE_PIN K6 [get_ports evrRefClkP[1]]
set_property PACKAGE_PIN K5 [get_ports evrRefClkN[1]]

#  Locate all trigger delay logic close to IOB
#  trigOut[0] : C13
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[0].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[0]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[0]}]
#  trigOut[1] : B12
#set_property LOC IDELAY_X0Y160 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[1].U_IDELAY}]
#set_property LOC IDELAY_X0Y159 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[1]}]
#set_property LOC IDELAY_X0Y159 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[1]}]
#  trigOut[2] : B11
#set_property LOC IDELAY_X0Y159 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[2].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[2]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[2]}]
#  trigOut[3] : B14
#set_property LOC IDELAY_X0Y158 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[3].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[3]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[3]}]
#  trigOut[4] : A14
#set_property LOC IDELAY_X0Y157 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[4].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[4]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[4]}]
#  trigOut[5] : B10
#set_property LOC IDELAY_X0Y156 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[5].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[5]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[5]}]
#  trigOut[6] : A10
#set_property LOC IDELAY_X0Y155 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[6].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[6]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[6]}]
#  trigOut[7] : B15
#set_property LOC IDELAY_X0Y154 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[7].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[7]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[7]}]
#  trigOut[8] : A15
#set_property LOC IDELAY_X0Y153 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[8].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[8]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[8]}]
#  trigOut[9] : A13
#set_property LOC IDELAY_X0Y152 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[9].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[9]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[9]}]
#  trigOut[10] : A12
#set_property LOC IDELAY_X0Y151 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[10].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[10]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[10]}]
#  trigOut[11] : J14
#set_property LOC IDELAY_X0Y150 [get_cells {EvrCardG2Core_Inst/Trig_Inst/OR_TRIG[11].U_IDELAY}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigR[11]}]
#set_property LOC IDELAY_X0Y161 [get_cells {EvrCardG2Core_Inst/Trig_Inst/seqR.trigF[11]}]

#####################################
# Timing Constraints: Define Clocks #
#####################################

create_clock -name evrRefClk0 -period  4.201 [get_ports {evrRefClkP[0]}]
create_clock -name evrRefClk1 -period  2.692 [get_ports {evrRefClkP[1]}]
create_clock -name pciRefClkP -period 10.000 [get_ports pciRefClkP]
create_clock -name evrClk0    -period  8.402 [get_pins  {EvrCardG2Core_Inst/EvrCardG2Gtx_Inst/GEN_GTX[0].U_Gtx/Gtx7Core_Inst/gtxe2_i/RXOUTCLK}]
create_clock -name txClk0     -period  8.402 [get_pins  {EvrCardG2Core_Inst/EvrCardG2Gtx_Inst/GEN_GTX[0].U_Gtx/Gtx7Core_Inst/gtxe2_i/TXOUTCLK}]
create_clock -name evrClk1    -period  5.384 [get_pins  {EvrCardG2Core_Inst/EvrCardG2Gtx_Inst/GEN_GTX[1].U_Gtx/Gtx7Core_Inst/gtxe2_i/RXOUTCLK}]
create_clock -name txClk1     -period  5.384 [get_pins  {EvrCardG2Core_Inst/EvrCardG2Gtx_Inst/GEN_GTX[1].U_Gtx/Gtx7Core_Inst/gtxe2_i/TXOUTCLK}]

#create_clock -name evrClk     -period  5.384 [get_pins  {EvrCardG2Core_Inst/EvrCardG2Gtx_Inst/U_EVRCLKMUX/O}]
#create_clock -name txClk      -period  5.384 [get_pins  {EvrCardG2Core_Inst/EvrCardG2Gtx_Inst/U_EVRTXCLKMUX/O}]

#create_generated_clock  -name stableClk [get_pins {EvrCardG2Core_Inst/EvrCardG2Gtx_Inst/GEN_GTREF[0].IBUFDS_GTE2_Inst/ODIV2}]  
create_generated_clock  -name dnaClk [get_pins {EvrCardG2Core_Inst/AxiVersion_Inst/GEN_DEVICE_DNA.DeviceDna_1/GEN_7SERIES.DeviceDna7Series_Inst/BUFR_Inst/O}]

#create_generated_clock  -name progClk    [get_pins {EvrCardG2Core_Inst/Iprog7Series_Inst/BUFR_ICPAPE2/O}]
create_generated_clock  -name pciClk     [get_pins {EvrCardG2Core_Inst/PciCore_Inst/EvrCardG2PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT0}]  
#create_generated_clock  -name pciClk     [get_pins {EvrCardG2Core_Inst/PciCore_Inst/EvrCardG2PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3}]  

##############################################
# Crossing Domain Clocks: Timing Constraints #
##############################################

set_clock_groups -asynchronous \
     -group [get_clocks -include_generated_clocks {pciClk}] \
     -group [get_clocks -include_generated_clocks {txClk0}] \
     -group [get_clocks -include_generated_clocks {txClk1}] \
     -group [get_clocks -include_generated_clocks {evrClk0}] \
     -group [get_clocks -include_generated_clocks {evrClk1}] \
     -group [get_clocks -include_generated_clocks {evrRefClk0}] \
     -group [get_clocks -include_generated_clocks {evrRefClk1}]

set_clock_groups -asynchronous -group [get_clocks pciClk] -group [get_clocks dnaClk]
#set_clock_groups -asynchronous -group [get_clocks pciClk] -group [get_clocks stableClk]

#set_clock_groups -asynchronous \
#    -group [get_clocks -include_generated_clocks {evrClk0}] \
#    -group [get_clocks -include_generated_clocks {evrClk1}]


###############################
# FPGA Hardware Configuration #
###############################

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]   
set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type2 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property CONFIG_MODE BPI16 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]

##########
# StdLib #
##########

set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]


#  Constrain output delays
#set_output_delay -clock [get_clocks trgClk] -min 8.0 -max 9.0 [get_ports {trigOut[*]}]
#set_output_delay -clock [get_clocks invClk] -min 8.0 -max 9.0 [get_ports {trigOut[*]}]
