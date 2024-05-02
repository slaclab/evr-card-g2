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

static void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options: -d <a..z> : /dev/tpr<arg>[0..a]\n");
}

int main(int argc, char** argv) {

  extern char* optarg;
  char tprid='a';

  int c;
  bool lUsage  = false;

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
    printf("BuildStamp: %s\n", reg.version.buildStamp().c_str());

    reg.trgmon.reset=1;
    usleep(1000);
    reg.trgmon.reset=0;
    
    usleep(1000000);

    printf("%8.8s %8.8s %8.8s\n", "Chan", "MinDel", "MaxDel");
    for(unsigned i=0; i<TrgMon::NTRIGGERS; i++)
      printf("%8u %8u %8u\n",i,reg.trgmon.trigger[i].periodMin,reg.trgmon.trigger[i].periodMax);
    
  }

  return 0;
}
