-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2Core.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-05-05
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPciePkg.all;
use work.TimingPkg.all;
use work.EvrV2Pkg.all;
--use work.PciPkg.all;
use work.SsiPkg.all;

entity EvrV2Core is
  generic (
    TPD_G         : time             := 1 ns;
    AXIL_BASEADDR : slv(31 downto 0) := x"00080000" );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    irqActive           : in  sl;
    irqEnable           : out sl;
    irqReq              : out sl;
    -- DMA
    dmaRxIbMaster       : out AxiStreamMasterType;
    dmaRxIbSlave        : in  AxiStreamSlaveType;
    dmaRxTranFromPci    : in  TranFromPcieType;
    dmaReady            : out sl;
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    evrBus              : in  TimingBusType;
    exptBus             : in  ExptBusType;
    gtxDebug            : in  slv(7 downto 0);
    -- Trigger and Sync Port
    syncL               : in  sl;
    trigOut             : out slv(11 downto 0);
    evrModeSel          : in  sl;
    delay_ld            : out slv      (11 downto 0);
    delay_wr            : out Slv6Array(11 downto 0);
    delay_rd            : in  Slv6Array(11 downto 0) );
end EvrV2Core;

architecture mapping of EvrV2Core is

  constant NUM_AXI_MASTERS_C : natural := 3;
  constant CSR_INDEX_C       : natural := 0;
  constant TRG_INDEX_C       : natural := 1;
  constant DMA_INDEX_C       : natural := 2;

  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    CSR_INDEX_C      => (
      baseAddr      => x"00000000" + AXIL_BASEADDR,
      addrBits      => 9,
      connectivity  => X"0001"),
    TRG_INDEX_C => (
      baseAddr      => x"00000200" + AXIL_BASEADDR,
      addrBits      => 9,
      connectivity  => X"0001"),
    DMA_INDEX_C => (
      baseAddr      => x"00000400" + AXIL_BASEADDR,
      addrBits      => 10,
      connectivity  => X"0001") );
  
  signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);
  
  constant STROBE_INTERVAL_C : integer := 12;
  
  signal bsaControl       : EvrV2BsaControlType;
  signal bsaChannel       : EvrV2BsaChannelArray   (ReadoutChannels-1 downto 0);
  signal channelConfig    : EvrV2ChannelConfigArray(ReadoutChannels-1 downto 0);
  signal channelConfigS   : EvrV2ChannelConfigArray(ReadoutChannels-1 downto 0) := (others=>EVRV2_CHANNEL_CONFIG_INIT_C);
  signal triggerConfig    : EvrV2TriggerConfigArray(TriggerOutputs-1 downto 0);
  signal triggerConfigS   : EvrV2TriggerConfigArray(TriggerOutputs-1 downto 0) := (others=>EVRV2_TRIGGER_CONFIG_INIT_C);
  
  signal gtxDebugS   : slv(7 downto 0);

  signal rStrobe        : slv(198 downto 0) := (others=>'0');
  
  signal timingMsg      : TimingMessageType := TIMING_MESSAGE_INIT_C;
  signal dmaSel         : slv(ReadoutChannels-1 downto 0) := (others=>'0');
  signal eventSel       : slv(ReadoutChannels-1 downto 0) := (others=>'0');
  signal eventCount     : SlVectorArray(ReadoutChannels downto 0,31 downto 0);
  signal rstCount : sl;
  
  signal dmaCtrl    : AxiStreamCtrlType;
  signal dmaData    : EvrV2DmaDataArray(ReadoutChannels+1 downto 0);

  constant SAXIS_MASTER_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);
  
  signal dmaMaster : AxiStreamMasterType;
  signal dmaSlave  : AxiStreamSlaveType;

  signal pciClk : sl;
  signal pciRst : sl;

  signal rxDescToPci   : DescToPcieType;
  signal rxDescFromPci : DescFromPcieType;

  signal bsaEnabled : slv(ReadoutChannels-1 downto 0);
  signal anyBsaEnabled : sl;
  
  signal irqRequest : sl;

  signal dmaFullThr     : Slv24Array (0 downto 0);
  signal dmaFullThrS    : Slv24Array (0 downto 0);

  signal partitionAddr  : slv(31 downto 0);
  signal modeSel        : sl;
  signal delay_wrb      : Slv6Array(11 downto 0) := (others=>(others=>'0'));
  signal delay_ldb      : slv      (11 downto 0) := (others=>'1');

  signal triggerStrobe  : sl;

  constant DEBUG_C : boolean := false;

  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  signal dbDmaValid : slv(11 downto 0);
  signal dbTrigOut : slv(11 downto 0);
  signal dbDmaRxIbMaster : AxiStreamMasterType;
  
