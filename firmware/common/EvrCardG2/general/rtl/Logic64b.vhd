-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Logic64b.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-05-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use work.DspLogicPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity Logic64b is
  generic ( AREG : natural := 0;
            BREG : natural := 0 );
  port ( clk   : in  sl;
         A     : in  slv(63 downto 0) := (others=>'0');
         B     : in  slv(63 downto 0) := (others=>'0');
         PCin  : in  slv(63 downto 0) := (others=>'0');
         op    : in  DspLogicOpType;
         PCout : out slv(63 downto 0);
         P     : out slv(63 downto 0);
         Pnz   : out sl );
end Logic64b;

architecture rtl of Logic64b is

  signal PoutU, PoutL : slv(47 downto 0);
  signal PzL, PzU : sl;
  
begin

  P   <= PoutU(31 downto 0) & PoutL(31 downto 0);
  Pnz <= not (PzL and PzU);
  
  U_LowerHalf : entity work.DspLogic
    generic map ( AREG => AREG,
                  BREG => BREG )
    port map ( clk        => clk,
               op         => op,
               A(47 downto 32) => (others=>'0'),
               A(31 downto  0) => A(31 downto 0),
               B(47 downto 32) => (others=>'0'),
               B(31 downto  0) => B(31 downto 0),
               P               => PoutL,
               Pzero           => PzL );
  
  U_UpperHalf : entity work.DspLogic
    generic map ( AREG => AREG,
                  BREG => BREG )
    port map ( clk        => clk,
               op         => op,
               A(47 downto 32) => (others=>'0'),
               A(31 downto  0) => A(63 downto 32),
               B(47 downto 32) => (others=>'0'),
               B(31 downto  0) => B(63 downto 32),
               P               => PoutU,
               Pzero           => PzU );

end rtl;
