-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2Module.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-03-28
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
use work.TimingPkg.all;
use work.EvrV2Pkg.all;

entity EvrV2Module is
  generic (
    TPD_G         : time             := 1 ns;
    NCHANNELS_G   : integer          := 1;   -- event selection channels
    NTRIGGERS_G   : integer          := 1;   -- trigger outputs
    TRIG_DEPTH_G  : integer          := 16;  -- maximum pipelined triggers
    COMMON_CLK_G  : boolean          := false;
    AXIL_BASEADDR : slv(31 downto 0) := x"00080000" );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    evrBus              : in  TimingBusType;
    exptBus             : in  ExptBusType;
    -- Trigger and Sync Port
    trigOut             : out slv(NTRIGGERS_G-1 downto 0);
    evrModeSel          : in  sl := '1' );
end EvrV2Module;

architecture mapping of EvrV2Module is

  constant NUM_AXI_MASTERS_C : natural := 2;
  constant CSR_INDEX_C       : natural := 0;
  constant TRG_INDEX_C       : natural := 1;

  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    CSR_INDEX_C      => (
      baseAddr      => x"00000000" + AXIL_BASEADDR,
      addrBits      => 9,
      connectivity  => X"0001"),
    TRG_INDEX_C => (
      baseAddr      => x"00000200" + AXIL_BASEADDR,
      addrBits      => 9,
      connectivity  => X"0001") );

  signal maxiWriteMaster : AxiLiteWriteMasterType;
  signal maxiWriteSlave  : AxiLiteWriteSlaveType;
  signal maxiReadMaster  : AxiLiteReadMasterType;
  signal maxiReadSlave   : AxiLiteReadSlaveType;

  signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);
  
  constant STROBE_INTERVAL_C : integer := 12;

  signal channelConfig    : EvrV2ChannelConfigArray(NCHANNELS_G-1 downto 0);
  signal triggerConfig    : EvrV2TriggerConfigArray(NTRIGGERS_G-1 downto 0);
  
  signal rStrobe        : slv(5 downto 0) := (others=>'0');
  signal timingMsg      : TimingMessageType := TIMING_MESSAGE_INIT_C;
  signal eventSel       : slv(NCHANNELS_G-1 downto 0) := (others=>'0');
  signal eventCount     : SlVectorArray(NCHANNELS_G downto 0,31 downto 0);
  signal rstCount       : sl;
  
