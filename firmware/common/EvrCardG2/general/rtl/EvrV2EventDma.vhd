-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2Core.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2023-09-27
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
use ieee.NUMERIC_STD.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.EvrV2Pkg.all;

entity EvrV2EventDma is
  generic (
    TPD_G      : time    := 1 ns;
    CHANNELS_G : integer := 1 );
  port (
    clk        :  in sl;
    rst        :  in sl;
    strobe     :  in sl;
    eventSel   :  in slv(CHANNELS_G-1 downto 0);
    eventData  :  in TimingMessageType;
    dmaData    : out EvrV2DmaDataType );
end EvrV2EventDma;

architecture mapping of EvrV2EventDma is

  constant WORDS_C : integer := TIMING_MESSAGE_BITS_NO_BSA_C/32;

  type ReadState is (IDLE_S, HDR_S, PAYLOAD_S);
  
  type RegType is record
    channels : slv(15 downto 0);
    state    : ReadState;
    count    : integer range 0 to WORDS_C-1;
    dmaData  : EvrV2DmaDataType;
  end record;

  constant REG_TYPE_INIT_C : RegType := (
    channels => (others=>'0'),
    state    => IDLE_S,
    count    => 0,
    dmaData  => EVRV2_DMA_DATA_INIT_C );

  signal r   : RegType := REG_TYPE_INIT_C;
  signal rin : RegType;

  signal utestData : slv(23 downto 0);
  
begin  -- mapping

  dmaData <= r.dmaData;
  
  process (r, rst, strobe, eventSel, eventData)
    variable v : RegType;
    variable eventSlv : slv(TIMING_MESSAGE_BITS_NO_BSA_C-1 downto 0);
  begin  -- process
    v := r;
    v.dmaData.tValid := '1';
    v.channels(eventSel'range) := r.channels(eventSel'range) or eventSel;

    v.count := r.count+1;

    eventSlv := toSlvNoBsa(eventData);
    
    case r.state is
      when IDLE_S =>
        if strobe='1' and uOr(r.channels)='1' then
          v.state := HDR_S;
          v.dmaData.tData  := EVRV2_EVENT_TAG & r.channels;
          v.channels       := (others=>'0');
        else
          v.dmaData.tValid := '0';
        end if;
      when HDR_S =>
        v.state := PAYLOAD_S;
        v.count := 0;
        v.dmaData.tData := toSlv(WORDS_C,32);
      when PAYLOAD_S =>
        v.dmaData.tData := eventSlv(32*r.count+31 downto 32*r.count);
        if r.count=WORDS_C-1 then
          v.state := IDLE_S;
        end if;
    end case;

    if rst='1' then
      v.channels := (others=>'0');
    end if;

    rin <= v;
  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;
end mapping;
