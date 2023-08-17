-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrClkMux.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-10
-- Last update: 2023-06-26
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

library unisim;
use unisim.vcomponents.all;

entity EvrClkMux is
   generic (
     CLKIN_PERIOD_G  : real := 1.0;
     CLK_MULT_F_G    : real := 6.0 );
   port (
      -- AxiLite/DRP interface
      clkSel     : in  sl;
      clkIn0     : in  sl;
      clkIn1     : in  sl;
      rstIn0     : in  sl;
      rstIn1     : in  sl;
      clkOut     : out sl;
      rstOut     : out sl );
end EvrClkMux;

architecture rtl of EvrClkMux is

  signal nclkSel        : sl;
  signal clkOutB        : sl;
  signal crst           : sl;
  signal clkFbO, clkFbI : sl;
  signal clkLocked      : sl;

begin

  nclkSel <= not clkSel;
  rstOut  <= not clkLocked;
  
  U_EVRCLKMUX : MMCME2_ADV
     generic map ( CLKFBOUT_MULT_F      => CLK_MULT_F_G,
                   CLKFBOUT_USE_FINE_PS => true,
                   CLKIN1_PERIOD        => CLKIN_PERIOD_G,
                   CLKIN2_PERIOD        => CLKIN_PERIOD_G,
                   CLKOUT0_DIVIDE_F     => CLK_MULT_F_G )
     port map ( CLKFBOUT   => clkFbO,
                CLKOUT0    => clkOutB,
                LOCKED     => clkLocked,
                CLKFBIN    => clkFbI,
                CLKIN1     => clkIn0,
                CLKIN2     => clkIn1,
                CLKINSEL   => nclkSel,
                DADDR      => (others=>'0'),
                DCLK       => '0',
                DEN        => '0',
                DI         => (others=>'0'),
                DWE        => '0',
                PSCLK      => '0',
                PSEN       => '0',
                PSINCDEC   => '0',
                PWRDWN     => '0',
                RST        => crst );
                   
  U_EVRCLKBUFG : BUFG
   port map (
     O  => clkOut,
     I  => clkOutB );

  U_EVRCLKFBBUFG : BUFG
   port map (
     O  => clkFbI,
     I  => clkFbO );

  seq: process (clkIn0) is
     variable v : slv(10 downto 0) := (others=>'1');
   begin
     crst <= v(0);
     if rising_edge(clkIn0) then
       if (rstIn0='1' or rstIn1='1') then
         v := (others=>'1');
       else
         v := '0' & v(10 downto 1);
       end if;
     end if;
   end process seq;

end rtl;
