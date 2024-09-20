//-----------------------------------------------------------------------------
// File          : McsRead.h
// Author        : Larry Ruckman  <ruckman@slac.stanford.edu>
// Created       : 10/14/2013
// Project       : Generic
//-----------------------------------------------------------------------------
// Description :
//    Generic MCS File reader
//-----------------------------------------------------------------------------
// This file is part of 'SLAC Generic Prom Loader'.
// It is subject to the license terms in the LICENSE.txt file found in the
// top-level directory of this distribution and at:
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
// No part of 'SLAC Generic Prom Loader', including this file,
// may be copied, modified, propagated, or distributed except according to
// the terms contained in the LICENSE.txt file.
//-----------------------------------------------------------------------------
// Modification history :
// 10/14/2013: created
//-----------------------------------------------------------------------------

#ifndef __MCS_READ_H__
#define __MCS_READ_H__

#include <string>
#include <iostream>
#include <fstream>
#include <stdint.h>

using namespace std;

#ifdef __CINT__
#define uint32_t unsigned int
#endif

struct McsReadData {
   uint32_t address;
   uint32_t data;
   bool endOfFile;
} ;

//! Class to contain generic register data.
class McsRead {
   public:

      //! Constructor
      McsRead ( );

      //! Deconstructor
      ~McsRead ( );

      //! Open File
      bool open ( string filePath);

      //! Close File
      void close ( );

      //! Moves the ifstream to beginning of file
      void beg ( );

      //! Get Address space information
      uint32_t startAddr ( );
      uint32_t endAddr ( );
      uint32_t addrSize ( );

      //! Reads next byte
      int32_t read (McsReadData *mem);

   private:
      //! Get next data record
      int32_t next ( );

      ifstream file;

      uint32_t promPntr;
      uint32_t promBaseAddr;
      uint32_t promLastAddr;
      uint32_t promData[16];
      uint32_t promAddr[16];

      bool endOfFile;
};
#endif