begin  -- rtl

  dmaRxIbMaster <= dbDmaRxIbMaster;
  
  GEN_DBUG : if DEBUG_C generate
    GEN_DMAV : for i in 0 to 11 generate
      dbDmaValid(i) <= dmaData(i).tValid;
    end generate;
    
    U_ILA : ila_0
      port map ( clk    => evrClk,
                 probe0(11 downto 0) => dbDmaValid,
                 probe0(12) => dmaMaster.tValid,
                 probe0(13) => dmaMaster.tLast,
                 probe0(45 downto 14) => dmaMaster.tData(31 downto 0),
                 probe0(46) => dmaSlave.tReady,
                 probe0(56 downto 47) => eventSel,
                 probe0(66 downto 57) => dmaSel,
                 probe0(67)           => triggerStrobe,
                 probe0(79 downto 68) => dbTrigOut,
                 probe0(83 downto 80) => dmaMaster.tUser(3 downto 0),
                 probe0(255 downto 84) => (others=>'0') );
    U_ILAD : ila_0
      port map ( clk    => pciClk,
                 probe0(0) => dbDmaRxIbMaster.tValid,
                 probe0(1) => dbDmaRxIbMaster.tLast,
                 probe0(5 downto 2) => dbDmaRxIbMaster.tUser( 3 downto 0),
                 probe0(133 downto 6) => dbDmaRxIbMaster.tData(127 downto 0),
                 probe0(255 downto 134) => (others=>'0') );
  end generate;
                 
