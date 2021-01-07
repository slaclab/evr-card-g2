#!/bin/sh

# Set the CPSW environment
. $PACKAGE_TOP/cpsw/framework/R4.4.2/env.slac.sh > /dev/null

# Call the python test script, passing the input arguments
python3 test.py $@
