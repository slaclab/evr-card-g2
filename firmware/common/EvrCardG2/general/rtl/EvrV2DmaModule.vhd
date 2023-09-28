-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2DmaModule.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2023-09-28
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

library lcls_timing_core;
use lcls_timing_core.EvrV2Pkg.all;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.XpmExtensionPkg.all;

entity EvrV2DmaModule is
  generic (
    TPD_G         : time    := 1 ns;
    CHANNELS_G    : integer := 1;
    AXIS_CONFIG_G : AxiStreamConfigType );
  port (
    clk        :  in sl;
    rst        :  in sl;
    config     :  in EvrV2ChannelConfigArray(CHANNELS_G-1 downto 0);
    timingMsg  :  in TimingMessageType;
    xpmMsg     :  in XpmMessageType;
    strobe     :  in sl;
    modeSel    :  in sl;
    dmaSel     :  in slv(CHANNELS_G-1 downto 0);
    dmaCtrl    :  in AxiStreamCtrlType;
    dmaMaster  : out AxiStreamMasterType;
    dmaSlave   :  in AxiStreamSlaveType;
    dmaCount   : out slv(23 downto 0);
    dmaDrops   : out slv(23 downto 0));
end EvrV2DmaModule;

architecture mapping of EvrV2DmaModule is

  constant NHARDCHANS_C      : natural := ReadoutChannels;
  constant BSA_CHDSP_IDX_C   : natural := 0;
  constant BSA_CTRL_IDX_C    : natural := NHARDCHANS_C;
  constant EVENT_IDX_C       : natural := NHARDCHANS_C+1;
  constant BSA_CHSUM_IDX_C   : natural := NHARDCHANS_C+2;
  constant NCHANNELS_C       : natural := CHANNELS_G;
  constant STROBE_INTERVAL_C : integer := 12;

  signal dmaEnabled    : slv(NCHANNELS_C-1 downto 0);
  signal anyDmaEnabled : sl;
  signal summarySel    : slv(15 downto 0) := (others=>'0');
  signal dmaData       : EvrV2DmaDataArray(NCHANNELS_C downto 0) := (others=>EVRV2_DMA_DATA_INIT_C);
  
  constant DEBUG_C : boolean := false;

  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  signal dbDmaValid : slv(11 downto 0);

  signal strobe_o       : sl;
  signal timingMsg_o    : TimingMessageType := TIMING_MESSAGE_INIT_C;
  signal dmaSel_o       : slv(NCHANNELS_C-1 downto 0) := (others=>'0');

  type RegType is record
    strobe    : slv(198 downto 0);
  end record;

  constant REG_TYPE_INIT_C : RegType := (
    strobe    => (others=>'0') );

  signal r   : RegType := REG_TYPE_INIT_C;
  signal rin : RegType;

begin  -- mapping

  --  Each BSA Channel occupies 11 clocks
  --  BSA Control occupies 10 clocks
  --  EventDMA occupies 22 clocks
--  assert (rStrobe'length <= 200)
  assert (NHARDCHANS_C*STROBE_INTERVAL_C+34 < 200)
    report "rStrobe'length exceeds clocks per cycle"
    severity failure;

  GEN_Channel: for i in 0 to NCHANNELS_C-1 generate
    dmaEnabled(i) <= config(i).dmaEnabled;
    summarySel(i) <= dmaSel_o(i) and not config(i).bsaEnabled;
  end generate GEN_Channel;

  anyDmaEnabled <= uOr(dmaEnabled);

  U_Dma : entity work.EvrV2Dma
    generic map ( CHANNELS_G    => NHARDCHANS_C+3,
                  AXIS_CONFIG_G => AXIS_CONFIG_G )
    port map (    clk        => clk,
                  strobe     => r.strobe(r.strobe'left),
                  modeSel    => modeSel,
                  dmaCntl    => dmaCtrl,
                  dmaData    => dmaData,
                  dmaMaster  => dmaMaster,
                  dmaSlave   => dmaSlave,
                  dmaCount   => dmaCount,
                  dmaDrops   => dmaDrops);
  
  U_BsaControl : entity work.EvrV2BsaControl
    generic map ( TPD_G      => TPD_G )
    port map (    evrClk     => clk,
                  evrRst     => rst,
                  enable     => anyDmaEnabled,
                  strobeIn   => r.strobe(0),
                  dataIn     => timingMsg_o,
                  dmaData    => dmaData        (BSA_CTRL_IDX_C) );

  --  No longer needed?
  Loop_BsaCh: for i in 0 to NHARDCHANS_C-1 generate
    U_BsaChannel : entity work.EvrV2BsaChannelDSP
      generic map ( TPD_G         => TPD_G,
                    CHAN_G        => i,
                    DEBUG_G       => false )
      port map    ( evrClk        => clk,
                    evrRst        => rst,
                    channelConfig => config(i),
                    evtSelect     => dmaSel_o(i),
                    strobeIn      => r.strobe(i*STROBE_INTERVAL_C+8),
                    dataIn        => timingMsg_o,
                    dmaData       => dmaData(BSA_CHDSP_IDX_C+i) );
  end generate;  -- i

  U_BsaSummary : entity work.EvrV2BsaChannelSummary
    generic map ( TPD_G         => TPD_G )
    port map    ( evrClk        => clk,
                  evrRst        => rst,
                  enable        => '1',
                  evtSelect     => summarySel,
                  strobeIn      => r.strobe(NHARDCHANS_C*STROBE_INTERVAL_C+15),
                  dataIn        => timingMsg_o,
                  dmaData       => dmaData(BSA_CHSUM_IDX_C) );
  
  U_EventDma : entity work.EvrV2EventDma
    generic map ( TPD_G      => TPD_G,
                  CHANNELS_G => dmaSel'length )
    port map (    clk        => clk,
                  rst        => strobe_o,
                  strobe     => r.strobe(NHARDCHANS_C*STROBE_INTERVAL_C+30),
                  eventSel   => dmaSel_o,
                  eventData  => timingMsg_o,
                  dmaData    => dmaData   (EVENT_IDX_C) );

  U_Align : entity work.XpmMessageAligner
    generic map ( TF_DELAY_G => 100,
                  CHANNELS_G => NCHANNELS_C )
    port map (    clk        => clk,
                  rst        => rst,
                  xpm_msg    => xpmMsg,
                  config     => config,
                  strobe_in  => strobe,
                  strobe_out => strobe_o,
                  timing_in  => timingMsg,
                  timing_out => timingMsg_o,
                  sel_in     => dmaSel,
                  sel_out    => dmaSel_o );

  comb : process ( r, strobe_o ) is
    variable v : RegType;
  begin
    v := r;

    v.strobe := r.strobe(r.strobe'left-1 downto 0) & strobe_o;

    rin <= v;
    
  end process comb;

  seq : process ( clk ) is
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process;
  
end mapping;
