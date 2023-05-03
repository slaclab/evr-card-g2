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
#include "PromLoad.h"

using namespace std;

#define PAGE_SIZE sysconf(_SC_PAGE_SIZE)

int main (int argc, char **argv) {

   int fd;
   void volatile *mapStart;
   string filePath;
   string devName;

   // Check the number of arguments
   if ( argc != 3 ) {
      cout << "Usage: ./PromLoad device filePath" << endl;
      return(0);
   }
   devName  = argv[1];
   filePath = argv[2];

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

   int status = PromLoad( mapStart, filePath );
   close(fd);
   return(status);
}


int PromLoad (volatile void *mapStart, string filePath)
{
//  cout << "mapStart = 0x" << hex << mapStart << endl;
   if(mapStart == MAP_FAILED){
      cout << "Error: mmap() = " << dec << mapStart << endl;
      return(1);
   }

   cout << "Creating EvrCardG2Prom" << endl;
   // Create the EvrCardG2Prom object
   EvrCardG2Prom *prom;
   prom = new EvrCardG2Prom(mapStart,filePath);

   // Check if the .mcs file exists
   if(!prom->fileExist()){
      cout << "Error opening: " << filePath << endl;
      delete prom;
      return(1);
   }

   uint32_t	promSize = prom->getPromSize(filePath);
   cout << "promSize = 0x" << hex << promSize << endl;
#if 0
   // Get & Set the FPGA's PROM code size
   prom->setPromSize(promSize);
#endif

   // Check if the PCIe device is a generation 2 card
   if(!prom->checkFirmwareVersion()){
      cout << "checkFirmwareVersion Error: Not a gen 2 card!" << endl;
      delete prom;
      return(1);
   }

   // Erase the PROM
   prom->eraseBootProm();

   // Write the .mcs file to the PROM
   if(!prom->bufferedWriteBootProm()) {
      cout << "Error in prom->bufferedWriteBootProm() function" << endl;
      delete prom;
      return(1);
   }

   // Compare the .mcs file with the PROM
   if(!prom->verifyBootProm()) {
      cout << "Error in prom->verifyBootProm() function" << endl;
      delete prom;
      return(1);
   }

   // Display Reminder
   prom->rebootReminder();

   // Mapping the reboot register
   void volatile *reboot = (void volatile *)((uint64_t)mapStart+0x10104);

   // Reboot the FGPA
   *((uint32_t*)reboot) = 0x1;

	// Close all the devices
   delete prom;
   return(0);
}
