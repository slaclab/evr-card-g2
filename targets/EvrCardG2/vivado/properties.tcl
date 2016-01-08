##############################################################################
## This file is part of 'SLAC EVR Gen2'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC EVR Gen2', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## Check for version 2015.3 of Vivado
if { [VersionCheck 2015.3] < 0 } {
   close_project
   exit -1
}
