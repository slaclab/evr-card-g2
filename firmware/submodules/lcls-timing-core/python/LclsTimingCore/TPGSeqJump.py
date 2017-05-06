#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Timing pattern sequencer jump programming
#-----------------------------------------------------------------------------
# File       : TPGSeqJump.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue Timing pattern sequencer jump programming
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class TPGSeqJump(pr.Device):
    def __init__(   self,       
                    name        = "TPGSeqJump",
                    description = "Timing pattern sequencer jump programming",
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, )

        ##############################
        # Variables
        ##############################

        self.addVariables(  name         = "StartAddr",
                            description  = "Sequence start offset",
                            offset       =  0x00,
                            bitSize      =  12,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                            number       =  1024,
                            stride       =  4,
                        )

        self.addVariables(  name         = "Class",
                            description  = "Sequence power class",
                            offset       =  0x01,
                            bitSize      =  4,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                            number       =  1024,
                            stride       =  4,
                        )

        self.addVariables(  name         = "StartSync",
                            description  = "Start synchronization condition",
                            offset       =  0x02,
                            bitSize      =  16,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                            number       =  1024,
                            stride       =  4,
                        )

