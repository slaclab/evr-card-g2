-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpClkRef.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2016-04-05
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

library unisim;
use unisim.vcomponents.all;

entity PgpClkRef is
   generic (
      TPD_G : time := 1 ns); 
   port (
      -- PGP Reference
      pgpRefClkP   : in  sl;
      pgpRefClkN   : in  sl;
      pgpHeartBeat : out sl;
      pgpClk       : out sl;
      pgpRst       : out sl;
      pgpRefClk    : out sl);
end PgpClkRef;

architecture mapping of PgpClkRef is

   signal pciRefClock : sl;
   signal pgpClock    : sl;
   signal pgpReset    : sl;
   signal pgpResetL   : sl;

begin

   pgpRefClk <= pciRefClock;
   pgpClk    <= pgpClock;
   pgpRst    <= pgpReset;

   U_IBUFDS : IBUFDS_GTE2
      port map(
         I     => pgpRefClkP,
         IB    => pgpRefClkN,
         CEB   => '0',
         O     => open,
         ODIV2 => pciRefClock);        

   U_BUFG : BUFG
      port map(
         I => pciRefClock,
         O => pgpClock);    

   U_PwrUpRst : entity work.PwrUpRst
      generic map(
         TPD_G => TPD_G)
      port map(
         clk    => pgpClock,
         rstOut => pgpReset);   

   -- Forcing the heartbeat always be disabled after power
   -- to prevent accidental noise on the board
   pgpResetL <= not(pgpReset);

   U_Heartbeat : entity work.Heartbeat
      generic map(
         TPD_G        => TPD_G,
         PERIOD_IN_G  => 6.4E-9,
         PERIOD_OUT_G => 1.0)
      port map(
         clk => pgpClock,
         rst => pgpResetL,
         o   => pgpHeartBeat);

end mapping;
