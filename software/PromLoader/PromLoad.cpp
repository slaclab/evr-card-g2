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

using namespace std;

#define PAGE_SIZE sysconf(_SC_PAGE_SIZE)

int main (int argc, char **argv) {

   int fd;
   void volatile *mapStart;
   void volatile *reboot;
   EvrCardG2Prom *prom;
   string filePath;
   string devName = argv[1];

   // Check the number of arguments
   if ( argc != 3 ) {
      cout << "Usage: ./PromLoad device filePath" << endl;
      return(0);
   }     
   devName  = argv[1];
   filePath = argv[2];

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
   
   // Mapping the reboot register
   reboot = (void volatile *)((uint64_t)mapStart+0x1001C);
   
   // Create the EvrCardG2Prom object
   prom = new EvrCardG2Prom(mapStart,filePath);
   
   // Check if the .mcs file exists
   if(!prom->fileExist()){
      cout << "Error opening: " << filePath << endl;
      delete prom;
      close(fd);
      return(1);   
   }   
   
   // Check if the PCIe device is a generation 2 card
   if(!prom->checkFirmwareVersion()){
      delete prom;
      close(fd);
      return(1);   
   }    
      
   // Erase the PROM
   prom->eraseBootProm();
  
   // Write the .mcs file to the PROM
   if(!prom->bufferedWriteBootProm()) {
      cout << "Error in prom->bufferedWriteBootProm() function" << endl;
      delete prom;
      close(fd);
      return(1);     
   }   

   // Compare the .mcs file with the PROM
   if(!prom->verifyBootProm()) {
      cout << "Error in prom->verifyBootProm() function" << endl;
      delete prom;
      close(fd);
      return(1);     
   }
      
   // Display Reminder
   prom->rebootReminder();

   // Reboot the FGPA
   *((uint32_t*)reboot) = 0x1;   
   
	// Close all the devices
   delete prom;
   close(fd);   
   return(0);
}
