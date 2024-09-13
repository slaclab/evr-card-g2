#-----------------------------------------------------------------------------
# This file is part of the 'Development Board Examples'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'Development Board Examples', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue  as pr
import pyrogue.protocols

import rogue
import rogue.hardware.axi

import evr_card_g2 as evr

rogue.Version.minVersion('6.4.0')

class Root(pr.Root):
    def __init__(   self,
            dev      = '/dev/tpra',
            pollEn   = True,  # Enable automatic polling registers
            initRead = True,  # Read all registers at start of the system
            promProg = False, # Flag to disable all devices not related to PROM programming
            zmqSrvEn = True,  # Flag to include the ZMQ server
            **kwargs):
        super().__init__(**kwargs)

        #################################################################
        if zmqSrvEn:
            self.zmqServer = pyrogue.interfaces.ZmqServer(root=self, addr='127.0.0.1', port=0)
            self.addInterface(self.zmqServer)

        # Start up flags
        self._pollEn   = pollEn
        self._initRead = initRead

        #################################################################

        # Create PCIE memory mapped interface
        self.memMap = rogue.hardware.axi.AxiMemMap(dev)

        #################################################################

        # Add Devices
        self.add(evr.EvrCardG2Core(
            offset   = 0x0000_0000,
            memBase  = memMap,
            promProg = promProg,
            expand   = True,
        ))

        #################################################################
