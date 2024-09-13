#-----------------------------------------------------------------------------
# This file is part of the 'Camera link gateway'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'Camera link gateway', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

import surf.axi as axi

class EvrCardG2Core(pr.Device):
    def __init__(self, promProg=False, **kwargs):
        super().__init__(**kwargs)

        # Add devices
        self.add(axi.AxiVersion(
            name        = 'AxiVersion',
            offset      = 0x0001_0000,
            expand      = False,
        ))
