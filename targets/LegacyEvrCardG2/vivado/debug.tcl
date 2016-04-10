## Open the run
open_run synth_1

## Setup configurations
set ilaName    u_ila_0

## Create the core
CreateDebugCore ${ilaName}

## Set the record depth
set_property C_DATA_DEPTH 8192 [get_debug_cores ${ilaName}]

## Set the clock for the Core
SetDebugCoreClk ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/axiClk}

## Set the Probes
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/irqActive}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/irqReq}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/status[intFlag][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[irq][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[config][latchTs]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[config][intControl][0]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[config][intControl][1]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[config][intControl][2]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[config][intControl][3]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[config][intControl][4]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[config][intControl][5]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[config][intControl][31]}

ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[irqRespCnt][3][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[irqRespTime][3][*]}

ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[irqRespCnt][5][*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/GEN_BIG_ENDIAN.EvrV1Reg_Inst/r[irqRespTime][5][*]}

## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

## Write the port map file
write_debug_probes -force ${PROJ_DIR}/images/debug_probes.ltx
