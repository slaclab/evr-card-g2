//
//  Command-line driver of TPR configuration
//
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>
#include <stdio.h>

#include "tpr.hh"
#include "tprsh.hh"

#include <string>
#include <vector>
#include <sstream>

using namespace Tpr;

static const double CLK_FREQ = 1300e6/7.;

extern int optind;

static void link_test          (TprReg&, bool lcls2);
static void lcls2_frame_rates  (TprReg&);
static void frame_capture      (TprReg&, char, bool lcls2);
static void dump_frame         (const uint32_t*);
static bool parse_frame        (const uint32_t*, uint64_t&, uint64_t&);

static void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options: -d <a..z> : /dev/tpr<arg>[0..a]\n");
}

int main(int argc, char** argv) {

  extern char* optarg;
  char tprid='a';

  int c;
  bool lUsage = false;
  while ( (c=getopt( argc, argv, "d:h?")) != EOF ) {
    switch(c) {
    case 'd':
      tprid  = optarg[0];
      if (strlen(optarg) != 1) {
        printf("%s: option `-r' parsing error\n", argv[0]);
        lUsage = true;
      }
      break;
    case 'h':
      usage(argv[0]);
      exit(0);
    case '?':
    default:
      lUsage = true;
      break;
    }
  }

  if (optind < argc) {
    printf("%s: invalid argument -- %s\n",argv[0], argv[optind]);
    lUsage = true;
  }

  if (lUsage) {
    usage(argv[0]);
    exit(1);
  }

  {
    char dev[16];
    sprintf(dev,"/dev/tpr%c",tprid);
    printf("Using tpr %s\n",dev);

    int fd = open(dev, O_RDWR);
    if (fd<0) {
      perror("Could not open");
      return -1;
    }

    void* ptr = mmap(0, sizeof(TprReg), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (ptr == MAP_FAILED) {
      perror("Failed to map");
      return -2;
    }

    TprReg& reg = *reinterpret_cast<TprReg*>(ptr);
    reg.xbar.setEvr( XBar::StraightIn );
    reg.xbar.setTpr( XBar::StraightIn );

    //
    //  Validate LCLS-II link
    //
    link_test(reg, true);

    //
    //  Capture series of timing frames (show table)
    //
    lcls2_frame_rates  (reg);
    frame_capture(reg,tprid, true);

    //
    //  Generate triggers (what device can digitize them)
    //

    //
    //  Validate LCLS-I link
    link_test(reg, false);

    //
    //  Capture series of timing frames (show table)
    //
    frame_capture(reg,tprid, false);

    //
    //  Generate triggers
    //

  }

  return 0;
}

void link_test(TprReg& reg, bool lcls2)
{
  static const double ClkMin[] = { 118, 184 };
  static const double ClkMax[] = { 120, 187 };
  static const double FrameMin[] = { 356, 928000 };
  static const double FrameMax[] = { 362, 929000 };
  unsigned ilcls = lcls2 ? 1:0;

  reg.tpr.clkSel(lcls2);
  reg.tpr.rxPolarity(false);
  usleep(100000);
  reg.tpr.resetCounts();
  unsigned rxclks0 = reg.tpr.RxRecClks;
  unsigned txclks0 = reg.tpr.TxRefClks;
  usleep(1000000);
  unsigned rxclks1 = reg.tpr.RxRecClks;
  unsigned txclks1 = reg.tpr.TxRefClks;
  unsigned sofCnts = reg.tpr.SOFcounts;
  unsigned crcErrs = reg.tpr.CRCerrors;
  unsigned decErrs = reg.tpr.RxDecErrs;
  unsigned dspErrs = reg.tpr.RxDspErrs;
  double rxClkFreq = double(rxclks1-rxclks0)*16.e-6;
  printf("RxRecClkFreq: %7.2f  %s\n", 
         rxClkFreq,
         (rxClkFreq > ClkMin[ilcls] &&
          rxClkFreq < ClkMax[ilcls]) ? "PASS":"FAIL");
  double txClkFreq = double(txclks1-txclks0)*16.e-6;
  printf("TxRefClkFreq: %7.2f  %s\n", 
         txClkFreq,
         (txClkFreq > ClkMin[ilcls] &&
          txClkFreq < ClkMax[ilcls]) ? "PASS":"FAIL");
  printf("SOFcounts   : %7u  %s\n",
         sofCnts,
         (sofCnts > FrameMin[ilcls] &&
          sofCnts < FrameMax[ilcls]) ? "PASS":"FAIL");
  printf("CRCerrors   : %7u  %s\n",
         crcErrs,
         crcErrs == 0 ? "PASS":"FAIL");
  printf("DECerrors   : %7u  %s\n",
         decErrs,
         decErrs == 0 ? "PASS":"FAIL");
  printf("DSPerrors   : %7u  %s\n",
         dspErrs,
         dspErrs == 0 ? "PASS":"FAIL");
}

void lcls2_frame_rates(TprReg& reg)
{
  const unsigned nrates=7;
  unsigned begin[nrates], end[nrates];
  static const unsigned rateMin[] = { 928000, 71000, 10000, 1000, 100,  9, 0 };
  static const unsigned rateMax[] = { 930000, 73000, 10400, 1040, 104, 12, 2 };

  for(unsigned i=0; i<nrates; i++) {
    reg.base.channel[i].evtSel  = (1<<30) | i;
    reg.base.channel[i].control = 1;
  }
  for(unsigned i=0; i<nrates; i++)
    begin[i] = reg.base.channel[i].evtCount;

  usleep(1000000);

  for(unsigned i=0; i<nrates; i++)
    end[i] = reg.base.channel[i].evtCount;

  for(unsigned i=0; i<nrates; i++) {
    unsigned rate = end[i]-begin[i];
    printf("FixedRate[%i]: %7u  %s\n",
           i, rate, 
           (rate > rateMin[i] && 
            rate < rateMax[i]) ? "PASS":"FAIL");
    reg.base.channel[i].control = 0;
  }
}

void frame_capture(TprReg& reg, char tprid, bool lcls2)
{
  int idx=0;
  char dev[16];
  sprintf(dev,"/dev/tpr%c%u",tprid,idx);

  int fd = open(dev, O_RDONLY);
  if (fd<0) {
    printf("Open failure for dev %s [FAIL]\n",dev);
    perror("Could not open");
    return;
  }

  void* ptr = mmap(0, sizeof(TprQueues), PROT_READ, MAP_SHARED, fd, 0);
  if (ptr == MAP_FAILED) {
    perror("Failed to map - FAIL");
    return;
  }

  unsigned _channel = 0;
  reg.base.setupTrigger(_channel,
                        _channel,
                        0, 0, 1, 0);
  unsigned ucontrol = reg.base.channel[_channel].control;
  reg.base.channel[_channel].control = 0;

  unsigned urate   = 0;     // 1MHz fixed rate
  unsigned destsel = 1<<17; // BEAM - DONT CARE
  reg.base.channel[_channel].evtSel = (destsel<<13) | (urate<<0);
  reg.base.channel[_channel].bsaDelay = 0;
  reg.base.channel[_channel].bsaWidth = 1;
  reg.base.channel[_channel].control = ucontrol | 1;

  //  read the captured frames

  printf("   %16.16s %8.8s %8.8s\n",
         "PulseId","Seconds","Nanosec");

  TprQueues& q = *(TprQueues*)ptr;

  char* buff = new char[32];

  int64_t allrp = q.allwp[idx];
  int64_t chnrp = q.chnwp[idx];

  read(fd, buff, 32);
  usleep(lcls2 ? 20 : 100000);
  //  disable channel 0
  reg.base.channel[_channel].control = 0;

  uint64_t pulseIdP=0;
  uint64_t pulseId, timeStamp;
  unsigned nframes=0;

  do {
    /*
    printf("allwp 0x%llx,  chnwp 0x%llx,  gwp 0x%llx\n",
           q.allwp[idx],
           q.chnwp[idx],
           q.gwp);
    */
    while(chnrp < q.chnwp[idx]) {
      const uint32_t* p = reinterpret_cast<const uint32_t*>
        (&q.chnq[idx].entry[chnrp&(MAX_TPR_CHNQ-1)].word[0]);
      //      dump_frame(p);
      chnrp++;
    }
    while(allrp < q.allwp[idx] && nframes<10) {
      const uint32_t* p = reinterpret_cast<const uint32_t*>
        (&q.allq[q.allrp[idx].idx[allrp &(MAX_TPR_ALLQ-1)] &(MAX_TPR_ALLQ-1) ].word[0]);
      //      dump_frame(p);
      if (parse_frame(p, pulseId, timeStamp)) {
        if (pulseIdP) {
          printf(" 0x%016llx %9u.%09u  %s\n", 
                 (unsigned long long)pulseId, 
                 unsigned(timeStamp>>32), 
                 unsigned(timeStamp&0xffffffff),
                 (pulseId==pulseIdP+1) ? "PASS":"FAIL");
          nframes++;
        }
        pulseIdP  =pulseId;
      }
      allrp++;
    }
    if (nframes>=10) 
      break;
    read(fd, buff, 32);
  } while(1);

  munmap(ptr, sizeof(TprQueues));
  close(fd);
}

void dump_frame(const uint32_t* p)
{
  char m = p[0]&(0x808<<20) ? 'D':' ';
  if (((p[0]>>16)&0xf)==0) {
    const uint64_t* pl = reinterpret_cast<const uint64_t*>(p+2);
    printf("EVENT LCLS%c chmask [x%x] [x%x] %c: %16lx %16lx",
           (p[0]&(1<<22)) ? '1':'2',
           (p[0]>>0)&0xffff,p[1],m,pl[0],pl[1]);
    for(unsigned i=6; i<20; i++)
      printf(" %08x",p[i]);
    printf("\n"); 
  }
}

bool parse_frame(const uint32_t* p,
                 uint64_t& pulseId, uint64_t& timeStamp)
{
  //  char m = p[0]&(0x808<<20) ? 'D':' ';
  if (((p[0]>>16)&0xf)==0) {
    const uint64_t* pl = reinterpret_cast<const uint64_t*>(p+2);
    pulseId = pl[0];
    timeStamp = pl[1];
    return true;
  }
  return false;
}
