-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Trig.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2017-04-23
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
      -- Clock
      evrRecClk  : in  sl;
      -- Trigger Inputs
      trigIn     : in  slv(11 downto 0);
      trigout    : out slv(11 downto 0) );
end EvrCardG2Trig;

architecture mapping of EvrCardG2Trig is

   signal clk190 : sl;
   signal trigMux, trigI, trigO : slv(11 downto 0);
   signal locked : sl;
   signal clkinsel : sl;
   signal delay_wr0 : Slv5Array(11 downto 0);
   signal delay_wr1 : Slv5Array(11 downto 0);

begin

   U_CLK190 : entity work.ClockManager7
     generic map ( INPUT_BUFG_G     => false,
                   NUM_CLOCKS_G     => 1,
                   CLKIN_PERIOD_G   => 8.0,
                   CLKFBOUT_MULT_G  => 38,
                   DIVCLK_DIVIDE_G  => 5,
                   CLKOUT0_DIVIDE_G => 5 )
     port map ( clkIn  => refclk,
                clkOut(0) => clk190 );

   U_IDELAYCTRL : IDELAYCTRL
     port map ( RDY    => open,
                REFCLK => clk190,
                RST    => '0' );

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
                  DATAIN      => trigIn(i),
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

end mapping;
