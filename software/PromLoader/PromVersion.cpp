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
#include <unistd.h>

#include "EvrCardG2Prom.h"
extern int PromVersion(volatile void *mapStart);

using namespace std;

int main (int argc, char **argv) {

   int fd;
   void volatile *mapStart;
   string devName;

   // Check the number of arguments
   if ( argc != 2 ) {
      cout << "Usage: ./PromVersion device" << endl;
      return(0);
   }
   devName  = argv[1];

	// Open the PCIe device
  cout << "Opening " << devName << endl;
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

   int status = PromVersion( mapStart );
   close(fd);
   return(status);
}


int PromVersion(volatile void *mapStart)
{
//  cout << "mapStart = 0x" << hex << mapStart << endl;
   if(mapStart == MAP_FAILED){
      cout << "Error: mmap() = " << dec << mapStart << endl;
      return(1);
   }

   cout << "Creating EvrCardG2Prom" << endl;
   // Create the EvrCardG2Prom object
   EvrCardG2Prom *prom;
   prom = new EvrCardG2Prom(mapStart,"NoImage");

   // Check if the PCIe device is a generation 2 card
   if(!prom->checkFirmwareVersion()){
      cout << "checkFirmwareVersion Error: Not a gen 2 card!" << endl;
      delete prom;
      return(1);
   }

	// Close all the devices
   delete prom;
   return(0);
}
