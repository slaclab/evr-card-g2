-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrLockTrig.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2023-06-14
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

entity EvrLockTrig is
   port (
      timingClk       : in  slv(1 downto 0);
      timingRst       : in  slv(1 downto 0);
      timingBus       : in  TimingBusArray(1 downto 0);
      ncDelay         : in  slv(19 downto 0);
      trigOut         : out slv(11 downto 0) );
end EvrLockTrig;

architecture mapping of EvrLockTrig is

  type NCRegType is record
    count          : slv(ncDelay'range);
    trigLatch      : slv(2 downto 0);
    trigOut        : slv(2 downto 0);
  end record;

  constant NCREG_INIT_C : NCRegType := (
    count          => (others=>'0'),
    trigLatch      => (others=>'0'),
    trigOut        => (others=>'0') );

  signal nc   : NCRegType := NCREG_INIT_C;
  signal ncin : NCRegType;

  type SCRegType is record
    trigOut        : slv(3 downto 0);
  end record;

  constant SCREG_INIT_C : SCRegType := (
    trigOut        => (others=>'0') );

  signal sc   : SCRegType := SCREG_INIT_C;
  signal scin : SCRegType;

begin

  trigOut <= toSlv(0,5) & nc.trigOut & sc.trigOut;
  

  nccomb : process( nc, timingRst, timingBus, ncDelay ) is
    variable v   : NCRegType;
  begin
    v := nc;

    v.trigOut := (others=>'0');

    if nc.count = ncDelay then
      v.trigOut   := nc.trigLatch;
      v.trigLatch := (others=>'0');
    else
      v.count     := nc.count+1;
    end if;
    
    if timingBus(0).strobe = '1' then
      v.count     := (others=>'0');
      if (timingBus(0).stream.eventCodes(1) = '1') then
        v.trigLatch(0) := '1';
      end if;
      if (timingBus(0).stream.eventCodes(11) = '1') then
        v.trigLatch(1) := '1';
      end if;
      if (timingBus(0).stream.eventCodes(15) = '1') then
        v.trigLatch(2) := '1';
      end if;
    end if;

    if timingRst(0) = '1' then
      v := NCREG_INIT_C;
    end if;

    ncin <= v;
  end process nccomb;

  ncseq: process( timingClk )
  begin
    if rising_edge(timingClk(0)) then
      nc <= ncin;
    end if;
  end process ncseq;

  sccomb : process( sc, timingRst, timingBus ) is
    variable v   : SCRegType;
  begin
    v := sc;

    v.trigOut := (others=>'0');
    
    if timingBus(1).strobe = '1' then
      if timingBus(1).message.acRates(0) = '1' then
        v.trigOut(0) := '1';
        if timingBus(1).message.acTimeSlot = "001" then
          v.trigOut(1) := '1';
        end if;
      end if;
      if (timingBus(1).message.acRates(5) = '1' and
          timingBus(1).message.acTimeSlot = "001") then
        v.trigOut(2) := '1';
      end if;
      if timingBus(1).message.fixedRates(5) = '1' then
        v.trigOut(3) := '1';
      end if;
    end if;
      
    if timingRst(1) = '1' then
      v := SCREG_INIT_C;
    end if;

    scin <= v;
  end process sccomb;

  scseq: process( timingClk )
  begin
    if rising_edge(timingClk(1)) then
      sc <= scin;
    end if;
  end process scseq;

end mapping;
