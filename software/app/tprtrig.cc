//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC EVR Gen2'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC EVR Gen2', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
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
static bool verbose = false;

extern int optind;

static void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options: -d <a..z> : /dev/tpr<arg>[0..a]\n");
  printf("         -f <output>,<delay>,<width>,<fixed rate>[,<polarity>]       : trigger on fixed rate marker\n");
  printf("         -a <output>,<delay>,<width>,<ac rate>,<tsmask>[,<polarity>] : trigger on AC rate marker\n");
  printf("         -s <output>,<delay>,<width>,<seq>,<bit>[,<polarity>]        : trigger on sequence marker\n");
  printf("         -g <output>,<delay>,<width>,<group>[,<polarity>]            : trigger on readout group\n");
  printf("         -b <output>,<delay>,<width>[,<polarity>]                    : trigger on beam\n");
  printf("         -1 : NC timing\n");
  printf("         -2 : SC timing (default)\n");
  printf("         -v : verbose\n");
  printf("  output [0..11]\n");
  printf("  delay,width [ns]\n");
  printf("  polarity [0(neg),1(pos)]\n");
}

static char _dump[256];

class PulseConfig {
public:
  PulseConfig(char*& arg) 
  { char* endPtr;
    output=strtoul(arg,&endPtr,0);
    delay =strtod (endPtr+1,&endPtr);
    width =strtod (endPtr+1,&endPtr);
    polarity = 0;
    arg = endPtr;
  }
  unsigned output;
  float    delay;
  float    width;
  unsigned polarity;
public:
    const char* dump() const {
        sprintf(_dump," out %x delay %f ns  width %f ns  polarity %u\n",
                output,delay,width,polarity);
        return _dump;
    }
};

class FixedRateConfig {
public:
  FixedRateConfig(char*& arg) : pulse(arg)
  { char* endPtr = arg;
    rate = strtoul(endPtr+1,&endPtr,0);
    pulse.polarity = (*endPtr==',') ? strtoul(endPtr+1,&endPtr,0) : 0;
    arg = endPtr+1;
  }
  unsigned    rate;
  PulseConfig pulse;
public:
    void dump() const { printf("f %u, %s\n",rate,pulse.dump()); }
};

class ACRateConfig {
public:
  ACRateConfig(char*& arg) : pulse(arg)
  { char* endPtr = arg;
    rate   = strtoul(endPtr+1,&endPtr,0);
    tsmask = strtoul(endPtr+1,&endPtr,0);
    pulse.polarity = (*endPtr==',') ? strtoul(endPtr+1,&endPtr,0) : 0;
  }
  unsigned    rate;
  unsigned    tsmask;
  PulseConfig pulse;
};

class SeqConfig {
public:
  SeqConfig(char*& arg) : pulse(arg)
  { char* endPtr = arg;
    seq   = strtoul(endPtr+1,&endPtr,0);
    bit   = strtoul(endPtr+1,&endPtr,0);
    pulse.polarity = (*endPtr==',') ? strtoul(endPtr+1,&endPtr,0) : 0;
  }
  unsigned    seq;
  unsigned    bit;
  PulseConfig pulse;
};

class BeamConfig {
public:
  BeamConfig(char*& arg) : pulse(arg)
  { char* endPtr = arg;
    if (verbose) printf("BeamConfig.arg %s\n",endPtr);
    pulse.polarity = (*endPtr==',') ? strtoul(endPtr+1,&endPtr,0) : 0;
  }
  PulseConfig pulse;
public:
    void dump() const { printf("b %s\n",pulse.dump()); }
};

class GroupConfig {
public:
  GroupConfig(char*& arg) : pulse(arg)
  { char* endPtr = arg;
    group = strtoul(endPtr+1,&endPtr,0);
    pulse.polarity = (*endPtr==',') ? strtoul(endPtr+1,&endPtr,0) : 0;
  }
  PulseConfig pulse;
  unsigned    group;
public:
    void dump() const { printf("g %u %s\n",group, pulse.dump()); }
};

static void set_trigger( TprBase&           base,
                         const PulseConfig& c, 
                         unsigned           evtSel)
{
  unsigned udel = c.delay*CLK_FREQ*1.e-9;
  unsigned uwid = c.width*CLK_FREQ*1.e-9;
  unsigned utap = (c.delay*CLK_FREQ*1.e-9 - double(udel))*63;
  base.channel[c.output].evtSel  = evtSel;
  base.channel[c.output].control = 5;
  base.trigger[c.output].control = 0;
  base.trigger[c.output].delay    = udel;
  base.trigger[c.output].delayTap = utap;
  base.trigger[c.output].width    = uwid;
  base.trigger[c.output].control  = (c.output&0xffff) | (1<<31) | (c.polarity ? (1<<16) : 0);
}

static const char* rateStr(unsigned v);

