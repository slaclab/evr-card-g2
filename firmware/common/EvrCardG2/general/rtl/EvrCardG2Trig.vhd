-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Trig.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2016-08-05
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

use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity EvrCardG2Trig is
   generic (
      TPD_G   : time    := 1 ns );
   port (
      refclk     : in  sl;
      delay_ld   : in  slv      (11 downto 0);
      delay_wr   : in  Slv6Array(11 downto 0);
      delay_rd   : out Slv6Array(11 downto 0);
      --
      evrModeSel : in  sl;
      -- Clock
      evrRecClk  : in  slv(1 downto 0);
      -- Trigger Inputs
      trigIn     : in  Slv12Array(1 downto 0);
      trigout    : out slv(11 downto 0);
      -- Status
      sGoodL     : out sl;
      sBadL      : out sl );
end EvrCardG2Trig;

architecture mapping of EvrCardG2Trig is

   signal clk190  : sl;
   signal clk, clkOut0, clkFbO, clkFbI : sl;
   signal trigMux, trigI, trigO : slv(11 downto 0);
   signal crst, crst0, crst1 : sl;
   signal locked : sl;
   signal clkinsel : sl;
   signal delay_wr0 : Slv5Array(11 downto 0);
   signal delay_wr1 : Slv5Array(11 downto 0);

begin

   sGoodL <= not locked;
   clkinsel <= not evrModeSel;
   
   -- Select the trigger path
   -- Note: Legacy software requires inverting LCLS-I trigger
   --       and it's still TBD if we need to do the same for
   --       the LCLS-II trigger as well
   trigMux <= not(trigIn(0)) when(evrModeSel = '0') else trigIn(1);

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
                   CLKIN1_PERIOD        => 8.4,
                   CLKIN2_PERIOD        => 5.6,
                   CLKOUT0_DIVIDE_F     => 6.0 )
     port map ( CLKFBOUT   => clkFbO,
                CLKOUT0    => clkOut0,
                LOCKED     => locked,
                CLKFBIN    => clkFbI,
                CLKIN1     => evrRecClk(0),
                CLKIN2     => evrRecClk(1),
                CLKINSEL   => clkinsel,
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
                   
   U_IDELAYCTRL : IDELAYCTRL
     port map ( RDY    => open,
                REFCLK => clk190,
                RST    => crst );

   OR_TRIG :
   for i in 11 downto 0 generate

     delay_rd (i) <= delay_wr(i);

     delay_wr0(i) <= delay_wr(i)(4 downto 0) when delay_wr(i)(5)='0' else
                     (others=>'1');
     delay_wr1(i) <= delay_wr(i)(4 downto 0) when delay_wr(i)(5)='1' else
                     (others=>'0');
     
     U_IDELAY1 : IDELAYE2
       generic map ( CINVCTRL_SEL => "TRUE",
                     DELAY_SRC    => "DATAIN",
                     IDELAY_TYPE  => "VAR_LOAD" )
       port map ( CNTVALUEOUT => open,
                  DATAOUT     => trigI(i),
                  C           => refclk,  -- control clock
                  CE          => '0',
                  CINVCTRL    => '0',
                  CNTVALUEIN  => delay_wr0(i),
                  INC         => '0',
                  LD          => delay_ld(i), -- load delay
                  LDPIPEEN    => '0',
                  IDATAIN     => '0',
                  DATAIN      => trigMux(i),
                  REGRST      => '0' );

     U_IDELAY2 : IDELAYE2
       generic map ( CINVCTRL_SEL => "TRUE",
                     DELAY_SRC    => "DATAIN",
                     IDELAY_TYPE  => "VAR_LOAD" )
       port map ( CNTVALUEOUT => open,
                  DATAOUT     => trigO(i),
                  C           => refclk,  -- control clock
                  CE          => '0',
                  CINVCTRL    => '0',
                  CNTVALUEIN  => delay_wr1(i),
                  INC         => '0',
                  LD          => delay_ld(i), -- load delay
                  LDPIPEEN    => '0',
                  IDATAIN     => '0',
                  DATAIN      => trigI(i),
                  REGRST      => '0' );

      U_OBUF : OBUF
         port map (
            I => trigO(i),
            O => trigout(i));

   end generate OR_TRIG;

   U_CLK190 : entity work.ClockManager7
     generic map ( INPUT_BUFG_G     => false,
                   NUM_CLOCKS_G     => 1,
                   CLKFBOUT_MULT_G  => 38,
                   DIVCLK_DIVIDE_G  => 5,
                   CLKOUT0_DIVIDE_G => 5 )
     port map ( clkIn  => refclk,
                clkOut(0) => clk190 );

   U_CRST : entity work.SynchronizerEdge
     port map ( clk         => clk190,
                dataIn      => evrModeSel,
                risingEdge  => crst0,
                fallingEdge => crst1 );

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
       
   seq: process (clk190) is
     variable v : slv(10 downto 0) := (others=>'1');
   begin
     crst <= v(0);
     if rising_edge(clk190) then
       if (crst0='1' or crst1='1') then
         v := (others=>'1');
       else
         v := '0' & v(10 downto 1);
       end if;
     end if;
   end process seq;
   
end mapping;
