
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>

#include <string>

#include "evgasync.hh"

using namespace EvgAsync;

extern int optind;

static void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("          -d <dev>  : <tpr a/b>\n");
  printf("          -R        : PLL reset\n");
  printf("          -r        : phy reset\n");
  printf("          -t        : update timestamp\n");
  printf("          -e code0[,code1,[...]] : arm event codes\n");
}

int main(int argc, char** argv) {

  extern char* optarg;
  char tprid='a';

  bool pllReset = false;
  bool phyReset = false;
  bool updateTime = false;
  bool updateCodes = false;
  uint32_t codes[8];
  memset(codes, 0, sizeof(codes));
  
  int c;
  bool lUsage = false;
  char* endptr;

  while ( (c=getopt( argc, argv, "rRtd:e:h?")) != EOF ) {
    switch(c) {
    case 'r': phyReset = true; break;
    case 'R': pllReset = true; break;
    case 't': updateTime = true; break;
    case 'd':
      tprid  = optarg[0];
      if (strlen(optarg) != 1) {
        printf("%s: option `-r' parsing error\n", argv[0]);
        lUsage = true;
      }
      break;
    case 'e':
      { char* p = optarg;
        do {
          unsigned e = strtoul(p,&endptr,0);
          printf("Adding eventcode %u\n",e);
          codes[e>>5] |= (1U<<(e&0x1f));
          p = endptr+1;
        } while (*endptr==',');
      } break;
    case 'h':
    case '?':
      usage(argv[0]);
      exit(0);
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
    char evrdev[16];
    sprintf(evrdev,"/dev/tpr%c",tprid);
    printf("Using tpr %s\n",evrdev);

    int fd = open(evrdev, O_RDWR);
    if (fd<0) {
      perror("Could not open");
      return -1;
    }

    void* ptr = mmap(0, sizeof(EvgAsync::Reg), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (ptr == MAP_FAILED) {
      perror("Failed to map");
      return -2;
    }

    EvgAsync::Reg& reg = *reinterpret_cast<EvgAsync::Reg*>(ptr);
    printf("FpgaVersion: %08X\n", reg.version.FpgaVersion);
    printf("BuildStamp: %s\n", reg.version.buildStamp().c_str());

    reg.xbar.setEvr( Tpr::XBar::StraightIn );
    reg.xbar.setEvr( Tpr::XBar::StraightOut);
    reg.xbar.setTpr( Tpr::XBar::StraightIn );
    reg.xbar.setTpr( Tpr::XBar::StraightOut);

    if (pllReset) {
      reg.csr.pllReset = 1;
      usleep(1000);
      reg.csr.pllReset = 0;
      usleep(1000);
    }

    if (phyReset) {
      reg.csr.phyReset = 1;
      usleep(1000);
      reg.csr.phyReset = 0;
      usleep(1000);
    }
    
    if (updateTime) {
      struct tm tm_s;
      tm_s.tm_sec  = 0;
      tm_s.tm_min  = 0;
      tm_s.tm_hour = 0;
      tm_s.tm_mday = 1;
      tm_s.tm_mon  = 0;
      tm_s.tm_year = 90;
      tm_s.tm_wday = 0;
      tm_s.tm_yday = 0;
      tm_s.tm_isdst = 0;
      time_t t0 = mktime(&tm_s);

      time_t ltv_sec = time(NULL);
      time_t tv_sec  = mktime(gmtime(&ltv_sec));

      reg.csr.timeStampWr = tv_sec - t0;
    }

    if (updateCodes) {
      for(unsigned i=0; i<8; i++)
        reg.csr.eventCodes[i] = codes[i];
    }
  }

  return 0;
}

