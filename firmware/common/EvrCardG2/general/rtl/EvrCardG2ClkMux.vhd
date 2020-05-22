-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2ClkMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2017-03-02
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity EvrCardG2ClkMux is
   generic (
      TPD_G   : time    := 1 ns );
   port (
      clkSel     : in  sl;
      -- Clock
      recClkIn   : in  slv(1 downto 0);
      recRstIn   : in  slv(1 downto 0);
      recClkOut  : out sl;
      recRstOut  : out sl;
      -- Status
      sGoodL     : out sl;
      sBadL      : out sl );
end EvrCardG2ClkMux;

architecture mapping of EvrCardG2ClkMux is

   signal clk, clkOut0, clkFbO, clkFbI : sl;
   signal locked : sl;
   signal rstInLoc : sl;
   
begin

   sGoodL <= not locked;
   
   U_CLKBUFG : BUFG
   port map (
     O  => clk,
     I  => clkOut0 );

   U_CLKFBBUFG : BUFG
   port map (
     O  => clkFbI,
     I  => clkFbO );

   -- This is now essentially just a BUFG_MUX
   -- Should try and use as a PLL (BANDWIDTH => "LOW")
   U_MMCM : MMCME2_ADV
     generic map ( CLKFBOUT_MULT_F      => 6.0,
                   CLKFBOUT_USE_FINE_PS => true,
                   CLKIN1_PERIOD        => 5.6,
                   CLKIN2_PERIOD        => 8.4,
                   CLKOUT0_DIVIDE_F     => 6.0 )
     port map ( CLKFBOUT   => clkFbO,
                CLKOUT0    => clkOut0,
                LOCKED     => locked,
                CLKFBIN    => clkFbI,
                CLKIN1     => recClkIn(1),
                CLKIN2     => recClkIn(0),
                CLKINSEL   => clkSel,
                DADDR      => (others=>'0'),
                DCLK       => '0',
                DEN        => '0',
                DI         => (others=>'0'),
                DWE        => '0',
                PSCLK      => '0',
                PSEN       => '0',
                PSINCDEC   => '0',
                PWRDWN     => '0',
                RST        => rstInLoc );

   rstInLoc <= recRstIn(0) when clkSel='0' else
               recRstIn(1);
                
   U_RstSyncO : entity surf.RstSync
     port map ( clk      => clk,
                asyncRst => rstInLoc,
                syncrst  => recRstOut );
                
   seqR: process (clk) is
     variable v : slv(26 downto 0) := (others=>'0');
   begin
     if rising_edge(clk) then
       sBadL   <= '0';
       if locked='0' then
         v := (others=>'1');
       elsif (uOr(v)='1') then
         v := v-1;
       else
         sBadL <= '1';
       end if;
     end if;
   end process seqR;
       
end mapping;
