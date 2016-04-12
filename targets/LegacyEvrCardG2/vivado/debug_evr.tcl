## Open the run
open_run synth_1

## Setup configurations
set ilaName    u_ila_0

## Create the core
CreateDebugCore ${ilaName}

## Set the record depth
set_property C_DATA_DEPTH 32768 [get_debug_cores ${ilaName}]

## Set the clock for the Core
SetDebugCoreClk ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/evrClk}

## Set the Probes
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/rxDataKDly[*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/rxDataDly[*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/intFlag[*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/irqClr[*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/latchTs}

## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

## Write the port map file
write_debug_probes -force ${PROJ_DIR}/images/debug_probes.ltx
