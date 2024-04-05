-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ResyncClock.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2023-06-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Interface to sensor link MGT
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 XPM Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 XPM Core', including this file, 
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


entity ResyncClock is
  generic ( DIVISOR_G : integer := 4 );
  port (
    refClk         : in  sl;
    refClkRst      : in  sl;
    resync         : in  sl;
    valid          : out sl;
    sync           : out sl;
    clkOut         : out sl;
    clkO90         : out sl );
end ResyncClock;

architecture rtl of ResyncClock is

  constant COUNT_WIDTH_C : integer := bitSize(DIVISOR_G-1);
  constant UP_CNT : slv(COUNT_WIDTH_C-1 downto 0) := toSlv(DIVISOR_G  -1,COUNT_WIDTH_C);
  constant DN_CNT : slv(COUNT_WIDTH_C-1 downto 0) := toSlv(DIVISOR_G/2-1,COUNT_WIDTH_C);
  constant D90_CNT : slv(COUNT_WIDTH_C-1 downto 0) := toSlv(DIVISOR_G/4-1,COUNT_WIDTH_C);
  constant U90_CNT : slv(COUNT_WIDTH_C-1 downto 0) := toSlv(DIVISOR_G/2,COUNT_WIDTH_C)+D90_CNT;

  type RegType is record
    count  : slv(COUNT_WIDTH_C-1 downto 0);
    syncd  : sl;
    synco  : sl;
    divClk : sl;
    d90Clk : sl;
  end record;

  constant REG_INIT_C : RegType := (
    count  => (others=>'0'),
    syncd  => '0',
    synco  => '0',
    divClk => '1',
    d90Clk => '1' );
  
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
begin

  comb : process ( r, refClkRst, resync ) is
    variable v : RegType;
  begin
    v := r;

    v.synco := '0';
    
    if resync = '1' then
      v.syncd := '1';
    end if;
    
    v.count := r.count+1;
    if r.count = UP_CNT or resync = '1' then
      v.divClk := '1';
      v.count  := (others=>'0');
    elsif r.count = DN_CNT and r.syncd = '1' then
      v.divClk := '0';
    end if;

    if r.count = U90_CNT then
      v.d90Clk := '1';
    elsif r.count = D90_CNT then
      v.d90Clk := '0';
    end if;
    
    if refClkRst = '1' then
      v := REG_INIT_C;
      v.syncd := resync;  -- allow reset to be used as resync
    end if;

    if r.count = UP_CNT-1 then
      v.synco := '1';
    end if;
    
    rin <= v;

    valid  <= r.syncd;
    sync   <= r.synco;
    clkOut <= r.divClk;
    clkO90 <= r.d90Clk;
  end process;

  seq : process (refClk) is
  begin
    if rising_edge(refClk) then
      r <= rin;
    end if;
  end process;
  
end rtl;
