#!/usr/bin/env python3
##############################################################################
## This file is part of 'SLAC EVR Gen2'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC EVR Gen2', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

import argparse
from pycpsw import *

if __name__ == '__main__':

    # Parse inputs arguments
    parser = argparse.ArgumentParser(description='Test EVR Card G2 using CPSW')
    parser.add_argument('--yaml', type=str, required=True, dest='yaml_top_file',
                        help='Path to the top level YAML file (000TopLevel.yaml)')
    parser.add_argument('--root-name', type=str, default='MemDev', dest='root_dev_name',
                        help='Root device name (default = "MemDev")')
    parser.add_argument('--scratch-pad', type=int, dest='scratch_pad',
                        help='Write this value to the AxiVersion/ScratchPad register')
    args = parser.parse_args()

    # Create the CPSW root
    root = Path.loadYamlFile(args.yaml_top_file, args.root_dev_name)
    
    # Create register access objects
    fpga_version = ScalVal_RO.create(root.findByName('mmio/AxiVersion/FpgaVersion'))
    git_hash = ScalVal_RO.create(root.findByName('mmio/AxiVersion/GitHash'))
    device_dna = ScalVal_RO.create(root.findByName('mmio/AxiVersion/DeviceDna'))
    up_time = ScalVal_RO.create(root.findByName('mmio/AxiVersion/UpTimeCnt'))
    build_stamp = ScalVal_RO.create(root.findByName('mmio/AxiVersion/BuildStamp'))
    scratch_pad = ScalVal.create(root.findByName('mmio/AxiVersion/ScratchPad'))

    # Write to the scratch pad register
    if args.scratch_pad:
        scratch_pad.setVal(args.scratch_pad)
    
    # Read and print the register content
    print(f'Version     : 0x{fpga_version.getVal():X}')
    print(f'DeviceDna   : 0x{device_dna.getVal():X}')
    print(f'Up time     : {up_time.getVal()} s')
    print(f"Git Hash    : 0x{''.join([str(format(i, 'x')) for i in reversed(git_hash.getVal())])}")
    print(f"Build stamp : {''.join([chr(item) for item in build_stamp.getVal()])}")
    print(f'Scratch Pad : {scratch_pad.getVal()}')
