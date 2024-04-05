-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrSim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2023-06-14
-- Last update: 2023-12-08
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
use ieee.numeric_std.all;
--use ieee.math_real.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

library lcls_timing_core;
use lcls_timing_core.EvrV2Pkg.all;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.TPGPkg.all;
use lcls_timing_core.TPGMiniEDefPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmMiniPkg.all;
use l2si_core.XpmExtensionPkg.all;

library l2si;

entity EvrSim is
end EvrSim;

architecture top_level of EvrSim is

  constant TPD_G : time := 1 ns;
  constant SAXIS_MASTER_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);
  constant NTRIGGERS_C       : natural := TriggerOutputs;
  constant NHARDCHANS_C      : natural := ReadoutChannels;
  constant NCHANNELS_C : integer := ReadoutChannels+2;
  constant MAXCHANNELS_C     : natural := 16;
  constant GEN_L2SI_G : boolean := true;
  
  signal tpgConfig : TpgConfigType := TPG_CONFIG_INIT_C;
  signal evrTxClk, evrTxRst  : slv(1 downto 0);
  signal txData  : Slv16Array(1 downto 0);
  signal txDataK : Slv2Array (1 downto 0);
  signal fiducial0 : sl;
  signal channelConfigS : EvrV2ChannelConfigArray(NCHANNELS_C downto 0) := (others=>EVRV2_CHANNEL_CONFIG_INIT_C);
  signal triggerConfigS   : EvrV2TriggerConfigArray(NCHANNELS_C-1 downto 0) := (others=>EVRV2_TRIGGER_CONFIG_INIT_C);
  signal triggerConfigT   : EvrV2TriggerConfigArray(NCHANNELS_C-1 downto 0);
  
  signal dmaFullThr : slv(9 downto 0);

  signal evrBus              : TimingBusType;
  
  type RegType is record
    strobei     : sl;
    strobe      : slv       (198 downto 0);
    trigStrobe  : sl;
    count       : slv       ( 27 downto 0);
    reset       : sl;
    partDelays  : Slv7Array (  7 downto 0);
    triggerDly  : Slv28Array(NCHANNELS_C-1 downto 0);
    eventSel    : slv       (NCHANNELS_C downto 0);
    dmaSel      : slv       (NCHANNELS_C downto 0);
    eventCount  : Slv20Array(NCHANNELS_C downto 0);
    eventCountL : Slv20Array(NCHANNELS_C downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    strobei     => '0',
    strobe      => (others=>'0'),
    trigStrobe  => '0',
    count       => (others=>'0'),
    reset       => '1',
    partDelays  => (others=>toSlv(1,7)),
    triggerDly  => (others=>(others=>'0')),
    eventSel    => (others=>'0'),
    dmaSel      => (others=>'0'),
    eventCount  => (others=>(others=>'0')),
    eventCountL => (others=>(others=>'0')) );

  signal r    : RegType := REG_INIT_C;
  signal rin  : RegType;

  signal timingMsg      : TimingMessageType := TIMING_MESSAGE_INIT_C;
  signal dmaSel         : slv(NCHANNELS_C downto 0) := (others=>'0');
  signal eventSel       : slv(15 downto 0) := (others=>'0');
  signal eventSel_i     : slv(15 downto 0) := (others=>'0');
  signal eventCountV    : Slv32Array(MAXCHANNELS_C downto 0) := (others=>(others=>'0'));
  
  signal dmaCtrl    : AxiStreamCtrlType := AXI_STREAM_CTRL_UNUSED_C;

  signal dmaMaster : AxiStreamMasterType;
  signal dmaSlave  : AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C;
  signal dmaDrops   : slv(23 downto 0);
  signal dmaCount   : slv(23 downto 0);

  signal partitionAddr  : slv(31 downto 0) := (others=>'0');
  signal modeSel        : sl := '1';
  signal delay_wrb      : Slv6Array(11 downto 0) := (others=>(others=>'0'));
  signal delay_ldb      : slv      (11 downto 0) := (others=>'1');

  signal triggerStrobe  : sl;

  signal xpmMessage : XpmMessageType;
  signal rxData     : TimingRxType;
  signal evrClkSel  : sl := '1';
  signal dsTx       : TimingPhyType := TIMING_PHY_INIT_C;
  signal xpmStream  : XpmStreamType := XPM_STREAM_INIT_C;
  signal xpmConfig  : XpmMiniConfigType := XPM_MINI_CONFIG_INIT_C;

  signal tpgStream   : TimingSerialType;
  signal tpgAdvance  : sl;
  signal tpgFiducial : sl;

  signal evrClk, evrRst : sl;
  signal regClk, regRst : sl;
  
  signal dbTrig     : slv(11 downto 0);
  signal dbTrigOut  : slv(11 downto 0);

