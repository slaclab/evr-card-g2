-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2Core.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2020-02-03
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
use work.TimingExtnPkg.all;
use work.EvrV2Pkg.all;
--use work.PciPkg.all;
use work.SsiPkg.all;

entity EvrV2Core is
  generic (
    TPD_G          : time             := 1 ns;
    AXIL_BASEADDR0 : slv(31 downto 0) := x"00060000";
    AXIL_BASEADDR1 : slv(31 downto 0) := x"00080000" );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterArray(1 downto 0);
    axilWriteSlave      : out AxiLiteWriteSlaveArray (1 downto 0);
    axilReadMaster      : in  AxiLiteReadMasterArray (1 downto 0);
    axilReadSlave       : out AxiLiteReadSlaveArray  (1 downto 0);
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

  constant NTRIGGERS_C       : natural := TriggerOutputs;
  constant NHARDCHANS_C      : natural := ReadoutChannels;
--  constant NSOFTCHANS    _C  : natural := 0;
  constant NSOFTCHANS_C      : natural := 2;
  constant NCHANNELS_C       : natural := NHARDCHANS_C+NSOFTCHANS_C;
  constant MAXCHANNELS_C     : natural := 16;
  constant NUM_AXI_MASTERS_C : natural := 2;
  
  constant CSR_INDEX_C       : natural := 0;
  constant DMA_INDEX_C       : natural := 1;
  constant AXI_CROSSBAR_MASTERS_CONFIG0_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) :=
    genAxiLiteConfig( 2, AXIL_BASEADDR0, 16, 10 );
  signal mAxiWriteMasters0 : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiWriteSlaves0  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadMasters0  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadSlaves0   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

  constant TRIG_INDEX_C      : natural := 1;
  constant CHAN_INDEX_C      : natural := 0;
  constant AXI_CROSSBAR_MASTERS_CONFIG1_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) :=
    genAxiLiteConfig( 2, AXIL_BASEADDR1, 18, 17 );
  signal mAxiWriteMasters1 : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiWriteSlaves1  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadMasters1  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadSlaves1   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

  constant AXI_CROSSBAR_MASTERS_CONFIG2_C : AxiLiteCrossbarMasterConfigArray(1 downto 0) :=
    genAxiLiteConfig( 2, AXI_CROSSBAR_MASTERS_CONFIG1_C(CHAN_INDEX_C).baseAddr, 17, 15 );
  signal mAxiWriteMasters2 : AxiLiteWriteMasterArray(1 downto 0);
  signal mAxiWriteSlaves2  : AxiLiteWriteSlaveArray (1 downto 0);
  signal mAxiReadMasters2  : AxiLiteReadMasterArray (1 downto 0);
  signal mAxiReadSlaves2   : AxiLiteReadSlaveArray  (1 downto 0);
  
  constant STROBE_INTERVAL_C : integer := 12;

  signal channelConfig    : EvrV2ChannelConfigArray(MAXCHANNELS_C-1 downto 0);
  signal channelConfigS   : EvrV2ChannelConfigArray(NCHANNELS_C-1 downto 0) := (others=>EVRV2_CHANNEL_CONFIG_INIT_C);
  signal channelConfigAV  : slv(NCHANNELS_C*EVRV2_CHANNEL_CONFIG_BITS_C-1 downto 0);
  signal channelConfigSV  : slv(NCHANNELS_C*EVRV2_CHANNEL_CONFIG_BITS_C-1 downto 0);
  signal triggerConfig    : EvrV2TriggerConfigArray(NTRIGGERS_C-1 downto 0);
  signal triggerConfigS   : EvrV2TriggerConfigArray(NTRIGGERS_C-1 downto 0) := (others=>EVRV2_TRIGGER_CONFIG_INIT_C);
  signal triggerConfigAV  : slv(NTRIGGERS_C*EVRV2_TRIGGER_CONFIG_BITS_C-1 downto 0);
  signal triggerConfigSV  : slv(NTRIGGERS_C*EVRV2_TRIGGER_CONFIG_BITS_C-1 downto 0);

  signal gtxDebugS   : slv(7 downto 0);

  type RegType is record
    strobe      : slv       (198 downto 0);
    count       : slv       ( 27 downto 0);
    reset       : sl;
    eventSel    : slv       (NCHANNELS_C downto 0);
    dmaSel      : slv       (NCHANNELS_C downto 0);
    eventCount  : Slv20Array(NCHANNELS_C downto 0);
    eventCountL : Slv20Array(NCHANNELS_C downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    strobe      => (others=>'0'),
    count       => (others=>'0'),
    reset       => '1',
    eventSel    => (others=>'0'),
    dmaSel      => (others=>'0'),
    eventCount  => (others=>(others=>'0')),
    eventCountL => (others=>(others=>'0')) );

  signal r    : RegType := REG_INIT_C;
  signal rin  : RegType;
  
  signal timingMsg      : TimingMessageType := TIMING_MESSAGE_INIT_C;
  signal timingMsg_i    : TimingMessageType := TIMING_MESSAGE_INIT_C;
  signal dmaSel         : slv(NCHANNELS_C-1 downto 0) := (others=>'0');
  signal eventSel       : slv(15 downto 0) := (others=>'0');
  signal eventSel_i     : slv(15 downto 0) := (others=>'0');
  signal summarySel     : slv(15 downto 0) := (others=>'0');
  signal eventCountV    : Slv32Array(MAXCHANNELS_C downto 0) := (others=>(others=>'0'));
  
  signal dmaCtrl    : AxiStreamCtrlType;
  signal dmaData    : EvrV2DmaDataArray(NCHANNELS_C downto 0) := (others=>EVRV2_DMA_DATA_INIT_C);

  constant SAXIS_MASTER_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);
  
  signal dmaMaster : AxiStreamMasterType;
  signal dmaSlave  : AxiStreamSlaveType;

  signal pciClk : sl;
  signal pciRst : sl;

  signal rxDescToPci   : DescToPcieType;
  signal rxDescFromPci : DescFromPcieType;

  signal dmaEnabled    : slv(NCHANNELS_C-1 downto 0);
  signal anyDmaEnabled : sl;
  
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
                 probe0(56 downto 47) => eventSel(9 downto 0),
                 probe0(66 downto 57) => dmaSel  (9 downto 0),
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

  --  Each BSA Channel occupies 11 clocks
  --  BSA Control occupies 10 clocks
  --  EventDMA occupies 22 clocks
