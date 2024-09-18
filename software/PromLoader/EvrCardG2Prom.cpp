//-----------------------------------------------------------------------------
// File          : EvrCardG2Prom.cpp
// Author        : Larry Ruckman  <ruckman@slac.stanford.edu>
// Created       : 07/24/2015
// Project       :
//-----------------------------------------------------------------------------
// Description :
//    EvrCardG2 PROM C++ Class
//-----------------------------------------------------------------------------
// This file is part of 'SLAC Generic Prom Loader'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Generic Prom Loader', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
// Proprietary and confidential to SLAC.
//-----------------------------------------------------------------------------
// Modification history :
// 07/24/2015: created
//-----------------------------------------------------------------------------

#include <sstream>
#include <string>
#include <iostream>
#include <string.h>
#include <stdlib.h>
#include <iomanip>
#include <unistd.h>
#include <cmath>

#include "EvrCardG2Prom.h"
#include "McsRead.h"

using namespace std;

#define GEN2_PROM_VERSION  0xCED20000
#define GEN2_MASK          (GEN2_PROM_VERSION >> 12)
#define PROM_BLOCK_SIZE    0x4000 // Assume the smallest block size of 16-kword/block
#define READ_MASK          0x80000000
#define PROM_SIZE          0x002DF2FB

// Configuration: Force default configurations
#define CONFIG_REG      0xFD4F

// Constructor
EvrCardG2Prom::EvrCardG2Prom (volatile void *mapStart, string pathToFile )
{
   // Set the file path
   filePath = pathToFile;

   // Default PROM size without user data
   promSize_      = PROM_SIZE;

   // Default PROM type = Legacy (TRUE)
   promType_ = true;

   // Setup the register Mapping
   mapVersion = (volatile void  *)((uint64_t)mapStart+0x10000);// Firmware version
   mapPromType= (volatile void  *)((uint64_t)mapStart+0x10400);// PROM Type
   mapBuild   = (volatile void  *)((uint64_t)mapStart+0x10800);// Build string
   mapData    = (volatile void  *)((uint64_t)mapStart+0x20000);// Write Cmd/Data Bus
   mapAddress = (volatile void  *)((uint64_t)mapStart+0x20004);// Write/Read CMD + Address Bus
   mapRead    = (volatile void  *)((uint64_t)mapStart+0x20008);// Read Data Bus
   mapTest    = (volatile void  *)((uint64_t)mapStart+0x2000C);// Test Reg

   // Setup the configuration Register
   writeToFlash(CONFIG_REG,0x60,0x03);
}

// Deconstructor
EvrCardG2Prom::~EvrCardG2Prom ( ) {
}

void EvrCardG2Prom::setPromSize (uint32_t promSize) {
   promSize_ = promSize;
}

uint32_t EvrCardG2Prom::getPromSize (string pathToFile) {
   McsRead mcsReader;
   uint32_t retVar;
   printf("Current PROM Size = 0x%08x\n", promSize_);
   mcsReader.open(pathToFile);
   printf("Calculating PROM file (.mcs) Memory Address size ...\n");
   retVar = mcsReader.addrSize();
   printf("Calculated PROM Size = 0x%08x\n", retVar);
   mcsReader.close();
   return retVar;
}

//! Check for a valid firmware version  (true=valid firmware version)
bool EvrCardG2Prom::checkFirmwareVersion ( ) {
   uint32_t firmwareVersion = *((volatile uint32_t *)mapVersion);
   uint32_t promType = *((volatile uint32_t *)mapPromType);
   uint32_t EvrCardGen = firmwareVersion >> 12;
   uint32_t i;
   uint32_t BuildStamp[64];

   if(EvrCardGen==GEN2_MASK){
      cout << "Found Gen 2 EVR card!" << endl;
   }
   cout << "*******************************************************************" << endl;
   cout << "Current Firmware Version on the FPGA: 0x" << hex << firmwareVersion << endl;
   for (i=0; i < 64; i++) {
      BuildStamp[i] = *((volatile uint32_t *)((uint64_t)mapBuild + (4*i) ));
   }
   cout << "Current BuildStamp: "   << string((char *)BuildStamp)  << endl;

//   return true;
   if(EvrCardGen!=GEN2_MASK){
   cout << "*******************************************************************" << endl;
      cout << "Error: Not a generation 2 EVR card" << endl;
      return false;
   }

   if(firmwareVersion<0xCED20030) {
      // PROM type = Legacy (TRUE)
      promType_ = true;
   } else {
      // PROM type = PROM_VERSION FPGA input pin
      promType_ = bool(promType&0x1);
   }

   if(promType_){
      cout << "Legacy PROM TYPE Detected!!!" << endl;
      // Enable CMD
      *((volatile uint32_t *)mapTest) = 0x0;
   } else {
      cout << "New PROM TYPE Detected!!!" << endl;
      // bypass CMD
      *((volatile uint32_t *)mapTest) = 0x1;
      resetProm();
   }

   return true;
}

