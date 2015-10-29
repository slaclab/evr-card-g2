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
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[evrEnable]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/config[irqClr][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/status[intFlag][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[config][intControl][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/heartBeatPulse}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/tsFIFOfullPulse}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/rxLinkUpSync}

## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

## Write the port map file
write_debug_probes -force ${PROJ_DIR}/images/debug_probes.ltx