--  assert (rStrobe'length <= 200)
  assert (NHARDCHANS_C*STROBE_INTERVAL_C+34 < 200)
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
  AxiLiteCrossbar0_Inst : entity work.AxiLiteCrossbar
    generic map (
      TPD_G              => TPD_G,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => 2,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG0_C)
    port map (
      axiClk              => axiClk,
      axiClkRst           => axiRst,
      sAxiWriteMasters(0) => axilWriteMaster(0),
      sAxiWriteSlaves (0) => axilWriteSlave (0),
      sAxiReadMasters (0) => axilReadMaster (0),
      sAxiReadSlaves  (0) => axilReadSlave  (0),
      mAxiWriteMasters    => mAxiWriteMasters0,
      mAxiWriteSlaves     => mAxiWriteSlaves0,
      mAxiReadMasters     => mAxiReadMasters0,
      mAxiReadSlaves      => mAxiReadSlaves0);   

  AxiLiteCrossbar1_Inst : entity work.AxiLiteCrossbar
    generic map (
      TPD_G              => TPD_G,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => 2,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG1_C)
    port map (
      axiClk              => axiClk,
      axiClkRst           => axiRst,
      sAxiWriteMasters(0) => axilWriteMaster(1),
      sAxiWriteSlaves (0) => axilWriteSlave (1),
      sAxiReadMasters (0) => axilReadMaster (1),
      sAxiReadSlaves  (0) => axilReadSlave  (1),
      mAxiWriteMasters    => mAxiWriteMasters1,
      mAxiWriteSlaves     => mAxiWriteSlaves1,
      mAxiReadMasters     => mAxiReadMasters1,
      mAxiReadSlaves      => mAxiReadSlaves1);   
  
  U_Reg : entity work.EvrV2Reg
    generic map ( TPD_G        => TPD_G,
                  DMA_ENABLE_G => true )
    port map (    axiClk              => axiClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => mAxiWriteMasters0 (CSR_INDEX_C),
                  axilWriteSlave      => mAxiWriteSlaves0  (CSR_INDEX_C),
                  axilReadMaster      => mAxiReadMasters0  (CSR_INDEX_C),
                  axilReadSlave       => mAxiReadSlaves0   (CSR_INDEX_C),
                  -- configuration
                  irqEnable           => irqEnable,
                  trigSel             => open,
                  dmaFullThr          => dmaFullThr(0),
                  -- status
                  irqReq              => irqRequest,
--                  partitionAddr       => partitionAddr,
                  rstCount            => open,
                  eventCount          => eventCountV(NCHANNELS_C),
                  gtxDebug            => gtxDebugS );
    
  U_PciRxDesc : entity work.EvrV2PcieRxDesc
    generic map ( DMA_SIZE_G       => 1 )
    port map (    dmaDescToPci  (0)=> rxDescToPci,
                  dmaDescFromPci(0)=> rxDescFromPci,
                  axiReadMaster    => mAxiReadMasters0 (DMA_INDEX_C),
                  axiReadSlave     => mAxiReadSlaves0  (DMA_INDEX_C),
                  axiWriteMaster   => mAxiWriteMasters0(DMA_INDEX_C),
                  axiWriteSlave    => mAxiWriteSlaves0 (DMA_INDEX_C),
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
    generic map ( CHANNELS_C    => ReadoutChannels+3,
                  AXIS_CONFIG_C => SAXIS_MASTER_CONFIG_C )
    port map (    clk        => evrClk,
                  strobe     => r.strobe(r.strobe'left),
                  modeSel    => modeSel,
                  dmaCntl    => dmaCtrl,
                  dmaData    => dmaData,
                  dmaMaster  => dmaMaster,
                  dmaSlave   => dmaSlave );
  
  U_BsaControl : entity work.EvrV2BsaControl
    generic map ( TPD_G      => TPD_G )
    port map (    evrClk     => evrClk,
                  evrRst     => evrRst,
                  enable     => anyDmaEnabled,
                  strobeIn   => r.strobe(0),
                  dataIn     => timingMsg,
                  dmaData    => dmaData        (ReadoutChannels) );

  Loop_EventSel: for i in 0 to NCHANNELS_C-1 generate
    U_EventSel : entity work.EvrV2EventSelect
      generic map ( TPD_G         => TPD_G )
      port map    ( clk           => evrClk,
                    rst           => evrRst,
                    config        => channelConfigS(i),
                    strobeIn      => r.strobe(0),
                    dataIn        => timingMsg,
                    selectOut     => eventSel_i(i),
                    dmaOut        => open );
    eventSel  (i) <= r.eventSel(i);
    dmaSel    (i) <= r.dmaSel  (i);
    summarySel(i) <= r.dmaSel  (i) and not channelConfigS(i).bsaEnabled;
  end generate;  -- i

  --  No longer needed?
  Loop_BsaCh: for i in 0 to NHARDCHANS_C-1 generate
    U_BsaChannel : entity work.EvrV2BsaChannelDSP
      generic map ( TPD_G         => TPD_G,
                    CHAN_C        => i,
                    DEBUG_C       => false )
      port map    ( evrClk        => evrClk,
                    evrRst        => evrRst,
                    channelConfig => channelConfigS(i),
                    evtSelect     => dmaSel(i),
                    strobeIn      => r.strobe(i*STROBE_INTERVAL_C+8),
                    dataIn        => timingMsg,
                    dmaData       => dmaData(i) );
  end generate;  -- i

  U_BsaSummary : entity work.EvrV2BsaChannelSummary
    generic map ( TPD_G         => TPD_G )
    port map    ( evrClk        => evrClk,
                  evrRst        => evrRst,
                  enable        => '1',
                  evtSelect     => summarySel,
                  strobeIn      => r.strobe(NHARDCHANS_C*STROBE_INTERVAL_C+15),
                  dataIn        => timingMsg,
                  dmaData       => dmaData(NHARDCHANS_C+2) );
  
  U_EventDma : entity work.EvrV2EventDma
    generic map ( TPD_G      => TPD_G,
                  CHANNELS_C => dmaSel'length )
    port map (    clk        => evrClk,
                  rst        => evrBus.strobe,
                  strobe     => r.strobe(NHARDCHANS_C*STROBE_INTERVAL_C+30),
                  eventSel   => dmaSel,
                  eventData  => timingMsg,
                  dmaData    => dmaData   (NHARDCHANS_C+1) );

  U_V2FromV1 : entity work.EvrV2FromV1
    port map ( clk       => evrClk,
               disable   => modeSel,
               timingIn  => evrBus,
               timingOut => timingMsg_i );

  --  fixup pulseId from XTPG
  pid_fixup : process (timingMsg_i) is
  begin
    timingMsg <= timingMsg_i;
    if timingMsg_i.pulseId(63)='1' then
      timingMsg.pulseId <= timingMsg_i.timeStamp;
    end if;
  end process pid_fixup;
    
  comb : process ( r, evrBus, eventSel_i, evrModeSel, channelConfigS ) is
    variable v : RegType;
  begin
    v := r;

    v.reset  := '0';
    v.count  := r.count+1;
    v.strobe := r.strobe(r.strobe'left-1 downto 0) & evrBus.strobe;
    
    for i in 0 to NCHANNELS_C-1 loop
      --  Add in DAQ event selection
      v.eventSel(i) := eventSel_i(i);
      if r.strobe(0) = '1' then
        if channelConfigS(i).rateSel(12 downto 11)="11" then
          v.eventSel(i) := toTrigVector(evrBus.extn.expt)(conv_integer(channelConfigS(i).rateSel(2 downto 0)));
        end if;
      end if;
      v.dmaSel(i) := v.eventSel(i) and channelConfigS(i).dmaEnabled;
      if r.eventSel(i) = '1' then
        v.eventCount(i) := r.eventCount(i)+1;
      end if;
    end loop;
    if evrBus.strobe = '1' then
      v.eventCount(NCHANNELS_C) := r.eventCount(NCHANNELS_C)+1;
    end if;

    if ((evrModeSel = '0' and r.count = toSlv(118999998,28)) or
        (evrModeSel = '1' and r.count = toSlv(181999998,28))) then
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

  SyncVector_Gtx : entity work.SynchronizerVector
    generic map (
      TPD_G          => TPD_G,
      WIDTH_G        => 8)
    port map (
      clk                   => axiClk,
      dataIn                => gtxDebug,
      dataOut               => gtxDebugS );

  GEN_EVTCOUNT : for i in 0 to NCHANNELS_C generate
    Sync_EvtCount : entity work.SynchronizerVector
      generic map ( TPD_G   => TPD_G,
                    WIDTH_G => 20 )
      port map    ( clk      => axiClk,
                    dataIn   => r.eventCountL(i),
                    dataOut  => eventCountV  (i)(19 downto 0) );
  end generate;
  
  triggerStrobe <= r.strobe(r.strobe'left) when modeSel='0' else
                   evrBus.strobe;
  
  U_TReg  : entity work.EvrV2TrigReg
    generic map ( TPD_G      => TPD_G,
                  TRIGGERS_C => NTRIGGERS_C,
                  EVR_CARD_G => true,
                  USE_TAP_C  => true )
    port map (    axiClk              => axiClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => mAxiWriteMasters1 (TRIG_INDEX_C),
                  axilWriteSlave      => mAxiWriteSlaves1  (TRIG_INDEX_C),
                  axilReadMaster      => mAxiReadMasters1  (TRIG_INDEX_C),
                  axilReadSlave       => mAxiReadSlaves1   (TRIG_INDEX_C),
                  -- configuration
                  triggerConfig       => triggerConfig,
                  -- status
                  delay_rd            => delay_rd );

  Out_Trigger: for i in 0 to NTRIGGERS_C-1 generate
     U_Trig : entity work.EvrV2Trigger
        generic map ( TPD_G        => TPD_G,
                      CHANNELS_C   => NHARDCHANS_C,
                      TRIG_DEPTH_C => 256,
                      USE_MASK_G   => false,
                      --DEBUG_C    => (i<1) )
                      DEBUG_C      => false )
        port map (    clk      => evrClk,
                      rst      => evrRst,
                      config   => triggerConfigS(i),
                      arm      => eventSel(NHARDCHANS_C-1 downto 0),
                      fire     => triggerStrobe,
                      trigstate=> dbTrigOut(i) );
  end generate Out_Trigger;

  --
  --  Add an AxiLiteCrossbar for timing closure
  --
  AxiLiteCrossbar2_Inst : entity work.AxiLiteCrossbar
    generic map (
      TPD_G              => TPD_G,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => AXI_CROSSBAR_MASTERS_CONFIG2_C'length,
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG2_C)
    port map (
      axiClk              => axiClk,
      axiClkRst           => axiRst,
      sAxiWriteMasters(0) => mAxiWriteMasters1(CHAN_INDEX_C),
      sAxiWriteSlaves (0) => mAxiWriteSlaves1 (CHAN_INDEX_C),
      sAxiReadMasters (0) => mAxiReadMasters1 (CHAN_INDEX_C),
      sAxiReadSlaves  (0) => mAxiReadSlaves1  (CHAN_INDEX_C),
      mAxiWriteMasters    => mAxiWriteMasters2,
      mAxiWriteSlaves     => mAxiWriteSlaves2,
      mAxiReadMasters     => mAxiReadMasters2,
      mAxiReadSlaves      => mAxiReadSlaves2);   
  
  GEN_EVRCHANREG : for i in 0 to 1 generate
    U_EvrChanReg : entity work.EvrV2ChannelReg
      generic map ( TPD_G        => TPD_G,
                    NCHANNELS_G  => 8,
                    DMA_ENABLE_G => true,
                    EVR_CARD_G   => true )
      port map (    axiClk              => axiClk,
                    axiRst              => axiRst,
                    axilWriteMaster     => mAxiWriteMasters2 (i),
                    axilWriteSlave      => mAxiWriteSlaves2  (i),
                    axilReadMaster      => mAxiReadMasters2  (i),
                    axilReadSlave       => mAxiReadSlaves2   (i),
                    -- configuration
                    channelConfig       => channelConfig(8*i+7 downto 8*i),
                    -- status
                    eventCount          => eventCountV(8*i+7 downto 8*i) );
  end generate;
  
  anyDmaEnabled <= uOr(dmaEnabled);

  -- Synchronize configurations to evrClk
  U_SyncChannelConfig : entity work.SynchronizerVector
    generic map ( WIDTH_G => NCHANNELS_C*EVRV2_CHANNEL_CONFIG_BITS_C )
    port map ( clk     => evrClk,
               dataIn  => channelConfigAV,
               dataOut => channelConfigSV );

  Sync_Channel: for i in 0 to NCHANNELS_C-1 generate
    channelConfigAV((i+1)*EVRV2_CHANNEL_CONFIG_BITS_C-1 downto i*EVRV2_CHANNEL_CONFIG_BITS_C)
        <= toSlv(channelConfig(i));
    channelConfigS(i) <= toChannelConfig(channelConfigSV((i+1)*EVRV2_CHANNEL_CONFIG_BITS_C-1 downto i*EVRV2_CHANNEL_CONFIG_BITS_C));

    dmaEnabled(i) <= channelConfigS(i).dmaEnabled;
  end generate Sync_Channel;

  U_SyncTriggerConfig : entity work.SynchronizerVector
    generic map ( WIDTH_G => NTRIGGERS_C*EVRV2_TRIGGER_CONFIG_BITS_C )
    port map ( clk     => evrClk,
               dataIn  => triggerConfigAV,
               dataOut => triggerConfigSV );
 
  Sync_Trigger: for i in 0 to NTRIGGERS_C-1 generate
    
    triggerConfigAV((i+1)*EVRV2_TRIGGER_CONFIG_BITS_C-1 downto i*EVRV2_TRIGGER_CONFIG_BITS_C)
      <= toSlv(triggerConfig(i));
    triggerConfigS(i) <= toTriggerConfig(triggerConfigSV((i+1)*EVRV2_TRIGGER_CONFIG_BITS_C-1 downto i*EVRV2_TRIGGER_CONFIG_BITS_C));

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
                  dataIn  => evrBus.extn.expt.partitionAddr,
                  dataOut => partitionAddr );

end mapping;