//! Check if file exist (true=exists)
bool EvrCardG2Prom::fileExist ( ) {
  ifstream ifile(filePath.c_str());
  return ifile.is_open();
}

//! Print Power Cycle Reminder
void EvrCardG2Prom::rebootReminder ( ) {
   cout << "\n\n\n\n\n";
   cout << "***************************************" << endl;
   cout << "***************************************" << endl;
   cout << "A power cycle (or 'COLD' reboot) is required " << endl;
   cout << "to load new into the PCIe card's FPGA." << endl;
   cout << "***************************************" << endl;
   cout << "***************************************" << endl;
   cout << "\n\n\n\n\n";
}

//! Erase the PROM
void EvrCardG2Prom::eraseBootProm ( ) {

   uint32_t address = 0;
   double size = double(promSize_);

   cout << "*******************************************************************" << endl;
   cout << "Starting Erasing ..." << endl;

   if(promType_){

      while(address<=promSize_) {
         // Print the status to screen
         cout << hex << "Erasing PROM from 0x" << address << " to 0x" << (address+PROM_BLOCK_SIZE-1);
         cout << setprecision(3) << " ( " << ((double(address))/size)*100 << " percent done )" << endl;

         // execute the erase command
         eraseCommand(address);

         //increment the address pointer
         address += PROM_BLOCK_SIZE;
      }

   } else {
      // ENTER NONVOLATILE PROTECTION COMMAND SET (C0h)
      writeToFlash(0x555,0,0xAA);
      writeToFlash(0x2AA,0,0x55);
      writeToFlash(0x555,0,0xC0);
      usleep(1);
      // CLEAR ALL NONVOLATILE PROTECTION BITS (80h/30h)
      writeToFlash(0x555,0,0x80);
      writeToFlash(0x000,0,0x30);
      sleep(2); // Clear nonvolatile protection bit time (max) = 1100 ms
      // EXIT LOCK REGISTER (90h/00h)
      writeToFlash(0x000,0,0x90);
      writeToFlash(0x000,0,0x00);
      usleep(1);
      // CHIP ERASE (80/10h)
      writeToFlash(0x555,0,0xAA);
      writeToFlash(0x2AA,0,0x55);
      writeToFlash(0x555,0,0x80);
      writeToFlash(0x555,0,0xAA);
      writeToFlash(0x2AA,0,0x55);
      writeToFlash(0x555,0,0x10);

      // Typical timeout for full chip erase = 66s
      // Maximum timeout for full chip erase = 528s
      for (int i=0; i<20; i++) {
         // Print the status to screen
         cout << hex << "Erasing PROM: " << round(100.0*float(3*i)/60.0) << " percent done " << endl;
         sleep(6);
      }
   }
   cout << "Erasing completed" << endl;
}

