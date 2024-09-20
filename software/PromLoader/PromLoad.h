//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC EVR Gen2'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC EVR Gen2', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#ifndef __PROM_LOAD_H__
#define __PROM_LOAD_H__

using namespace std;
extern int PromLoad (volatile void *mapStart, string filePath);
#endif 
