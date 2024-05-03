
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

extern int optind;

static void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("          -d <dev>  : <tpr a/b> [-c <channel>] [-v]\n");
}

static void frame_capture(char,unsigned);
static void dump_frame         (volatile const uint32_t*);
static bool parse_frame        (volatile const uint32_t*, uint64_t&, uint64_t&);

static bool verbose = false;


int main(int argc, char** argv) {

  extern char* optarg;
  char tprid='a';
  unsigned idx=0;

  int c;
  bool lUsage = false;

  char* endptr;

  while ( (c=getopt( argc, argv, "c:d:vh?")) != EOF ) {
    switch(c) {
    case 'c':
      idx = strtoul(optarg,0,NULL);
      break;
    case 'd':
      tprid  = optarg[0];
      if (strlen(optarg) != 1) {
        printf("%s: option `-r' parsing error\n", argv[0]);
        lUsage = true;
      }
      break;
    case 'v':
        verbose = true;
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

    printf("--xbar--\n");
    reg.xbar.dump();
    printf("--csr--\n");
    reg.csr.dump();
    printf("--dma--\n");
    reg.dma.dump();
    printf("--core--\n");
    reg.tpr.dump();
    printf("--base--\n");
    reg.base.dump();
  }

  frame_capture(tprid,idx);

  return 0;
}

void frame_capture(char tprid, unsigned idx)
{
    char dev[16];
    sprintf(dev,"/dev/tpr%c%x",tprid,idx);

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

    //  read the captured frames

    printf("   %16.16s %8.8s %8.8s\n",
           "PulseId","Seconds","Nanosec");

    TprQueues& q = *(TprQueues*)ptr;

    char* buff = new char[32];

    int64_t allrp = q.allwp[idx];
    int64_t bsarp = q.bsawp;
    printf("allrp %#lx  q.allwp[%d] %#lx\n", (uint64_t) allrp, idx, (uint64_t) q.allwp[idx]);

    read(fd, buff, 32);
    //    read(fdbsa, buff, 32);
    usleep(1000);

    uint64_t pulseIdP=0;
    uint64_t pulseId, timeStamp;
    unsigned nframes=0;

    do {
        //        printf("allrp %#lx  q.allwp[%d] %#lx\n", (uint64_t) allrp, idx, (uint64_t) q.allwp[idx]);
        while(allrp < q.allwp[idx] && nframes<10) {
            volatile const uint32_t* p = reinterpret_cast<volatile const uint32_t*>
                (&q.allq[q.allrp[idx].idx[allrp &(MAX_TPR_ALLQ-1)] &(MAX_TPR_ALLQ-1) ].word[0]);
            if (verbose)
                dump_frame(p);
            else if (parse_frame(p, pulseId, timeStamp)) {
                if (pulseIdP) {
                    uint64_t pulseIdN = pulseIdP+1;
                    //                    if (tmode==LCLS1) pulseIdN = (pulseId&~0x1ffffULL) | (pulseIdN&0x1ffffULL);
                    printf(" 0x%016llx %9u.%09u %s\n",
                           (unsigned long long)pulseId,
                           unsigned(timeStamp>>32),
                           unsigned(timeStamp&0xffffffff),
                           (pulseId==pulseIdN) ? "PASS":"FAIL");
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

}

void dump_frame(volatile const uint32_t* p)
{
    char m = p[0]&(0x808<<20) ? 'D':' ';
    if (((p[0]>>16)&0xf)==0) {
        volatile const uint64_t* pl = reinterpret_cast<volatile const uint64_t*>(p+2);
        printf("EVENT LCLS%c chmask [x%x] [x%x] %c: %16lx %16lx",
               (p[0]&(1<<22)) ? '1':'2',
               (p[0]>>0)&0xffff,p[1],m,pl[0],pl[1]);
        for(unsigned i=6; i<20; i++)
            printf(" %08x",p[i]);
        printf("\n");
    }
}

bool parse_frame(volatile const uint32_t* p,
                 uint64_t& pulseId, uint64_t& timeStamp)
{
    //  char m = p[0]&(0x808<<20) ? 'D':' ';
    if (((p[0]>>16)&0xf)==0) { // EVENT_TAG
        volatile const uint64_t* pl = reinterpret_cast<volatile const uint64_t*>(p+2);
        pulseId = pl[0];
        timeStamp = pl[1];
        return true;
    }
    return false;
}

