##############################################################################
## This file is part of 'SLAC EVR Gen2'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC EVR Gen2', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
## Open the run
open_run synth_1

## Setup configurations
set ilaName    u_ila_0

## Create the core
CreateDebugCore ${ilaName}

## Set the record depth
set_property C_DATA_DEPTH 16384 [get_debug_cores ${ilaName}]

## Set the clock for the Core
SetDebugCoreClk ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/evrClk}

## Set the Probes

# ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/rxDataKDly[*]}
# ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/rxDataDly[*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/intFlag[*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/irqClr[*]}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/latchTs}
ConfigProbe ${ilaName} {EvrCardG2Core_Inst/EvrCardG2LclsV1_Inst/EvrV1Core_Inst/EvrV1EventReceiver_Inst/timeStampDly[*]}

## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

## Write the port map file
write_debug_probes -force ${PROJ_DIR}/images/debug_probes.ltx
