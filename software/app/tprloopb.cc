
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>

#include "tpr.hh"
#include "tprsh.hh"

#include <string>

using namespace Tpr;

static bool     verbose = false;

enum TimingMode { LCLS1=0, LCLS2=1, UED=2 };
static void link_test          (TprReg&, TimingMode, bool lring);

extern int optind;

static void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("          -d <dev>  : <tpr a/b>\n");
  printf("          -1        : test LCLS-I  timing\n");
  printf("          -2        : test LCLS-II timing\n");
}

int main(int argc, char** argv) {

  extern char* optarg;
  char tprid='a';

  int c;
  bool lUsage = false;

  TimingMode tmode = LCLS1;
  char* endptr;

  while ( (c=getopt( argc, argv, "12d:h?")) != EOF ) {
    switch(c) {
    case '1': tmode = LCLS1; break;
    case '2': tmode = LCLS2; break;
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
    TprReg* p = reinterpret_cast<TprReg*>(0);
      printf("version @%p\n",&p->version);
      printf("xbar    @%p\n",&p->xbar);
      printf("base    @%p\n",&p->base);
      printf("tpr     @%p\n",&p->tpr);
      printf("tpg     @%p\n",&p->tpg);
    printf("RxRecClks[%p]\n",&p->tpr.RxRecClks);
  }

  {
    char evrdev[16];
    sprintf(evrdev,"/dev/tpr%c",tprid);
    printf("Using tpr %s\n",evrdev);

    int fd = open(evrdev, O_RDWR);
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
    printf("FpgaVersion: %08X\n", reg.version.FpgaVersion);
    printf("BuildStamp: %s\n", reg.version.buildStamp().c_str());

    reg.xbar.setEvr( XBar::LoopIn );
    reg.xbar.setEvr( XBar::StraightOut);
    reg.xbar.setTpr( XBar::LoopIn );
    reg.xbar.setTpr( XBar::StraightOut);

    printf("\n-- LCLS1 --\n");
    link_test(reg, LCLS1, true);
    printf("\n-- LCLS2 --\n");
    link_test(reg, LCLS2, true);
    printf("\n-- LCLS1 --\n");
    link_test(reg, LCLS1, true);
    printf("\n-- LCLS2 --\n");
    link_test(reg, LCLS2, true);
  }

  return 0;
}

void link_test(TprReg& reg, TimingMode tmode, bool lring)
{
  static const double ClkMin[] = { 118, 184, 118 };
  static const double ClkMax[] = { 120, 187, 120 };
  static const double FrameMin[] = { 356, 928000, 356 };
  static const double FrameMax[] = { 362, 929000, 362 };
  unsigned ilcls = unsigned(tmode);

  // clkSel chooses the reference clock and the sfp module
  reg.tpr.clkSel(tmode==LCLS2);
  // modeSel chooses the protocol
  reg.tpr.modeSel(tmode!=LCLS1);
  reg.tpr.modeSelEn(true);
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

  reg.tpr.dump();
  reg.csr.dump();
  // Change dmaFullThr
  reg.csr.setupDma(0x2ff);
  reg.csr.dump();

  unsigned v = reg.tpr.CSR;
  printf(" %s", v&(1<<1) ? "LinkUp":"LinkDn");
  if (v&(1<<2)) printf(" RXPOL");
  printf(" %s", v&(1<<4) ? "LCLSII":"LCLS");
  if (v&(1<<5)) printf(" LinkDnL");
  printf("\n");
  //  Acknowledge linkDownL bit
  reg.tpr.CSR = v & ~(1<<5);

  if (!lring) return;

  //  Dump ring buffer
  printf("\n-- RingB 0 --\n");
  reg.ring0.enable(false);
  reg.ring0.clear ();
  reg.ring0.enable(true);
  usleep(10000);
  reg.ring0.enable(false);
  reg.ring0.dump  ();

  //  Dump ring buffer
  printf("\n-- RingB 1 --\n");
  reg.ring1.enable(false);
  reg.ring1.clear ();
  reg.ring1.enable(true);
  usleep(10000);
  reg.ring1.enable(false);
  reg.ring1.dump  ("%08x");
}

