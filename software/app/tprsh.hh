//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC EVR Gen2'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC EVR Gen2', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#ifndef TPRSH_HH
#define TPRSH_HH

#define MOD_SHARED 14
#define MAX_TPR_ALLQ (32*1024)
#define MAX_TPR_BSAQ  1024
#define MSG_SIZE      32

namespace Tpr {
  // DMA Buffer Size, Bytes (could be as small as 512B)
#define BUF_SIZE 4096
#define NUMBER_OF_RX_BUFFERS 256

  class TprEntry {
  public:
    volatile uint32_t word[MSG_SIZE];
    volatile uint64_t fifo_tsc;
  };

  class TprQIndex {
  public:
    volatile long long idx[MAX_TPR_ALLQ];
  };

  class TprQueues {
  public:
    TprEntry  allq  [MAX_TPR_ALLQ];
    TprEntry  bsaq  [MAX_TPR_BSAQ];
    TprQIndex allrp [MOD_SHARED]; // indices into allq
    volatile long long allwp [MOD_SHARED]; // write pointer into allrp
    volatile long long bsawp;
    volatile long long gwp;
    volatile int       fifofull;
  };
};

#endif