//! Write the .mcs file to the PROM
bool EvrCardG2Prom::bufferedWriteBootProm ( ) {
   cout << "*******************************************************************" << endl;
   cout << "Starting Writing ..." << endl;
   McsRead mcsReader;
   McsReadData mem;

   uint32_t address = 0;
   uint16_t fileData;
   uint16_t i;

   uint32_t bufAddr[256];
   uint16_t bufData[256];
   uint16_t bufSize = 0;

   double size = double(promSize_);
   double percentage;
   double skim = 5.0;
   bool   toggle = false;

   //check for valid file path
   if ( !mcsReader.open(filePath) ) {
      mcsReader.close();
      cout << "mcsReader.close() = file path error" << endl;
      return false;
   }

   //reset the flags
   mem.endOfFile = false;

   //read the entire mcs file
   while(!mem.endOfFile) {

      //read a line of the mcs file
      if (mcsReader.read(&mem)<0){
         cout << "mcsReader.close() = line read error" << endl;
         mcsReader.close();
         return false;
      }

      // Check if this is the upper or lower byte
      if(!toggle) {
         toggle = true;
         fileData = (uint16_t)mem.data;
      } else {
         toggle = false;
         fileData |= ((uint16_t)mem.data << 8);

         // Latch the values
         bufAddr[bufSize] = address;
         bufData[bufSize] = fileData;
         bufSize++;

         // Check if we need to send the buffer
         if(bufSize==256) {
            bufferedProgramCommand(bufAddr,bufData,bufSize);
            bufSize = 0;
         }

         address++;
         percentage = (((double)address)/size)*100;
         percentage *= 2.0;//factor of two from two 8-bit reads for every write 16 bit write
         if(percentage>=skim) {
            skim += 5.0;
            cout << "Writing the PROM: " << round(percentage) << " percent done" << endl;
         }
      }
   }

   // Check if we need to send the buffer
   if(bufSize != 0) {
      // Pad the end of the block with ones
      for(i=bufSize;i<256;i++){
         bufData[bufSize] = 0xFFFF;
      }
      // Send the last block program
      bufferedProgramCommand(bufAddr,bufData,256);
   }

   mcsReader.close();
   cout << "Writing completed" << endl;
   return true;
}

//! Compare the .mcs file with the PROM (true=matches)
bool EvrCardG2Prom::verifyBootProm ( ) {
   cout << "*******************************************************************" << endl;
   cout << "Starting Verification ..." << endl;
   McsRead mcsReader;
   McsReadData mem;

   uint32_t address = 0;
   uint16_t promData,fileData;
   double size = double(promSize_);
   double percentage;
   double skim = 5.0;
   bool   toggle = false;

   //check for valid file path
   if ( !mcsReader.open(filePath) ) {
      mcsReader.close();
      cout << "mcsReader.close() = file path error" << endl;
      return(1);
   }

   //reset the flags
   mem.endOfFile = false;

   //read the entire mcs file
   while(!mem.endOfFile) {

      //read a line of the mcs file
      if (mcsReader.read(&mem)<0){
         cout << "mcsReader.close() = line read error" << endl;
         mcsReader.close();
         return false;
      }

      // Check if this is the upper or lower byte
      if(!toggle) {
         toggle = true;
         fileData = (uint16_t)mem.data;
      } else {
         toggle = false;
         fileData |= ((uint16_t)mem.data << 8);
         promData = readWordCommand(address);
         if(fileData != promData) {
            cout << "verifyBootProm error = ";
            cout << "invalid read back" <<  endl;
            cout << hex << "\taddress: 0x"  << address << endl;
            cout << hex << "\tfileData: 0x" << fileData << endl;
            cout << hex << "\tpromData: 0x" << promData << endl;
            mcsReader.close();
            return false;
         }
         address++;
         percentage = (((double)address)/size)*100;
         percentage *= 2.0;//factore of two from two 8-bit reads for every write 16 bit write
         if(percentage>=skim) {
            skim += 5.0;
            cout << "Verifying the PROM: " << round(percentage) << " percent done" << endl;
         }
      }
   }

   mcsReader.close();
   cout << "Verification completed" << endl;
   cout << "*******************************************************************" << endl;
   return true;
}

//! Erase Command
void EvrCardG2Prom::eraseCommand(uint32_t address) {
   uint16_t status = 0;

   // Unlock the Block
   writeToFlash(address,0x60,0xD0);

   // Reset the status register
   writeToFlash(address,0x50,0x50);

   // Send the erase command
   writeToFlash(address,0x20,0xD0);

   while(1) {
      // Get the status register
      status = readFlash(address,0x70);

      // Check for erasing failure
      if ( (status&0x20) != 0 ) {

         // Unlock the Block
         writeToFlash(address,0x60,0xD0);

         // Reset the status register
         writeToFlash(address,0x50,0x50);

         // Send the erase command
         writeToFlash(address,0x20,0xD0);

      // Check for FLASH not busy
      } else if ( (status&0x80) != 0 ) {
         break;
      }
   }

   // Lock the Block
   writeToFlash(address,0x60,0x01);
}

