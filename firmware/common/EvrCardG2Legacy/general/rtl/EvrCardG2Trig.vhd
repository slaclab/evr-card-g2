-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Trig.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2015-10-19
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


library surf;
use surf.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity EvrCardG2Trig is
   generic (
      TPD_G : time := 1 ns); 
   port (
      evrModeSel : in  sl;
      -- Clock
      evrRecClk  : in  slv(1 downto 0);
      -- Trigger Inputs
      trigIn     : in  Slv12Array(1 downto 0);
      trigout    : out slv(11 downto 0));
end EvrCardG2Trig;

architecture mapping of EvrCardG2Trig is

   signal clk     : sl;
   signal trig    : slv(11 downto 0);
   signal trigger : slv(11 downto 0);

begin

   -- Select the trigger path
   -- Note: Legacy software requires inverting LCLS-I trigger
   --       and it's still TBD if we need to do the same for
   --       the LCLS-II trigger as well
   -- trig <= not(trigIn(0)) when(evrModeSel = '0') else trigIn(1);
   trig <= not(trigIn(0));

   -- BUFGMUX_inst : BUFGMUX
   -- port map (
   -- O  => clk,                     -- 1-bit output: Clock output
   -- I0 => evrRecClk(0),            -- 1-bit input: Clock input (S=0)
   -- I1 => evrRecClk(1),            -- 1-bit input: Clock input (S=1)
   -- S  => evrModeSel);             -- 1-bit input: Clock select

   clk <= evrRecClk(0);

   OR_TRIG :
   for i in 11 downto 0 generate
      
      U_ODDR : ODDR
         generic map(
            DDR_CLK_EDGE => "SAME_EDGE")
         port map (
            C  => clk,
            Q  => trigger(i),
            CE => '1',
            D1 => trig(i),
            D2 => trig(i),
            R  => '0',
            S  => '0');

      U_OBUF : OBUF
         port map (
            I => trigger(i),
            O => trigout(i));

   end generate OR_TRIG;

end mapping;
