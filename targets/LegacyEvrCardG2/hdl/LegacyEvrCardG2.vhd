-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : LegacyEvrCardG2.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2015-10-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC EVR Gen2'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC EVR Gen2', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

entity LegacyEvrCardG2 is
   generic (
      TPD_G : time := 1 ns); 
   port (
      -- XADC Ports
      vPIn       : in    sl;
      vNIn       : in    sl;
      -- Boot Memory Ports
      flashData  : inout slv(15 downto 0);
      flashAddr  : out   slv(23 downto 0);
      -- flashRs    : inout slv(1 downto 0);
      flashCe    : out   sl;
      flashOe    : out   sl;
      flashWe    : out   sl;
      flashAdv   : out   sl;
      flashWait  : in    sl;
      -- Crossbar Ports
      xBarSin    : out   slv(1 downto 0);
      xBarSout   : out   slv(1 downto 0);
      xBarConfig : out   sl;
      xBarLoad   : out   sl;
      -- PCIe Ports
      pciRstL    : in    sl;
      pciRefClkP : in    sl;
      pciRefClkN : in    sl;
      pciRxP     : in    slv(3 downto 0);
      pciRxN     : in    slv(3 downto 0);
      pciTxP     : out   slv(3 downto 0);
      pciTxN     : out   slv(3 downto 0);
      -- EVR Ports
      evrRefClkP : in    slv(1 downto 0);
      evrRefClkN : in    slv(1 downto 0);
      evrRxP     : in    slv(1 downto 0);
      evrRxN     : in    slv(1 downto 0);
      evrTxP     : out   slv(1 downto 0);
      evrTxN     : out   slv(1 downto 0);
      -- Trigger and Sync Port
      syncL      : in    sl;
      trigOut    : out   slv(11 downto 0);
      -- Misc.
      debugIn    : out   slv(11 downto 0);
      ledRedL    : out   slv(1 downto 0);
      ledGreenL  : out   slv(1 downto 0);
      ledBlueL   : out   slv(1 downto 0);
      testPoint  : out   sl);  
end LegacyEvrCardG2;

architecture top_level of LegacyEvrCardG2 is

begin

   EvrCardG2Core_Inst : entity work.EvrCardG2Core
      generic map (
         TPD_G => TPD_G) 
      port map (
         -- XADC Ports
         vPIn       => vPIn,
         vNIn       => vNIn,
         -- FLASH Interface 
         flashData  => flashData,
         flashAddr  => flashAddr,
         -- flashRs    => flashRs,
         flashAdv   => flashAdv,
         flashCe    => flashCe,
         flashOe    => flashOe,
         flashWe    => flashWe,
         flashWait  => flashWait,
         -- Crossbar Ports
         xBarSin    => xBarSin,
         xBarSout   => xBarSout,
         xBarConfig => xBarConfig,
         xBarLoad   => xBarLoad,
         -- PCIe Ports
         pciRstL    => pciRstL,
         pciRefClkP => pciRefClkP,
         pciRefClkN => pciRefClkN,
         pciRxP     => pciRxP,
         pciRxN     => pciRxN,
         pciTxP     => pciTxP,
         pciTxN     => pciTxN,
         -- EVR Ports
         evrRefClkP => evrRefClkP,
         evrRefClkN => evrRefClkN,
         evrRxP     => evrRxP,
         evrRxN     => evrRxN,
         evrTxP     => evrTxP,
         evrTxN     => evrTxN,
         -- Trigger and Sync Port
         syncL      => syncL,
         trigOut    => trigOut,
         -- Misc.
         debugIn    => debugIn,
         ledRedL    => ledRedL,
         ledGreenL  => ledGreenL,
         ledBlueL   => ledBlueL,
         testPoint  => testPoint);        

end top_level;
