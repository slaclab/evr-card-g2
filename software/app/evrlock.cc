#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>
#include <signal.h>

#include "tpr.hh"

#include <string>

FILE* ofd = 0;

static void sigHandler(int signal)
{
    psignal(signal, "closing output file");
    if (ofd)
        fclose(ofd);
    ::exit(signal);
}

using namespace Tpr;

namespace Tpr {
  //
  // Memory map of TPR registers (EvrCardG2 BAR 1)
  //
  class LockApp {
  public:
    volatile uint32_t     ready;
    volatile uint32_t     phase;
    volatile uint32_t     phaseN;
    volatile uint32_t     valid;
    volatile uint32_t     clks;
    volatile uint32_t     tmoCnt;
    volatile uint32_t     refMarkCnt;
    volatile uint32_t     testMarkCnt;
    volatile uint32_t     timingRst;
    volatile uint32_t     txDataNC;
    volatile uint32_t     txDataSC;
    volatile uint32_t     psincdec;
    volatile uint32_t     loopbackNC;
    volatile uint32_t     loopbackSC;
  public:
#define REGCPY(name) { name = o.name; usleep(1000); }
      LockApp() {}
      LockApp(const LockApp& o) {
          REGCPY(ready);
          REGCPY(phase);
          REGCPY(phaseN);
          REGCPY(valid);
          REGCPY(clks);
          REGCPY(tmoCnt);
          REGCPY(refMarkCnt);
          REGCPY(testMarkCnt);
          REGCPY(txDataNC);
          REGCPY(txDataSC);
      }
      LockApp& operator=(const LockApp& o) {
          REGCPY(ready);
          REGCPY(phase);
          REGCPY(phaseN);
          REGCPY(valid);
          REGCPY(clks);
          REGCPY(tmoCnt);
          REGCPY(refMarkCnt);
          REGCPY(testMarkCnt);
          REGCPY(txDataNC);
          REGCPY(txDataSC);
          return *this;
      }
    void dump(LockApp& cache) const {
      LockApp cc(*this);
      unsigned ph  = cc.phase;
      unsigned phN = cc.phaseN;
      unsigned va  = cc.valid;
      printf("ready   %c\n",cc.ready?'T':'F');
      printf("phase   0x%x [%f]\n", ph , double(ph )/double(va));
      printf("phaseN  0x%x [%f]\n", phN, double(phN)/double(va));
      printf("clks    %u\n", cc.clks);
      printf("tmocnt  %u  %d\n", cc.tmoCnt, cc.tmoCnt-cache.tmoCnt);
      printf("refcnt  %u  %d\n", cc.refMarkCnt, cc.refMarkCnt-cache.refMarkCnt);
      printf("tstcnt  %u  %d\n", cc.testMarkCnt, cc.testMarkCnt-cache.testMarkCnt);
      printf("timRst  %u\n", cc.timingRst&3);
      printf("txNC    %05x\n", cc.txDataNC&0x3ffff);
      printf("txSC    %05x\n", cc.txDataSC&0x3ffff);
      cache = cc;
    }
  };
  
  class LockCore {
  public:
    uint32_t     reserved_0    [(0x10000)>>2];
    AxiVersion   version;  // 0x00010000
    uint32_t     reserved_10000[(0x40000-0x20000)>>2];  // boot_mem is here
    XBar         xbar;     // 0x00040000
    uint32_t     reserved_30010[(0x60000-0x40010)>>2];
    LockApp      app;      // 0x00060000
    uint32_t     reserved_80000[(0x20000-sizeof(LockApp))/4];
    TprCore      coreNC;   // 0x00080000
    uint32_t     reserved_C0000[(0x40000-sizeof(TprCore))/4];
    TprCore      coreSC;   // 0x000C0000
    uint32_t     reserved_END  [(0x40000-sizeof(TprCore))/4];
  };
};

static const double CLK_FREQ = 1300e6/7.;
static bool     verbose = false;

extern int optind;

static void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("          -d <dev>  : <tpr a/b>\n");
  printf("          -l        : loopback XBAR\n");
  printf("          -L        : loopback GTX\n");
  printf("          -F        : fast scan\n");
  printf("          -S        : slow scan\n");
  printf("          -f <fname>: output data filename\n");
}

