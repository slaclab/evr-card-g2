-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2Core.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2023-07-11
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
use surf.SsiPkg.all;
--use work.SsiPciePkg.all;

library lcls_timing_core;
use lcls_timing_core.EvrV2Pkg.all;

entity EvrV2Dma is
  generic (
    TPD_G         : time    := 1 ns;
    CHANNELS_C    : integer := 1;
    AXIS_CONFIG_C : AxiStreamConfigType );
  port (
    clk        :  in sl;
    strobe     :  in sl;
    modeSel    :  in sl;
    dmaCntl    :  in AxiStreamCtrlType;
    dmaData    :  in EvrV2DmaDataArray   (CHANNELS_C-1 downto 0);
    dmaMaster  : out AxiStreamMasterType;
    dmaSlave   :  in AxiStreamSlaveType;
    dmaCount   : out slv(23 downto 0);
    dmaDrops   : out slv(23 downto 0));
end EvrV2Dma;

architecture mapping of EvrV2Dma is

  type RegType is record
    idle    : sl;
    paused  : sl;
    dropped  : sl;
    dmaCnt   : slv(23 downto 0);
    dropCnt  : slv(23 downto 0);
    smaster : AxiStreamMasterType;
  end record;

  constant REG_TYPE_INIT_C : RegType := (
    idle    => '1',
    paused  => '0',
    dropped => '0',
    dmaCnt  => (others=>'0'),
    dropCnt => (others=>'0'),
    smaster => AXI_STREAM_MASTER_INIT_C );

  signal r   : RegType := REG_TYPE_INIT_C;
  signal rin : RegType;

begin  -- mapping

  dmaMaster <= r.smaster;
  
  process (r, dmaData, dmaSlave, strobe, modeSel, dmaCntl)
    variable v : RegType;
    variable i : integer;
  begin  -- process
    v := r;
    v.smaster.tValid := '0';
    v.smaster.tLast  := '0';
    v.smaster.tData  := (others=>'0');
    v.smaster.tUser  := (others=>'0');
    for i in 0 to CHANNELS_C-1 loop
      if dmaData(i).tValid='1' then
        if r.paused = '1' then
          v.dropped := '1';
        else
          v.smaster.tValid := dmaData(i).tValid;
          v.smaster.tData(dmaData(i).tData'range) := dmaData(i).tData;
          if r.smaster.tValid = '0' then  -- message header
            if modeSel='0' then
              v.smaster.tData(EVRV2_LCLS_TAG_BIT+16) := '1';
            end if;
          end if;
          if r.idle='1' then -- DMA header, too
            if r.dropped = '1' then
              v.smaster.tData(EVRV2_DROP_TAG_BIT+16) := '1';
              v.dropped := '0';
            end if;
            ssiSetUserSof(AXIS_CONFIG_C, v.smaster, '1');
            v.idle := '0';
          end if;
        end if;
      end if;
    end loop;  -- i

    if strobe='1' then
      if r.idle='0' then
        v.idle           := '1';
        v.smaster.tValid := '1';
        v.smaster.tLast  := '1';
        v.smaster.tData(dmaData(0).tData'range) := EVRV2_END_TAG & x"FFFF";
        v.dmaCnt         := r.dmaCnt+1;
      end if;
      v.paused := dmaCntl.pause;

      if r.dropped = '1' then
        v.dropCnt := r.dropCnt+1;
      end if;
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