int main(int argc, char** argv) {

  extern char* optarg;
  char tprid='a';

  int c;
  bool lUsage  = false;
  std::vector<FixedRateConfig> fixedRate;
  std::vector<ACRateConfig>    acRate;
  std::vector<SeqConfig>       seq;
  std::vector<BeamConfig>      beam;
  std::vector<GroupConfig>     group;
  bool resetRx = false;
  int clkSel = 1;
  
  while ( (c=getopt( argc, argv, "f:a:s:d:g:b:hvR12?")) != EOF ) {
    switch(c) {
    case 1: clkSel = 0; break;
    case 2: clkSel = 1; break;
    case 'd':
      tprid  = optarg[0];
      if (strlen(optarg) != 1) {
        printf("%s: option `-r' parsing error\n", argv[0]);
        lUsage = true;
      }
      break;
    case 'f':
      fixedRate.push_back(FixedRateConfig(optarg));
      break;
    case 'a':
      acRate.push_back(ACRateConfig(optarg));
      break;
    case 's':
      seq.push_back(SeqConfig(optarg));
      break;
    case 'g':
      group.push_back(GroupConfig(optarg));
      break;
    case 'b':
      beam.push_back(BeamConfig(optarg));
      break;
    case 'v':
      verbose = true;
      break;
    case 'R':
      resetRx = true;
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

    reg.xbar.setEvr( XBar::StraightIn );
    reg.xbar.setEvr( XBar::LoopOut );
    reg.xbar.setTpr( XBar::StraightIn );
    reg.xbar.setTpr( XBar::LoopOut );

    reg.tpr.clkSel(clkSel);
    reg.tpr.modeSel(true);
    reg.tpr.modeSelEn(true);

    reg.tpr.rxPolarity(false);
    if (resetRx)
      reg.tpr.resetRx();

    volatile unsigned vp = reg.tpr.rxPolarity();
    usleep(100000);
    reg.tpr.resetCounts();

    for(unsigned i=0; i<fixedRate.size(); i++)
      set_trigger( reg.base,
                   fixedRate[i].pulse, 
                   (2<<29) | (0<<11) | fixedRate[i].rate);
    // for(unsigned i=0; i<acRate.size(); i++)
    //   set_trigger( reg.base,
    // acRate   [i].pulse, 
    // (2<<29) | (1<<11) | acRate[i].rate);
    for(unsigned i=0; i<seq.size(); i++)
      set_trigger( reg.base,
                   seq      [i].pulse, 
                   (2<<29) | (2<<11) | ((seq[i].seq&0x1f)<<4) | (seq[i].bit&0xf) );
    for(unsigned i=0; i<group.size(); i++)
      set_trigger( reg.base,
                   group    [i].pulse, 
                   (2<<29) | (0x3<<11) | (group[i].group));
    for(unsigned i=0; i<beam.size(); i++)
      set_trigger( reg.base,
                   beam     [i].pulse, 
                   (0<<29) | (0x1<<13));  // beam to dest 0

    //
    //  Dump the status of all trigger channels
    //
    //  Wait for the full measurement
    reg.tpr.dump();
    reg.csr.dump();
    sleep(2);
    reg.tpr.dump();
    reg.csr.dump();

    TprCore last = reg.tpr;
    while(1) {
      sleep(1);
      TprCore curr = reg.tpr;
#define printField(name) printf("%s: %08x\n", #name, curr.name-last.name)
      printField(SOFcounts);
      printField(RxRstDone);
      printField(RxDspErrs);
      last = curr;
      
      printf("%4.4s|%6.6s|%12.12s|%8.8s|%4.4s|%8.8s\n",
	     "Chan","Rate","Delay,ns","Width,ns","Pol","RateMeas");
      for(unsigned i=0; i<Tpr::TprBase::NTRIGGERS; i++) {
	if (reg.base.channel[i].control&1)
	  printf("%4d|%6.6s|%12.2f|%8.2f|%4.4s|%8d\n",
		 i, rateStr(reg.base.channel[i].evtSel),
		 (float(reg.base.trigger[i].delay&0xfffff) +
		  float(reg.base.trigger[i].delayTap&0x3f)/63.)*1.e9/CLK_FREQ,
		 (float(reg.base.trigger[i].width&0xfffff)*1.e9/CLK_FREQ),
		 (reg.base.trigger[i].control&(1<<16)) ? "Pos":"Neg",
		 reg.base.channel[i].evtCount);
      }
    }
  }

  return 0;
}

static char _ratebuff[16];

const char* rateStr(unsigned v)
{
  static const char* _fixed[] = { "1H", "10H", "100H",
                                  "1kH", "10kH", "70kH", "910kH" };

  switch( (v>>29)&3 ) {
  case 0: // Beam
    return "Beam";
  case 1:
    return "NoBeam";
  case 2: {
    switch( (v>>11)&3 ) {
    case 0: // FixedRate
      if ((v&0xf) < 7)
        return _fixed[v&0xf];
      break;
    case 1: // AC rate
      break;
    case 2: // Sequence
      sprintf(_ratebuff,"S%u.%u",(v>>4)&0x1f,v&0xf);
      return _ratebuff;
    case 3: // Group
      sprintf(_ratebuff,"G%u", v&0xf);
      return _ratebuff;
    default:
      break;
    }
  }
  default:
    break;
  }
  return "Unk";
}

