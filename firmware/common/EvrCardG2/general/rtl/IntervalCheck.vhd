-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : IntervalCheck.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2023-08-17
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Check interval between consecutive markers
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

entity IntervalCheck is
  generic ( INTERVAL_G    : integer := 4;
            COUNT_WIDTH_G : integer := 20 );
  port (
    clk         : in  sl;
    rst         : in  sl;
    mark        : in  sl;
    axilClk     : in  sl;
    axilRst     : in  sl;
    errCnt      : out slv(COUNT_WIDTH_G-1 downto 0) );
end IntervalCheck;

architecture rtl of IntervalCheck is

  constant COUNT_WIDTH_C : integer := bitSize(INTERVAL_G);
  
  type RegType is record
    count  : slv(COUNT_WIDTH_C-1 downto 0);
    err    : sl;
  end record;

  constant REG_INIT_C : RegType := (
    count  => (others=>'0'),
    err    => '0');
  
  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;
  
begin

  comb : process( r, rst, mark ) is
    variable v : RegType;
  begin
    v := r;

    v.err := '0';

    if r.count = INTERVAL_G-1 then
      v.count := (others=>'0');
    else
      v.count := r.count+1;
    end if;
    
    if (mark = '1') then
      if r.count /= INTERVAL_G-1 then
        v.err := '1';
      end if;
      v.count := (others=>'0');
    end if;

    if rst='1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process comb;

  seq : process ( clk ) is
  begin
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process seq;

  S_Mark : entity surf.SynchronizerOneShotCnt
    generic map ( CNT_WIDTH_G => COUNT_WIDTH_G )
    port map ( wrClk   => clk,
               wrRst   => rst,
               dataIn  => r.err,
               rdClk   => axilClk,
               rdRst   => axilRst,
               rollOverEn => '1',
               cntRst  => '0',
               dataOut => open,
               cntOut  => errCnt );
  
end rtl;

    
  