//! Program Command
void EvrCardG2Prom::programCommand(uint32_t address, uint16_t data) {
   uint16_t status = 0;

   // Unlock the Block
   writeToFlash(address,0x60,0xD0);

   // Reset the status register
   writeToFlash(address,0x50,0x50);

   // Send the program command
   writeToFlash(address,0x40,data);

   while(1) {
      // Get the status register
      status = readFlash(address,0x70);

      // Check for programming failure
      if ( (status&0x10) != 0 ) {

         // Unlock the Block
         writeToFlash(address,0x60,0xD0);

         // Reset the status register
         writeToFlash(address,0x50,0x50);

         // Send the program command
         writeToFlash(address,0x40,data);

      // Check for FLASH not busy
      } else if ( (status&0x80) != 0 ) {
         break;
      }
   }

   // Lock the Block
   writeToFlash(address,0x60,0x01);
}

//! Buffered Program Command
void EvrCardG2Prom::bufferedProgramCommand(uint32_t *address, uint16_t *data, uint16_t size) {
   uint16_t status = 0;
   uint16_t i;

   if(promType_){

      // Unlock the Block
      writeToFlash(address[0],0x60,0xD0);

      // Reset the status register
      writeToFlash(address[0],0x50,0x50);

      // Send the buffer program command and size
      writeToFlash(address[0],0xE8,(size-1));

      // Load the buffer
      for(i=0;i<size;i++) {
         readFlash(address[i],data[i]);
      }

      // Confirm buffer programming
      readFlash(address[0],0xD0);

      while(1) {
         // Get the status register
         status = readFlash(address[0],0x70);

         // Check for programming failure
         if ( (status&0x10) != 0 ) {

            // Unlock the Block
            writeToFlash(address[0],0x60,0xD0);

            // Reset the status register
            writeToFlash(address[0],0x50,0x50);

            // Send the buffer program command and size
            writeToFlash(address[0],0xE8,(size-1));

            // Load the buffer
            for(i=0;i<size;i++) {
               readFlash(address[i],data[i]);
            }

            // Confirm buffer programming
            readFlash(address[0],0xD0);

         // Check for FLASH not busy
         } else if ( (status&0x80) != 0 ) {
            break;
         }
      }

      // Lock the Block
      writeToFlash(address[0],0x60,0x01);

   } else {

      // WRITE TO BUFFER PROGRAM (25h)
      writeToFlash(0x555,0,0xAA);
      writeToFlash(0x2AA,0,0x55);
      writeToFlash(address[0],0,0x25);
      writeToFlash(address[0],0,(size-1));
      usleep(1);

      // Loop through the buffer data
      for (i=0; i<size; i++) {
         writeToFlash(address[i],0,data[i]);
      }
      usleep(1);

      // WRITE TO BUFFER PROGRAM CONFIRM (29h)
      writeToFlash(address[0],0,0x29);

      // Typical timeout for buffer program = 512μs
      // Maximum timeout for buffer program = 2048μs
      usleep(2048);
   }
}

//! Read FLASH memory Command
uint16_t EvrCardG2Prom::readWordCommand(uint32_t address) {
   return readFlash(address,0xFF);
}

//! Generate request word
uint32_t EvrCardG2Prom::genReqWord(uint16_t cmd, uint16_t data) {
   uint32_t readReq;
   readReq = ( ((uint32_t)cmd << 16) | ((uint32_t)data) );
   return readReq;
}

//! Generic FLASH write Command
void EvrCardG2Prom::writeToFlash(uint32_t address, uint16_t cmd, uint16_t data) {
//   cout << "writeToFlash( 0x"<<hex<<address << ", 0x" << cmd << ", 0x" << data << ")" << endl;
   // Set the data bus
   *((volatile uint32_t *)mapData) = genReqWord(cmd,data);

   // Set the address bus and initiate the transfer
   *((volatile uint32_t *)mapAddress) = (~READ_MASK & address);
}

//! Generic FLASH read Command
uint16_t EvrCardG2Prom::readFlash(uint32_t address, uint16_t cmd) {
   uint32_t readReg;

   // Set the data bus
   *((volatile uint32_t *)mapData) = genReqWord(cmd,0xFF);

   // Set the address bus and initiate the transfer
   *((volatile uint32_t *)mapAddress) = (READ_MASK | address);

   // Read the data register
   readReg = *((volatile uint32_t *)mapRead);

   // return the readout data
   return (uint16_t)(readReg&0xFFFF);
}

//! Reset the PROM (new PROM only)
void EvrCardG2Prom::resetProm() {
   writeToFlash(0x1A2,0,0xFFFF);
   writeToFlash(0x555,0,0xAA);
   writeToFlash(0x2AA,0,0x55);
   writeToFlash(0x000,0,0xF0);
}
