//-----------------------------------------------------------------------------
// File          : EvrCardG2Prom.h
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

#ifndef __EVRCARDG2_PROM_H__
#define __EVRCARDG2_PROM_H__

#include <sys/stat.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <linux/types.h>

#include <string.h>
#include <stdint.h>

using namespace std;

//! Class to contain generic register data.
class EvrCardG2Prom {
   public:

      //! Constructor
      EvrCardG2Prom (void volatile *mapStart, string pathToFile );

      //! Deconstructor
      ~EvrCardG2Prom ( );

      //! Check for a valid firmware version
      bool checkFirmwareVersion ( );

      //! Check if file exist
      bool fileExist ( );

      //! Erase the PROM
      void eraseBootProm ( );

      //! Write the .mcs file to the PROM
      bool bufferedWriteBootProm ( );

      //! Compare the .mcs file with the PROM
      bool verifyBootProm ( );

      //! Print Reminder
      void rebootReminder ( );

   private:
      // Local Variables
      string filePath;
      void volatile *mapVersion;
      void volatile *mapBuild;
      void volatile *mapData;
      void volatile *mapAddress;
      void volatile *mapRead;

      //! Erase Command
      void eraseCommand(uint32_t address);

      //! Program Command
      void programCommand(uint32_t address, uint16_t data);

      //! Buffered Program Command
      void bufferedProgramCommand(uint32_t *address, uint16_t *data, uint16_t size);

      //! Read FLASH memory Command
      uint16_t readWordCommand(uint32_t address);

      //! Generate request word
      uint32_t genReqWord(uint16_t cmd, uint16_t data);

      //! Generic FLASH write Command
      void writeToFlash(uint32_t address, uint16_t cmd, uint16_t data);

      //! Generic FLASH read Command
      uint16_t readFlash(uint32_t address, uint16_t cmd);
};
#endif
