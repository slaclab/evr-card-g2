//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC Generic Prom Loader'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Generic Prom Loader', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <linux/types.h>

#include <fcntl.h>
#include <sstream>
#include <string>
#include <iomanip>
#include <iostream>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>

using namespace std;

int main (int argc, char **argv) {

   int fd;
   void volatile *mapStart;
   void volatile *mapVersion;
   void volatile *mapBuild;

   string filePath;
   string devName = argv[1];

   uint32_t i;
   uint32_t firmwareVersion;
   uint32_t BuildStamp[64];
   uint16_t rdBack;

   // Check the number of arguments
   if ( argc != 2 ) {
      cout << "Usage: ./MemoryMapTest device" << endl;
      return(0);
   }

	// Open the PCIe device
   if ( (fd = open(devName.c_str(), (O_RDWR|O_SYNC)) ) <= 0 ) {
      cout << "Error opening " << devName << endl;
      close(fd);
      return(1);
   }

   // Map the PCIe device from Kernel to Userspace
   mapStart = (void volatile *)mmap(NULL, 0x100000, (PROT_READ|PROT_WRITE), MAP_SHARED, fd, 0);
   if(mapStart == MAP_FAILED){
      cout << "Error: mmap() = " << dec << mapStart << endl;
      close(fd);
      return(1);
   }

   mapVersion = (void volatile *)((uint64_t)mapStart+0x10000);// Firmware version
   mapBuild   = (void volatile *)((uint64_t)mapStart+0x10800);// Build string

   firmwareVersion = *((uint32_t*)mapVersion);
   cout << "Firmware Version: 0x" << hex << firmwareVersion << endl;
   for (i=0; i < 64; i++) {
      BuildStamp[i] = *((volatile uint32_t *)((uint64_t)mapBuild + (4*i) ));
   }
   cout << "BuildStamp: "   << string((char *)BuildStamp)  << endl;

   for (i=0; i < 12; i++) {
      *(uint16_t*)(void volatile *)((uint64_t)mapStart+(272*4+2*i)) = (uint16_t)(i+1);
   }

   for (i=0; i < 12; i++) {
      rdBack = *(uint16_t*)(void volatile *)((uint64_t)mapStart+(272*4+2*i));
      if (rdBack != (uint16_t)(i+1)){
         cout << "Passed Failed!" << endl;
         close(fd);
         return(1);
      }
   }

   cout << "Passed test!" << endl;

   close(fd);
   return(0);
}

