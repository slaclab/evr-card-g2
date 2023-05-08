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
    volatile uint32_t    pllReset;
    volatile uint32_t    phyReset;
    volatile uint64_t    timeStampWr;
    volatile uint64_t    timeStampRd;
    volatile uint32_t    reserved[2];
    volatile uint32_t    eventCodes[8];
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
  };
};

#endif