begin  -- rtl

  assert (rStrobe'length <= 200)
    report "rStrobe'length exceeds clocks per cycle"
    severity failure;
  
  GEN_ASYNC : if not COMMON_CLK_G generate
    AxiLiteAsync_Inst : entity work.AxiLiteAsync
      generic map ( TPD_G        => TPD_G )
      port map ( -- Slave Port
        sAxiClk         => axiClk,
        sAxiClkRst      => axiRst,
        sAxiReadMaster  => axiReadMaster,
        sAxiReadSlave   => axiReadSlave,
        sAxiWriteMaster => axiWriteMaster,
        sAxiWriteSlave  => axiWriteSlave,
        -- Master Port
        mAxiClk         => evrClk,
        mAxiClkRst      => evrRst,
        mAxiReadMaster  => maxiReadMaster,
        mAxiReadSlave   => maxiReadSlave,
        mAxiWriteMaster => maxiWriteMaster,
        mAxiWriteSlave  => maxiWriteSlave );
  end generate;

  GEN_SYNC : if COMMON_CLK_G generate
    maxiReadMaster  <= axiReadMaster;
    maxiWriteMaster <= axiWriteMaster;
    axiReadSlave    <= maxiReadSlave;
    axiWriteSlave   <= maxiWriteSlave;
  end generate;
  
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
      axiClk              => evrClk,
      axiClkRst           => evrRst,
      sAxiWriteMasters(0) => maxiWriteMaster,
      sAxiWriteSlaves (0) => maxiWriteSlave,
      sAxiReadMasters (0) => maxiReadMaster,
      sAxiReadSlaves  (0) => maxiReadSlave,
      mAxiWriteMasters    => mAxiWriteMasters,
      mAxiWriteSlaves     => mAxiWriteSlaves,
      mAxiReadMasters     => mAxiReadMasters,
      mAxiReadSlaves      => mAxiReadSlaves);   
  
  Loop_EvtSel: for i in 0 to NCHANNELS_G-1 generate
    U_EventSel : entity work.EvrV2EventSelect
      generic map ( TPD_G         => TPD_G )
      port map    ( clk           => evrClk,
                    rst           => evrRst,
                    config        => channelConfig(i),
                    strobeIn      => rStrobe(4),
                    dataIn        => timingMsg,
                    exptIn        => exptBus,
                    selectOut     => eventSel(i) );
  end generate;  -- i

  U_V2FromV1 : entity work.EvrV2FromV1
    port map ( clk       => evrClk,
               disable   => evrModeSel,
               timingIn  => evrBus,
               timingOut => timingMsg );
  
  process (evrClk)
  begin  -- process
    if rising_edge(evrClk) then
      rStrobe    <= rStrobe(rStrobe'left-1 downto 0) & evrBus.strobe;
    end if;
  end process;
  
  Sync_EvtCount : entity work.SyncStatusVector
    generic map ( TPD_G   => TPD_G,
                  WIDTH_G => NCHANNELS_G+1 )
    port map    ( statusIn(NCHANNELS_G)            => evrBus.strobe,
                  statusIn(NCHANNELS_G-1 downto 0) => eventSel,
                  cntRstIn     => rstCount,
                  rollOverEnIn => (others=>'1'),
                  cntOut       => eventCount,
                  wrClk        => evrClk,
                  wrRst        => '0',
                  rdClk        => axiClk,
                  rdRst        => axiRst );

  Out_Trigger: for i in 0 to NTRIGGERS_G-1 generate
     U_Trig : entity work.EvrV2Trigger
        generic map ( TPD_G        => TPD_G,
                      CHANNELS_C   => NCHANNELS_G,
                      TRIG_DEPTH_G => TRIG_DEPTH_G,
                      DEBUG_C      => false )
        port map (    clk        => evrClk,
                      rst        => evrRst,
                      config     => triggerConfig(i),
                      arm        => eventSel,
                      fire       => rStrobe(5),
                      trigstate  => trigOut(i) );
  end generate Out_Trigger;
  
  U_EvrAxi : entity work.EvrV2Axi
    generic map ( TPD_G      => TPD_G,
                  CHANNELS_C => NCHANNELS_G )
    port map (    axiClk              => evrClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => mAxiWriteMasters (CSR_INDEX_C),
                  axilWriteSlave      => mAxiWriteSlaves  (CSR_INDEX_C),
                  axilReadMaster      => mAxiReadMasters  (CSR_INDEX_C),
                  axilReadSlave       => mAxiReadSlaves   (CSR_INDEX_C),
                  -- configuration
                  channelConfig       => channelConfig,
                  -- status
                  rstCount            => rstCount,
                  eventCount          => eventCount );

  U_EvrTrigReg : entity work.EvrV2TrigReg
    generic map ( TPD_G      => TPD_G,
                  TRIGGERS_C => NTRIGGERS_G )
    port map (    axiClk              => evrClk,
                  axiRst              => axiRst,
                  axilWriteMaster     => mAxiWriteMasters (TRG_INDEX_C),
                  axilWriteSlave      => mAxiWriteSlaves  (TRG_INDEX_C),
                  axilReadMaster      => mAxiReadMasters  (TRG_INDEX_C),
                  axilReadSlave       => mAxiReadSlaves   (TRG_INDEX_C),
                  -- configuration
                  triggerConfig       => triggerConfig );

end mapping;