int main(int argc, char** argv) {

  extern char* optarg;
  char tprid='a';

  int c;
  bool lUsage = false;
  bool loopbackXbar = false;
  bool loopbackGtx = false;
  bool lfast = false;
  bool lslow = false;
  const char* fname = "evrlock.dat";
  
  char* endptr;

  while ( (c=getopt( argc, argv, "d:f:FSlLh?")) != EOF ) {
    switch(c) {
    case 'd':
      tprid  = optarg[0];
      if (strlen(optarg) != 1) {
        printf("%s: option `-r' parsing error\n", argv[0]);
        lUsage = true;
      }
      break;
    case 'f':
      fname = optarg;
      break;
    case 'F':
      lfast = true;
      lslow = false;
      break;
    case 'S':
      lfast = false;
      lslow = true;
      break;
    case 'l':
      loopbackXbar = true;
      break;
    case 'L':
      loopbackGtx = true;
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


  struct sigaction sa;
  sa.sa_handler = sigHandler;
  sa.sa_flags = SA_RESETHAND;

  sigaction(SIGINT ,&sa,NULL);
  sigaction(SIGABRT,&sa,NULL);
  sigaction(SIGKILL,&sa,NULL);
  sigaction(SIGSEGV,&sa,NULL);

  {
    LockCore* p = reinterpret_cast<LockCore*>(0);
      printf("version @%p\n",&p->version);
      printf("xbar    @%p\n",&p->xbar);
      printf("app     @%p\n",&p->app);
      printf("coreNC  @%p\n",&p->coreNC);
      printf("coreSC  @%p\n",&p->coreSC);
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

    void* ptr = mmap(0, sizeof(LockCore), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (ptr == MAP_FAILED) {
      perror("Failed to map");
      return -2;
    }

    LockCore& reg = *reinterpret_cast<LockCore*>(ptr);
    printf("FpgaVersion: %08X\n", reg.version.FpgaVersion);
    printf("BuildStamp: %s\n", reg.version.buildStamp().c_str());

    reg.xbar.setEvr( loopbackXbar ? XBar::LoopIn : XBar::StraightIn );
    reg.xbar.setEvr( XBar::StraightOut);
    reg.app.loopbackNC = loopbackGtx ? 2 : 0;

    reg.coreNC.clkSel(false);
    reg.coreNC.resetRxPll();
    usleep(100000);
    reg.coreNC.resetRx();

    reg.xbar.setTpr( loopbackXbar ? XBar::LoopIn : XBar::StraightIn );
    reg.xbar.setTpr( XBar::StraightOut);
    reg.app.loopbackSC = loopbackGtx ? 2 : 0;

    reg.coreSC.clkSel(true);
    reg.coreSC.resetRxPll();
    usleep(100000);
    reg.coreSC.resetRx();
    usleep(100000);

    reg.xbar.dump();

    printf("-- coreNC --\n");
    TprCore cache(reg.coreNC);
    cache.dump();
    for(unsigned i=0; i<5; i++) {
      usleep(1000000);
      //      reg.coreNC.dump(cache);
      reg.coreNC.dump();
    }

    printf("-- coreSC --\n");
    cache = reg.coreSC;
    reg.coreSC.dump();
    for(unsigned i=0; i<5; i++) {
      usleep(1000000);
      printf("--\n");
      //      reg.coreSC.dump(cache);
      reg.coreSC.dump();
    }

    //  Just monitor the lock
    ofd = fopen(fname,"w");
    if (ofd == 0)
        perror("Opening output file");

    unsigned iter=0;
    LockApp dc;
    while(1) {
      printf("-- Iteration %u\n",iter);
      reg.app.dump(dc);
      if (lfast)
          for(unsigned i=0; i<1000; i++) {
              reg.app.psincdec = 1;
              usleep(1000);
          }
      else 
          usleep(1000000);

      if (lslow)
          reg.app.psincdec = 1;
      printf("\n");
      fprintf(ofd, "%u: %u  %u  %u  %u\n", iter++, dc.clks, dc.phase, dc.phaseN, dc.valid);
    }
  }

  return 0;
}

