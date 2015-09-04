## Open the run
open_run synth_1

## Setup configurations
set ilaName    u_ila_0

## Create the core
CreateDebugCore ${ilaName}

## Set the record depth
set_property C_DATA_DEPTH 1024 [get_debug_cores ${ilaName}]

## Set the clock for the Core
SetDebugCoreClk ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/axiClk}

## Set the Probes
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/irqActive}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/irqEnable}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/irqReq}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/rxLinkUp}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[irqClr][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/status[intFlag][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/status[rxSize][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/status[tsFifoEventCode][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/status[tsFifoTsHigh][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/status[tsFifoTsLow][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[dbdis]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[dben]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[dbena]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[evrEnable]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[extEventEn]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[intEventEn]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[mapRamPage]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[tsFifoRdEna]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/TimeStampFIFO_Inst/empty}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/TimeStampFIFO_Inst/rd_en}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/TimeStampFIFO_Inst/wr_en}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/fifoRst}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/fifoWrEn}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/evrEnable}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/evrRst}

# ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/axiReadMaster[*}
# ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/axiReadSlave[*}
# ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/axiWriteMaster[*}
# ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/axiWriteSlave[*}
# ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/config[outputMap][*}

## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

## Write the port map file
write_debug_probes -force ${PROJ_DIR}/images/debug_probes.ltx