--  assert (rStrobe'length <= 200)
  assert (ReadoutChannels*STROBE_INTERVAL_C+34 < 200)
    report "rStrobe'length exceeds clocks per cycle"
    severity failure;
  
  pciClk <= axiClk;
  pciRst <= axiRst;
  irqReq <= irqRequest;

  modeSel    <= evrModeSel;
  delay_ld   <= delay_ldb;
  delay_wr   <= delay_wrb;

  dmaReady <= not dmaCtrl.pause;
  trigOut <= dbTrigOut;

  -------------------------
  -- AXI-Lite Crossbar Core
  -------------------------  
  AxiLiteCrossbar_Inst : entity work.AxiLiteCrossbar
    generic map (
      TPD_G              => TPD_G,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
    port map (
      axiClk              => axiClk,
      axiClkRst           => axiRst,
      sAxiWriteMasters(0) => axilWriteMaster,
      sAxiWriteSlaves (0) => axilWriteSlave,
      sAxiReadMasters (0) => axilReadMaster,
      sAxiReadSlaves  (0) => axilReadSlave,
      mAxiWriteMasters    => mAxiWriteMasters,
      mAxiWriteSlaves     => mAxiWriteSlaves,
      mAxiReadMasters     => mAxiReadMasters,
      mAxiReadSlaves      => mAxiReadSlaves);   
  
  U_PciRxDesc : entity work.EvrV2PcieRxDesc
    generic map ( DMA_SIZE_G       => 1 )
    port map (    dmaDescToPci  (0)=> rxDescToPci,
                  dmaDescFromPci(0)=> rxDescFromPci,
                  axiReadMaster    => mAxiReadMasters (DMA_INDEX_C),
                  axiReadSlave     => mAxiReadSlaves  (DMA_INDEX_C),
                  axiWriteMaster   => mAxiWriteMasters(DMA_INDEX_C),
                  axiWriteSlave    => mAxiWriteSlaves (DMA_INDEX_C),
                  irqReq           => irqRequest,
                  cntRst           => '0',
                  pciClk           => pciClk,
                  pciRst           => pciRst );

  U_PciRxDma : entity work.EvrV2PcieRxDma
    generic map ( TPD_G                 => TPD_G,
                  SAXIS_MASTER_CONFIG_G => SAXIS_MASTER_CONFIG_C,
                  FIFO_ADDR_WIDTH_G     => 10 )
    port map (    sAxisClk       => evrClk,
                  sAxisRst       => evrRst,
                  sAxisMaster    => dmaMaster,
                  sAxisSlave     => dmaSlave,
                  sAxisCtrl      => dmaCtrl,
                  sAxisPauseThr  => dmaFullThrS(0)(9 downto 0),
                  pciClk         => pciClk,
                  pciRst         => pciRst,
                  dmaIbMaster    => dbDmaRxIbMaster,
                  dmaIbSlave     => dmaRxIbSlave,
                  dmaDescFromPci => rxDescFromPci,
                  dmaDescToPci   => rxDescToPci,
                  dmaTranFromPci => dmaRxTranFromPci,
                  dmaChannel     => x"0" );

  U_Dma : entity work.EvrV2Dma
    generic map ( CHANNELS_C    => ReadoutChannels+2,
                  AXIS_CONFIG_C => SAXIS_MASTER_CONFIG_C )
    port map (    clk        => evrClk,
                  strobe     => rStrobe(rStrobe'left),
                  modeSel    => modeSel,
                  dmaCntl    => dmaCtrl,
                  dmaData    => dmaData,
                  dmaMaster  => dmaMaster,
                  dmaSlave   => dmaSlave );
  
  U_BsaControl : entity work.EvrV2BsaControl
    generic map ( TPD_G      => TPD_G )
    port map (    evrClk     => evrClk,
                  evrRst     => evrRst,
                  enable     => anyBsaEnabled,
                  strobeIn   => rStrobe(0),
                  dataIn     => timingMsg,
                  dmaData    => dmaData        (ReadoutChannels) );

  Loop_BsaCh: for i in 0 to ReadoutChannels-1 generate
    U_EventSel : entity work.EvrV2EventSelect
      generic map ( TPD_G         => TPD_G )
      port map    ( clk           => evrClk,
                    rst           => evrRst,
                    config        => channelConfigS(i),
                    strobeIn      => rStrobe(i*STROBE_INTERVAL_C+5),
                    dataIn        => timingMsg,
                    exptIn        => exptBus,
                    selectOut     => eventSel(i),
                    dmaOut        => dmaSel(i) );
    U_BsaChannel : entity work.EvrV2BsaChannel
      generic map ( TPD_G         => TPD_G,
                    CHAN_C        => i,
                    DEBUG_C       => ite(i>0,false,DEBUG_C) )
      port map    ( evrClk        => evrClk,
                    evrRst        => evrRst,
                    channelConfig => channelConfigS(i),
                    evtSelect     => dmaSel(i),
                    strobeIn      => rStrobe(i*STROBE_INTERVAL_C+6),
                    dataIn        => timingMsg,
                    dmaData       => dmaData(i) );
  end generate;  -- i

  U_EventDma : entity work.EvrV2EventDma
    generic map ( TPD_G      => TPD_G,
                  CHANNELS_C => ReadoutChannels )
    port map (    clk        => evrClk,
                  rst        => evrBus.strobe,
                  strobe     => rStrobe(ReadoutChannels*STROBE_INTERVAL_C+10),
                  eventSel   => dmaSel,
                  eventData  => timingMsg,
                  dmaData    => dmaData   (ReadoutChannels+1) );

  U_V2FromV1 : entity work.EvrV2FromV1
    port map ( clk       => evrClk,
               disable   => modeSel,
               timingIn  => evrBus,
               timingOut => timingMsg );

  process (evrClk)
  begin
    if rising_edge(evrClk) then
      rStrobe    <= rStrobe(rStrobe'left-1 downto 0) & evrBus.strobe;
    end if;
  end process;

  SyncVector_Gtx : entity work.SynchronizerVector
    generic map (
      TPD_G          => TPD_G,
      WIDTH_G        => 8)
    port map (
      clk                   => axiClk,
      dataIn                => gtxDebug,
      dataOut               => gtxDebugS );

  Sync_EvtCount : entity work.SyncStatusVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => ReadoutChannels+1 )
    port map    ( statusIn(ReadoutChannels) => evrBus.strobe,
                  statusIn(ReadoutChannels-1 downto 0) => eventSel,
                  cntRstIn     => rstCount,
                  rollOverEnIn => (others=>'1'),
                  cntOut       => eventCount,
                  wrClk        => evrClk,
                  wrRst        => '0',
                  rdClk        => axiClk,
                  rdRst        => axiRst );

  triggerStrobe <= rStrobe(rStrobe'left) when modeSel='0' else
                   evrBus.strobe;
  
  Out_Trigger: for i in 0 to TriggerOutputs-1 generate
     U_Trig : entity work.EvrV2Trigger
        generic map ( TPD_G        => TPD_G,
                      CHANNELS_C   => ReadoutChannels,
                      TRIG_DEPTH_C => 256,
                      --DEBUG_C    => (i<1) )
                      DEBUG_C      => false )
        port map (    clk      => evrClk,
                      rst      => evrRst,
                      config   => triggerConfigS(i),
                      arm      => eventSel,
                      fire     => triggerStrobe,
                      trigstate=> dbTrigOut(i) );
  end generate Out_Trigger;
  
  U_EvrAxi : entity work.EvrV2Axi
    generic map ( TPD_G        => TPD_G,
                  DMA_ENABLE_G => true,
                  CHANNELS_C   => ReadoutChannels )
    port map (    axiClk              => axiClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => mAxiWriteMasters (CSR_INDEX_C),
                  axilWriteSlave      => mAxiWriteSlaves  (CSR_INDEX_C),
                  axilReadMaster      => mAxiReadMasters  (CSR_INDEX_C),
                  axilReadSlave       => mAxiReadSlaves   (CSR_INDEX_C),
                  -- configuration
                  irqEnable           => irqEnable,
                  channelConfig       => channelConfig,
                  trigSel             => open,
                  dmaFullThr          => dmaFullThr(0),
                  -- status
                  irqReq              => irqRequest,
                  partitionAddr       => partitionAddr,
                  rstCount            => rstCount,
                  eventCount          => eventCount,
                  gtxDebug            => gtxDebugS );

  U_EvrTrigReg : entity work.EvrV2TrigReg
    generic map ( TPD_G      => TPD_G,
                  TRIGGERS_C => TriggerOutputs,
                  USE_TAP_C  => true )
    port map (    axiClk              => axiClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => mAxiWriteMasters (TRG_INDEX_C),
                  axilWriteSlave      => mAxiWriteSlaves  (TRG_INDEX_C),
                  axilReadMaster      => mAxiReadMasters  (TRG_INDEX_C),
                  axilReadSlave       => mAxiReadSlaves   (TRG_INDEX_C),
                  -- configuration
                  triggerConfig       => triggerConfig,
                  -- status
                  delay_rd            => delay_rd(TriggerOutputs-1 downto 0) );

  anyBsaEnabled <= uOr(bsaEnabled);

  -- Synchronize configurations to evrClk
  Sync_Channel: for i in 0 to ReadoutChannels-1 generate
    
    U_SyncRate : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => channelConfig (i).rateSel'length)
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => channelConfig (i).rateSel,
                    dataOut => channelConfigS(i).rateSel );
    
    U_SyncDest : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => channelConfig (i).destSel'length)
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => channelConfig (i).destSel,
                    dataOut => channelConfigS(i).destSel );
     
    Sync_Enable : entity work.Synchronizer
      generic map ( TPD_G   => TPD_G )
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => channelConfig (i).enabled,
                    dataOut => channelConfigS(i).enabled );

    Sync_dmaEnable : entity work.Synchronizer
      generic map ( TPD_G   => TPD_G )
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => channelConfig (i).dmaEnabled,
                    dataOut => channelConfigS(i).dmaEnabled );

    Sync_bsaEnable : entity work.Synchronizer
      generic map ( TPD_G   => TPD_G )
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => channelConfig (i).bsaEnabled,
                    dataOut => bsaEnabled(i) );

    channelConfigS(i).bsaEnabled <= bsaEnabled(i);
    
    Sync_Setup : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => channelConfig (i).bsaActiveSetup'length)
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => channelConfig (i).bsaActiveSetup,
                    dataOut => channelConfigS(i).bsaActiveSetup );
    
    Sync_Delay : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => channelConfig (i).bsaActiveDelay'length)
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => channelConfig (i).bsaActiveDelay,
                    dataOut => channelConfigS(i).bsaActiveDelay );
    
    Sync_Width : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => channelConfig (i).bsaActiveWidth'length)
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => channelConfig (i).bsaActiveWidth,
                    dataOut => channelConfigS(i).bsaActiveWidth );
  
  end generate Sync_Channel;

  Sync_Trigger: for i in 0 to TriggerOutputs-1 generate
    
    Sync_Enable : entity work.Synchronizer
      generic map ( TPD_G   => TPD_G )
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => triggerConfig (i).enabled,
                    dataOut => triggerConfigS(i).enabled );

    Sync_Polarity : entity work.Synchronizer
      generic map ( TPD_G   => TPD_G )
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => triggerConfig (i).polarity,
                    dataOut => triggerConfigS(i).polarity );

    Sync_Channel : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => triggerConfig (i).channel'length)
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => triggerConfig (i).channel,
                    dataOut => triggerConfigS(i).channel );
    
    U_SyncDelay : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => triggerConfig (i).delay'length)
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => triggerConfig (i).delay,
                    dataOut => triggerConfigS(i).delay );
    
    U_SyncWidth : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => triggerConfig (i).width'length)
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => triggerConfig (i).width,
                    dataOut => triggerConfigS(i).width );

    U_SyncTap : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => triggerConfig (i).delayTap'length)
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => triggerConfig (i).delayTap,
                    dataOut => triggerConfigS(i).delayTap );

    U_SyncTapLd : entity work.SynchronizerOneShot
      generic map ( TPD_G   => TPD_G )
      port map (    clk     => evrClk,
                    rst     => evrRst,
                    dataIn  => triggerConfig (i).loadTap,
                    dataOut => triggerConfigS(i).loadTap );

    delay_wrb(i) <= triggerConfig(i).delayTap;
    delay_ldb(i) <= triggerConfig(i).loadTap;

  end generate Sync_Trigger;

  Sync_dmaFullThr : entity work.SynchronizerVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => 24 )
    port map (    clk     => evrClk,
                  rst     => evrRst,
                  dataIn  => dmaFullThr (0),
                  dataOut => dmaFullThrS(0) );

  Sync_partAddr : entity work.SynchronizerVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => partitionAddr'length )
    port map (    clk     => axiClk,
                  dataIn  => exptBus.message.partitionAddr,
                  dataOut => partitionAddr );

end mapping;
