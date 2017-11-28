-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2Core.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-11-28
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

  constant NTRIGGERS_C       : natural := TriggerOutputs;
  constant NHARDCHANS_C      : natural := ReadoutChannels;
--  constant NSOFTCHANS    _C  : natural := 0;
  constant NSOFTCHANS_C      : natural := 2;
  constant NCHANNELS_C       : natural := NHARDCHANS_C+NSOFTCHANS_C;
  constant NUM_AXI_MASTERS_C : natural := 2+NCHANNELS_C+NTRIGGERS_C;
  constant CSR_INDEX_C       : natural := 0;
  constant DMA_INDEX_C       : natural := 1;
  constant CHAN_INDEX_C      : natural := 2;
  constant TRIG_INDEX_C      : natural := 2+NCHANNELS_C;
  
  function crossBarConfig return AxiLiteCrossbarMasterConfigArray is
    variable ret : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0);
    variable i   : integer;
    variable a   : slv(31 downto 0);
  begin
    ret(0).baseAddr := AXIL_BASEADDR;
    ret(0).addrBits := 8;
    ret(0).connectivity := x"FFFF";
    ret(1).baseAddr := AXIL_BASEADDR + toSlv(256,32);
    ret(1).addrBits := 8;
    ret(1).connectivity := x"FFFF";
    for i in 0 to NCHANNELS_C-1 loop
      ret(i+CHAN_INDEX_C).baseAddr := AXIL_BASEADDR + toSlv((i+1)*4096,32);
      ret(i+CHAN_INDEX_C).addrBits := 6;
      ret(i+CHAN_INDEX_C).connectivity := x"FFFF";
    end loop;
    for i in 0 to NTRIGGERS_C-1 loop
      ret(i+TRIG_INDEX_C).baseAddr := AXIL_BASEADDR + toSlv((i+1+NCHANNELS_C)*4096,32);
      ret(i+TRIG_INDEX_C).addrBits := 6;
      ret(i+TRIG_INDEX_C).connectivity := x"FFFF";
    end loop;
    return ret;
  end function;
  
  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := crossBarConfig;

  signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);
  
  constant STROBE_INTERVAL_C : integer := 12;
  
  signal channelConfig    : EvrV2ChannelConfigArray(NCHANNELS_C-1 downto 0);
  signal channelConfigS   : EvrV2ChannelConfigArray(NCHANNELS_C-1 downto 0) := (others=>EVRV2_CHANNEL_CONFIG_INIT_C);
  signal channelConfigAV  : slv(NCHANNELS_C*EVRV2_CHANNEL_CONFIG_BITS_C-1 downto 0);
  signal channelConfigSV  : slv(NCHANNELS_C*EVRV2_CHANNEL_CONFIG_BITS_C-1 downto 0);
  signal triggerConfig    : EvrV2TriggerConfigArray(NTRIGGERS_C-1 downto 0);
  signal triggerConfigS   : EvrV2TriggerConfigArray(NTRIGGERS_C-1 downto 0) := (others=>EVRV2_TRIGGER_CONFIG_INIT_C);
  signal triggerConfigAV  : slv(NTRIGGERS_C*EVRV2_TRIGGER_CONFIG_BITS_C-1 downto 0);
  signal triggerConfigSV  : slv(NTRIGGERS_C*EVRV2_TRIGGER_CONFIG_BITS_C-1 downto 0);

  signal gtxDebugS   : slv(7 downto 0);

  signal rStrobe        : slv(198 downto 0) := (others=>'0');
  
  signal timingMsg      : TimingMessageType := TIMING_MESSAGE_INIT_C;
  signal dmaSel         : slv(NCHANNELS_C-1 downto 0) := (others=>'0');
  signal eventSel       : slv(15 downto 0) := (others=>'0');
  signal summarySel     : slv(15 downto 0) := (others=>'0');
  signal eventCount     : SlVectorArray(NCHANNELS_C downto 0,31 downto 0);
  signal eventCountV    : Slv32Array(NCHANNELS_C downto 0);
  signal rstCount : sl;
  
  signal dmaCtrl    : AxiStreamCtrlType;
  signal dmaData    : EvrV2DmaDataArray(NHARDCHANS_C+2 downto 0);

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

  eventCountV(NCHANNELS_C) <= muxSlVectorArray(eventCount,NCHANNELS_C);
  
  U_Reg : entity work.EvrV2Reg
    generic map ( TPD_G        => TPD_G,
                  DMA_ENABLE_G => true )
    port map (    axiClk              => axiClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => mAxiWriteMasters (CSR_INDEX_C),
                  axilWriteSlave      => mAxiWriteSlaves  (CSR_INDEX_C),
                  axilReadMaster      => mAxiReadMasters  (CSR_INDEX_C),
                  axilReadSlave       => mAxiReadSlaves   (CSR_INDEX_C),
                  -- configuration
                  irqEnable           => irqEnable,
                  trigSel             => open,
                  dmaFullThr          => dmaFullThr(0),
                  -- status
                  irqReq              => irqRequest,
                  partitionAddr       => partitionAddr,
                  rstCount            => rstCount,
                  eventCount          => eventCountV(NCHANNELS_C),
                  gtxDebug            => gtxDebugS );
    
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
    generic map ( CHANNELS_C    => ReadoutChannels+3,
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
                  enable     => anyDmaEnabled,
                  strobeIn   => rStrobe(0),
                  dataIn     => timingMsg,
                  dmaData    => dmaData        (ReadoutChannels) );

  Loop_EventSel: for i in 0 to NCHANNELS_C-1 generate
    U_EventSel : entity work.EvrV2EventSelect
      generic map ( TPD_G         => TPD_G )
      port map    ( clk           => evrClk,
                    rst           => evrRst,
                    config        => channelConfigS(i),
                    strobeIn      => rStrobe(0),
                    dataIn        => timingMsg,
                    exptIn        => exptBus,
                    selectOut     => eventSel(i),
                    dmaOut        => dmaSel(i) );
    summarySel(i) <= dmaSel(i) and not channelConfigS(i).bsaEnabled;
  end generate;  -- i

  Loop_BsaCh: for i in 0 to NHARDCHANS_C-1 generate
    U_BsaChannel : entity work.EvrV2BsaChannelDSP
      generic map ( TPD_G         => TPD_G,
                    CHAN_C        => i,
                    DEBUG_C       => ite(i>0,false,DEBUG_C) )
      port map    ( evrClk        => evrClk,
                    evrRst        => evrRst,
                    channelConfig => channelConfigS(i),
                    evtSelect     => dmaSel(i),
                    strobeIn      => rStrobe(i*STROBE_INTERVAL_C+8),
                    dataIn        => timingMsg,
                    dmaData       => dmaData(i) );
  end generate;  -- i

  U_BsaSummary : entity work.EvrV2BsaChannelSummary
    generic map ( TPD_G         => TPD_G )
    port map    ( evrClk        => evrClk,
                  evrRst        => evrRst,
                  enable        => '1',
                  evtSelect     => summarySel,
                  strobeIn      => rStrobe(NHARDCHANS_C*STROBE_INTERVAL_C+15),
                  dataIn        => timingMsg,
                  dmaData       => dmaData(NHARDCHANS_C+2) );
  
  U_EventDma : entity work.EvrV2EventDma
    generic map ( TPD_G      => TPD_G,
                  CHANNELS_C => dmaSel'length )
    port map (    clk        => evrClk,
                  rst        => evrBus.strobe,
                  strobe     => rStrobe(NHARDCHANS_C*STROBE_INTERVAL_C+30),
                  eventSel   => dmaSel,
                  eventData  => timingMsg,
                  dmaData    => dmaData   (NHARDCHANS_C+1) );

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
                  WIDTH_G => NCHANNELS_C+1 )
    port map    ( statusIn(NCHANNELS_C) => evrBus.strobe,
                  statusIn(NCHANNELS_C-1 downto 0) => eventSel(NCHANNELS_C-1 downto 0),
                  cntRstIn     => rstCount,
                  rollOverEnIn => (others=>'1'),
                  cntOut       => eventCount,
                  wrClk        => evrClk,
                  wrRst        => '0',
                  rdClk        => axiClk,
                  rdRst        => axiRst );

  triggerStrobe <= rStrobe(rStrobe'left) when modeSel='0' else
                   evrBus.strobe;
  
  Out_Trigger: for i in 0 to NTRIGGERS_C-1 generate
     U_Reg  : entity work.EvrV2TriggerReg
       generic map ( TPD_G      => TPD_G,
                     USE_TAP_C  => true )
       port map (    axiClk              => axiClk,
                     axiRst              => axiRst,
                     axilWriteMaster     => mAxiWriteMasters (TRIG_INDEX_C+i),
                     axilWriteSlave      => mAxiWriteSlaves  (TRIG_INDEX_C+i),
                     axilReadMaster      => mAxiReadMasters  (TRIG_INDEX_C+i),
                     axilReadSlave       => mAxiReadSlaves   (TRIG_INDEX_C+i),
                     -- configuration
                     triggerConfig       => triggerConfig(i),
                     -- status
                     delay_rd            => delay_rd(i) );

     U_Trig : entity work.EvrV2Trigger
        generic map ( TPD_G        => TPD_G,
                      TRIG_DEPTH_C => 256,
                      USE_MASK_G   => true,
                      --DEBUG_C    => (i<1) )
                      DEBUG_C      => false )
        port map (    clk      => evrClk,
                      rst      => evrRst,
                      config   => triggerConfigS(i),
                      arm      => eventSel,
                      fire     => triggerStrobe,
                      trigstate=> dbTrigOut(i) );
  end generate Out_Trigger;
  
  GEN_CHANREG: for i in 0 to NCHANNELS_C-1 generate
    eventCountV(i) <= muxSlVectorArray(eventCount,i);
    U_EvrChanReg : entity work.EvrV2ChannelReg
      generic map ( TPD_G        => TPD_G,
                    DMA_ENABLE_G => true )
      port map (    axiClk              => axiClk,
                    axiRst              => axiRst,
                    axilWriteMaster     => mAxiWriteMasters (CHAN_INDEX_C+i),
                    axilWriteSlave      => mAxiWriteSlaves  (CHAN_INDEX_C+i),
                    axilReadMaster      => mAxiReadMasters  (CHAN_INDEX_C+i),
                    axilReadSlave       => mAxiReadSlaves   (CHAN_INDEX_C+i),
                    -- configuration
                    channelConfig       => channelConfig(i),
                    -- status
                    eventCount          => eventCountV(i));
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
                  dataIn  => exptBus.message.partitionAddr,
                  dataOut => partitionAddr );

end mapping;
