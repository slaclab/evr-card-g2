##############################################################################
## This file is part of 'SLAC EVR Gen2'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC EVR Gen2', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
set format     "mcs"
set inteface   "bpix16"
set size       "128"

set BIT_PATH   "$::env(IMPL_DIR)/$::env(PROJECT).bit"
set DATA_PATH  "$::env(IMAGES_DIR)/$::env(PROJECT)_$::env(PRJ_VERSION).tar.gz"

set loadbit    "up 0x00000000 ${BIT_PATH}"
set loaddata   "up 0x0016F97E ${DATA_PATH}"