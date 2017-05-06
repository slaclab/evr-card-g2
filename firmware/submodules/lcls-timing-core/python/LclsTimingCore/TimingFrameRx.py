#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Status of timing frame reception
#-----------------------------------------------------------------------------
# File       : TimingFrameRx.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue Status of timing frame reception
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

class TimingFrameRx(pr.Device):
    def __init__(   self,       
                    name        = "TimingFrameRx",
                    description = "Status of timing frame reception",
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, )

        ##############################
        # Variables
        ##############################

        self.addVariable(   name         = "sofCount",
                            description  = "Start of frame count",
                            offset       =  0x00,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "eofCount",
                            description  = "End of frame count",
                            offset       =  0x04,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "FidCount",
                            description  = "Valid frame count",
                            offset       =  0x08,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "CrcErrCount",
                            description  = "CRC error count",
                            offset       =  0x0C,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "RxClkCount",
                            description  = "Recovered clock count div 16",
                            offset       =  0x10,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "RxRstCount",
                            description  = "Receive link reset count",
                            offset       =  0x14,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "RxDecErrCount",
                            description  = "Receive 8b/10b decode error count",
                            offset       =  0x18,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "RxDspErrCount",
                            description  = "Receive disparity error count",
                            offset       =  0x1C,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "RxCountReset",
                            description  = "Reset receive counters",
                            offset       =  0x20,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "RxLinkUp",
                            description  = "Receive link status",
                            offset       =  0x20,
                            bitSize      =  1,
                            bitOffset    =  0x01,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "RxPolarity",
                            description  = "Invert receive link polarity",
                            offset       =  0x20,
                            bitSize      =  1,
                            bitOffset    =  0x02,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "RxReset",
                            description  = "Reset receive link",
                            offset       =  0x20,
                            bitSize      =  1,
                            bitOffset    =  0x03,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "ClkSel",
                            description  = "Select LCLS-I/LCLS-II Timing",
                            offset       =  0x20,
                            bitSize      =  1,
                            bitOffset    =  0x04,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "RxDown",
                            description  = "Rx down latch status",
                            offset       =  0x20,
                            bitSize      =  1,
                            bitOffset    =  0x05,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "BypassRst",
                            description  = "Buffer bypass reset status",
                            offset       =  0x20,
                            bitSize      =  1,
                            bitOffset    =  0x06,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "MsgDelay",
                            description  = "LCLS-II timing frame pipeline delay (186MHz clks)",
                            offset       =  0x24,
                            bitSize      =  20,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "TxClkCount",
                            description  = "Transmit clock counter div 16",
                            offset       =  0x28,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "BypassDoneCount",
                            description  = "Buffer bypass done count",
                            offset       =  0x2C,
                            bitSize      =  16,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "BypassResetCount",
                            description  = "Buffer bypass reset count",
                            offset       =  0x2E,
                            bitSize      =  16,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        ##############################
        # Commands
        ##############################

        self.addCommand(    name         = "C_RxReset",
                            description  = "Reset Rx Link",
                            function     = """\
                                           self.RxReset.set(1)
                                           self.usleep.set(1000)
                                           self.RxReset.set(0)
                                           """
                        )

        self.addCommand(    name         = "ClearRxCounters",
                            description  = "Clear the Rx status counters.",
                            function     = """\
                                           self.RxCountReset.set(1)
                                           self.usleep.set(1000)
                                           self.RxCountReset.set(0)
                                           """
                        )