begin

   tpgConfig.FixedRateDivisors  <= (x"00000",
                                    x"00000",
                                    x"00000",
                                    x"00001",                                   -- 929 kHz
                                    x"0000D",                                    -- 71.4kHz
                                    x"0005B",                                    -- 10.2kHz
                                    x"0038E",                                    -- 1.02kHz 
                                    x"0238C",                                    -- 102 Hz
                                    x"16378",                                    -- 10.2Hz
                                    x"DE2B0");                                    -- 1.02H
   tpgConfig.pulseIdWrEn <= '0';
   
   xpmConfig.dsLink(0).enable <= '0';
   xpmConfig.partition.l0Select.enabled <= '1';
   xpmConfig.partition.l0Select.rateSel <= toSlv(5,16);
   xpmConfig.partition.pipeline.depth_fids <= toSlv(8,8);
   xpmConfig.partition.pipeline.depth_clks <= toSlv(8*200,16);

   channelConfigS(0).enabled <= '1';
   channelConfigS(0).rateSel <= toSlv(5,13);  -- 71kH
   channelConfigS(0).destSel <= resize(x"20000",19);
   channelConfigS(0).dmaEnabled <= '1';
     
   channelConfigS(1).enabled <= '1';
   channelConfigS(1).rateSel <= "11" & toSlv(0,11); -- group 0
   channelConfigS(1).destSel <= resize(x"20000",19);
   channelConfigS(1).dmaEnabled <= '1';

   process is
   begin
     triggerConfigS(0).enabled <= '1';
     triggerConfigS(0).delay <= toSlv(40000,28);
     triggerConfigS(0).width <= toSlv(100,28);
     triggerConfigS(0).channel  <= toSlv(0,4);
     triggerConfigS(0).channels <= toSlv(1,16);

     triggerConfigS(1).enabled <= '1';
     triggerConfigS(1).delay <= toSlv(40000,28);
     triggerConfigS(1).width <= toSlv(100,28);
     triggerConfigS(1).channel  <= toSlv(1,4);
     triggerConfigS(1).channels <= toSlv(2,16);

     wait for 100 us;
     triggerConfigS(1).delay <= toSlv(4000,28);

     wait;
   end process;
       
   triggerStrobe <= r.trigStrobe;
   
   process is
   begin
     regClk <= '1';
     wait for 4.0 ns;
     regClk <= '0';
     wait for 4.0 ns;
   end process;
   
   process is
   begin
     evrTxClk(0) <= '1';
     wait for 4.2 ns;
     evrTxClk(0) <= '0';
     wait for 4.2 ns;
   end process;

   process is
   begin
     evrTxClk(1) <= '1';
     wait for 2.7 ns;
     evrTxClk(1) <= '0';
     wait for 2.7 ns;
   end process;

   process is
   begin
     evrTxRst <= "11";
     regRst   <= '1';
     wait for 20 ns;
     evrTxRst <= "00";
     regRst   <= '0';
     wait;
   end process;

   evrClk <= evrTxClk(1);
   evrRst <= evrTxRst(1);
   
   U_EVG : entity lcls_timing_core.TPGMiniStream
     port map (
       config     => TPG_CONFIG_INIT_C,
       edefConfig => TPG_MINI_EDEF_CONFIG_INIT_C,
       txClk      => evrTxClk(0),
       txRst      => evrTxRst(0),
       txRdy      => '1',
       txData     => txData(0),
       txDataK    => txDataK(0),
       simStrobe  => fiducial0 );

   U_TPG : entity lcls_timing_core.TPGMini
     generic map ( STREAM_INTF => true )
     port map (
       statusO    => open,
       configI    => tpgConfig,
       txClk      => evrTxClk(1),
       txRst      => evrTxRst(1),
       txRdy      => '1',
       streams(0) => tpgStream,
       advance(0) => tpgAdvance,
       fiducial   => tpgFiducial );

   xpmStream.fiducial   <= tpgFiducial;
   xpmStream.advance(0) <= tpgAdvance;
   xpmStream.streams(0) <= tpgStream;

   tpgAdvance <= tpgStream.ready and not tpgFiducial;

   U_Xpm : entity l2si_core.XpmMini
     port map (
       regclk          => regClk,
       regrst          => regRst,
       update          => '1',
       status          => open,
       config          => xpmConfig,
       -- DS Ports
       dsRxClk(0)      => evrTxClk(1),
       dsRxRst(0)      => evrTxRst(1),
       dsRx(0)         => TIMING_RX_INIT_C,
       dsTx(0)         => dsTx,
       -- Timing Interface (timingClk domain) 
       timingClk       => evrTxClk(1),
       timingRst       => evrTxRst(1),
       timingStream    => xpmStream );

   U_Timing : entity lcls_timing_core.TimingCore
     generic map (
         DEFAULT_CLK_SEL_G => '1',
         TPGEN_G           => false,
         AXIL_RINGB_G      => false,
         ASYNC_G           => true )
      port map (
         gtTxUsrClk       => evrTxClk(1),
         gtTxUsrRst       => evrTxRst(1),
         gtRxRecClk       => evrClk,
         gtRxData         => dsTx.data,
         gtRxDataK        => dsTx.dataK,
         gtRxDispErr      => "00",
         gtRxDecErr       => "00",
         gtRxControl      => open,
         gtRxStatus       => TIMING_PHY_STATUS_FORCE_C,
         tpgMiniTimingPhy => open,
         timingClkSel     => open,
         -- Decoded timing message interface
         appTimingClk     => evrClk,
         appTimingRst     => evrRst,
         appTimingMode    => open,
         appTimingBus     => evrBus,
         -- AXI Lite interface
         axilClk          => regClk,
         axilRst          => regRst,
         axilReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave    => open,
         axilWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave   => open );
       
  xpmMessage <= toXpmMessageType(evrBus.extension(XPM_STREAM_ID_C));

   U_Record : entity l2si.AxiStreamRecord
     port map ( axisClk    => evrClk,
                axisMaster => dmaMaster,
                axisSlave  => dmaSlave );
   
  -- U_Dma : entity work.EvrV2DmaModule
  --   generic map ( CHANNELS_G    => ReadoutChannels+3,
  --                 AXIS_CONFIG_G => SAXIS_MASTER_CONFIG_C )
  --   port map (    clk        => evrClk,
  --                 rst        => evrRst,
  --                 timingMsg  => evrBus.message,
  --                 xpmMsg     => xpmMessage,
  --                 strobe     => r.strobe(2),
  --                 config     => channelConfigS,
  --                 dmaSel     => dmaSel,
  --                 modeSel    => modeSel,
  --                 dmaCtrl    => dmaCtrl,
  --                 dmaMaster  => dmaMaster,
  --                 dmaSlave   => dmaSlave,
  --                 dmaCount   => dmaCount,
  --                 dmaDrops   => dmaDrops);
    
  Loop_EventSel: for i in 0 to NCHANNELS_C-1 generate
    U_EventSel : entity lcls_timing_core.EvrV2EventSelect
      generic map ( TPD_G         => TPD_G )
      port map    ( clk           => evrClk,
                    rst           => evrRst,
                    config        => channelConfigS(i),
                    strobeIn      => r.strobe(0),
                    dataIn        => timingMsg,
                    selectOut     => eventSel_i(i),
                    dmaOut        => open );
    eventSel    (i) <= r.eventSel(i);
    dmaSel      (i) <= r.dmaSel  (i);
  end generate;  -- i

  U_V2FromV1 : entity lcls_timing_core.EvrV2FromV1
    port map ( clk       => evrClk,
               disable   => modeSel,
               timingIn  => evrBus,
               timingOut => timingMsg );

  trig_t : process (triggerConfigS, r) is
  begin
    triggerConfigT <= triggerConfigS;
    if GEN_L2SI_G then
      for i in 0 to NTRIGGERS_C-1 loop
        triggerConfigT(i).delay <= r.triggerDly(i);
      end loop;
    end if;
  end process;

  Out_Trigger: for i in 0 to NTRIGGERS_C-1 generate
     U_Trig : entity lcls_timing_core.EvrV2Trigger
        generic map ( TPD_G        => TPD_G,
                      CHANNELS_C   => NHARDCHANS_C,
                      TRIG_DEPTH_C => 256,
                      USE_MASK_G   => false )
        port map (    clk      => evrClk,
                      rst      => evrRst,
                      config   => triggerConfigT(i),
                      arm      => eventSel(NHARDCHANS_C-1 downto 0),
                      fire     => triggerStrobe,
                      trigstate=> dbTrig(i) );
  end generate Out_Trigger;

  Compl_Trigger: for i in 0 to NTRIGGERS_C/2-1 generate
    U_Trig : entity lcls_timing_core.EvrV2TriggerCompl
      generic map ( REG_OUT_G => true )
      port map ( clk     => evrClk,
                 rst     => evrRst,
                 config  => triggerConfigT(2*i+1 downto 2*i),
                 trigIn  => dbTrig   (2*i+1 downto 2*i),
                 trigOut => dbTrigOut(2*i+1 downto 2*i) );
  end generate;
   
   comb : process ( r, evrBus, eventSel_i, evrClkSel, channelConfigS, xpmMessage, modeSel ) is
     variable v : RegType;
     variable j : integer;
    variable xpmEvent : XpmEventDataType;
    variable broadcastMessage : XpmBroadcastType;
  begin
    v := r;

    v.reset  := '0';
    v.count  := r.count+1;
    v.strobei := evrBus.strobe;
    v.strobe := r.strobe(r.strobe'left-1 downto 0) & r.strobei;

    --  Need this to compensate trigger delays
    if evrBus.strobe = '1' then
      -- Update partitionDelays values when partitionAddr indicates new PDELAYs
      broadcastMessage := toXpmBroadcastType(xpmMessage.partitionAddr);
      if (broadcastMessage.btype = XPM_BROADCAST_PDELAY_C) then
        v.partDelays(broadcastMessage.index) := broadcastMessage.value;
      end if;
    end if;
    
    if modeSel='0' then
      v.trigStrobe := v.strobe(r.strobe'left);
    else
      v.trigStrobe := v.strobei;
    end if;
    
    for i in 0 to NCHANNELS_C-1 loop
      v.eventSel(i) := eventSel_i(i);
      if r.strobe(1) = '1' then      --  Add in DAQ event selection
        if channelConfigS(i).rateSel(12 downto 11)="11" then
          j := conv_integer(channelConfigS(i).rateSel(2 downto 0));
          xpmEvent := toXpmEventDataType(xpmMessage.partitionWord(j));
          v.eventSel(i) := xpmEvent.valid and xpmEvent.l0Accept;
          v.triggerDly(i) := triggerConfigS(i).delay - toSlv(200*conv_integer(r.partDelays(j)),28);
        else
          v.triggerDly(i) := triggerConfigS(i).delay;
        end if;
      end if;
      v.dmaSel(i) := v.eventSel(i) and channelConfigS(i).dmaEnabled;
      if r.eventSel(i) = '1' then
        v.eventCount(i) := r.eventCount(i)+1;
      end if;
    end loop;
    if v.strobei = '1' then
      v.eventCount(NCHANNELS_C) := r.eventCount(NCHANNELS_C)+1;
    end if;
    
    if ((evrClkSel = '0' and r.count = toSlv(118999998,28)) or
        (evrClkSel = '1' and r.count = toSlv(181999998,28))) then
      v.reset := '1';
    end if;

    if r.reset = '1' then
      v.count       := (others=>'0');
      v.eventCount  := (others=>(others=>'0'));
      v.eventCountL := r.eventCount;
    end if;
    
    rin <= v;
  end process comb;
    
  seq : process (evrClk)
  begin
    if rising_edge(evrClk) then
      r <= rin;
    end if;
  end process seq;

     U_Trig : entity work.EvrLockTrig
       port map (
         timingClk(0) => '0',
         timingClk(1) => evrClk,
         timingRst(0) => '0',
         timingRst(1) => evrRst,
         timingBus(0) => TIMING_BUS_INIT_C,
         timingBus(1) => evrBus,
         ncDelay      => (others=>'0'),
         trigOut      => open );
     
end top_level;
