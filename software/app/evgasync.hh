//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC EVR Gen2'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC EVR Gen2', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#ifndef EVGASYNC_HH
#define EVGASYNC_HH

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string>
#include <math.h>

#include "tpr.hh"

namespace EvgAsync {

  class Control {
  public:
      void resetPll() { pllReset=1; usleep(1000); pllReset=0; }
      void resetPhy() { phyReset=1; usleep(1000); phyReset=0; }
      void updateTime(uint64_t ts) {
          timeStampWr[0] = ts&0xffffffff;
          timeStampWr[1] = ts>>32;
      }
      void trigger() { triggerCnt=0; }
      uint64_t lastTime() const {
          uint32_t v = timeStampRd[0];
          uint64_t r = timeStampRd[1];
          r <<= 32;
          r += v;
          return r;
      }
  public:
    volatile uint32_t    pllReset;
    volatile uint32_t    phyReset;
    volatile uint32_t    timeStampWr[2];
    volatile uint32_t    timeStampRd[2];
    volatile uint32_t    triggerCnt;
    volatile uint32_t    reserved;
    volatile uint32_t    eventCodes[8];
  };
  
  class RingBuffer {
  public:
      void     enable (bool v) { _setbit(31,v); }
      void     clear  () { _setbit(30,true); _setbit(30,false); }
      void     dump   () { 
          unsigned len = csr;
          unsigned wid = (len>>20)&0xff;
          len &= (1<<wid)-1;
          printf("[wid=%x,len=%x]\n",wid,len);
          if (len>0x3ff) len=0x3ff;
          volatile uint32_t* data = &this->csr+1;
          for(unsigned i=0; i<len; i++) {
              uint32_t v = data[i];
              printf("%08x%c", v, (i&0x7)==0x7 ? '\n':' ');
          }
      }
      void     clear_and_dump() {
          enable(false);
          clear ();
          enable(true);
          usleep(100);
          enable(false);
          dump();
      }
  private:
      void _setbit(unsigned b, bool v) {
          unsigned r = csr;
          if (v) r |= (1<<b);
          else   r &= ~(1<<b);
          csr = r;
      }
  protected:
    volatile uint32_t csr;
  };

  //
  // Memory map of TPR registers (EvrCardG2 BAR 1)
  //
  class Reg {
  public:
    uint32_t        reserved_0    [(0x10000)>>2];
    Tpr::AxiVersion version;  // 0x00010000
    uint32_t        reserved_40000[(0x30000-sizeof(Tpr::AxiVersion))>>2];  // boot_mem is here
    Tpr::XBar       xbar;     // 0x00040000
    uint32_t        reserved_60000[(0x20000-sizeof(Tpr::XBar))>>2];
    Control         csr;      // 0x00060000
    RingBuffer      ring;     // 0x00070000
  };
};

#endif
