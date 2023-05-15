-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2020-07-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: EvrCard Sim Top Level
-- 
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 DAQ Software'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 DAQ Software', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.TPGMiniEdefPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use lcls_timing_core.TPGPkg.all;
use lcls_timing_core.EvrV2Pkg.all;
use l2si_core.XpmPkg.all;
use l2si_core.XpmMiniPkg.all;

library xil_defaultlib;
use xil_defaultlib.SsiPciePkg.all;
use xil_defaultlib.AxiLiteSimPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EvrCardG2Sim is
end EvrCardG2Sim;

architecture top_level_app of EvrCardG2Sim is

  signal axilClk         : sl;
  signal axilRst         : sl;
  signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
  signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
  signal axilReadSlave   : AxiLiteReadSlaveType;
  signal axilWriteSlave  : AxiLiteWriteSlaveType;

  constant NUM_AXI_MASTERS_C  : natural := 2;
  constant CSR_INDEX_C        : natural := 0;
  constant TPR_INDEX_C        : natural := 1;

  constant AXI_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    CSR_INDEX_C      => (
      baseAddr      => x"00060000",
      addrBits      => 16,
      connectivity  => X"0001"),
    TPR_INDEX_C => (
      baseAddr      => x"00080000",
      addrBits      => 18,
      connectivity  => X"0001") );

  signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
  signal mAxiReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);
  
  signal evrClk   : sl;
  signal evrRst   : sl;
  signal evrBus   : TimingBusType := TIMING_BUS_INIT_C;
--  signal exptBus  : ExptBusType   := EXPT_BUS_INIT_C;

  signal trigOut  : slv(11 downto 0);
  
  signal axiClk          : sl;
  signal axiRst          : sl;

  signal axilDone : sl := '0';
  signal tstrobe  : sl := '0';
  signal rst      : sl := '1';

  signal axiValid     : sl := '1';
  signal axiMatch     : sl := '0';

  signal dmaIbMaster : AxiStreamMasterType;
  signal dmaIbSlave  : AxiStreamSlaveType := AXI_STREAM_SLAVE_FORCE_C;
  signal dmaRxTran   : TranFromPcieType := TRAN_FROM_PCIE_INIT_C;

  signal xData     : TimingRxType := TIMING_RX_INIT_C;
  signal xPhy      : TimingPhyType;
  signal tpgConfig : TPGConfigType := TPG_CONFIG_INIT_C;
  signal tpgStream   : TimingSerialType;
  signal tpgAdvance  : sl;
  signal tpgFiducial : sl;

  signal xpmConfig   : XpmMiniConfigType := XPM_MINI_CONFIG_INIT_C;
  signal xpmStream   : XpmStreamType := XPM_STREAM_INIT_C;

  signal evgTx       : TimingRxType := TIMING_RX_INIT_C;

  constant GEN_LCLS1_C : boolean := true;

  constant EVR_HALF_PERIOD : time := ite(GEN_LCLS1_C, 4.2 ns, 2.7 ns);

  function axiLiteWriteConfig return AxiLiteWriteCmdArray is
    variable v : AxiLiteWriteCmdArray(4*ReadoutChannels+7 downto 0);
    variable a : slv(31 downto 0);
    variable k : integer := 0;
  begin
    v(0) := (x"00060000", x"00000001");  -- irq_enable
    v(1) := (x"00060018", toSlv(16,32)); -- dma_full_threshold
    k := 2;
    for i in 0 to ReadoutChannels-1 loop
      if GEN_LCLS1_C then
        v(k) := (x"00080004"+4096*i, x"40001028");
      else
        v(k) := (x"00080004"+4096*i, x"40000000");
      end if;
      k := k+1;
      if i>2 then
        v(k) := (x"0008000C"+4096*i, toSlv(0,32));
      else
        v(k) := (x"0008000C"+4096*i, toSlv(2-i,12) & toSlv(0,20));
      end if;
      k := k+1;
      v(k) := (x"00080010"+4096*i, x"00000001");
      k := k+1;
    end loop;
    v(k) := (x"000a0000", x"80010001");  -- enable
    k := k+1;
    v(k) := (x"000a0004", x"00000C01");  -- delay
    k := k+1;
    v(k) := (x"000a0008", x"00000004");  -- width
    k := k+1;
    v(k) := (x"000a1000", x"90010002");  -- enable + complEn,OR
    k := k+1;
    v(k) := (x"000a1004", x"00000003");  -- delay
    k := k+1;
    v(k) := (x"000a1008", x"00000004");  -- width
    k := k+1;
    for i in 0 to ReadoutChannels-1 loop
      if i > 10 then
        a := toSlv(7,32);
      else
        a := toSlv(7,32);
      end if;
      v(k) := (x"00080000"+4096*i, a); -- enable + bsa + dma
      k := k+1;
    end loop;
    return v;
  end axiLiteWriteConfig;
begin

  process is
  begin
    axilClk <= '1';
    wait for 4.0 ns;
    axilClk <= '0';
    wait for 4.0 ns;
  end process;

  process is
  begin
    axiClk <= '1';
    wait for 2.5 ns;
    axiClk <= '0';
    wait for 2.5 ns;
  end process;

  process is
  begin
    evrClk <= '1';
    wait for EVR_HALF_PERIOD;
    evrClk <= '0';
    wait for EVR_HALF_PERIOD;
  end process;

  process is
  begin
    wait for 20 ns;
    rst <= '0';
    wait;
  end process;
  
  axilRst <= rst;
  axiRst  <= rst;
  evrRst  <= rst;

  process is
  begin
    wait until axilDone = '1';
    wait for 100 ns;
    wait until axilClk='0';
    tpgConfig.bsadefv(0).nToAvg  <= toSlv(1,13);
    tpgConfig.bsadefv(0).avgToWr <= toSlv(160,16);
    tpgConfig.bsadefv(0).init    <= '0';
    wait until axilClk='1';
    wait until axilClk='0';
    tpgConfig.bsadefv(0).rateSel <= toSlv(0,13);
    tpgConfig.bsadefv(0).destSel <= "010" & x"0000";
    tpgConfig.bsadefv(0).init    <= '1';
    wait;
  end process;

  GEN_LCLS1 : if GEN_LCLS1_C generate
    U_TPGS : entity lcls_timing_core.TPGMiniStream
      generic map (
        NUM_EDEFS      => 1,
        AC_PERIOD      => 20*1666 )
      port map (
        -- Register Interface
        config         => tpgConfig,
        edefConfig     => TPG_MINI_EDEF_CONFIG_INIT_C,

        txClk          => evrClk,
        txRst          => evrRst,
        txRdy          => '1',
        txData         => evgTx.data,
        txDataK        => evgTx.dataK );

    U_TPGSRx : entity lcls_timing_core.TimingStreamRx
      port map (
        rxClk               => evrClk,
        rxRst               => evrRst,
        rxData              => evgTx,
        timingMessageUser   => evrBus.stream,
        timingMessageStrobe => evrBus.strobe,
        timingMessageValid  => evrBus.valid );

    evrBus.modesel <= '0';
  end generate;

  GEN_LCLS2 : if not GEN_LCLS1_C generate
    xpmConfig.partition.l0Select.enabled <= '1';
    xpmConfig.partition.l0Select.rateSel <= toSlv(0,16);
    xpmConfig.partition.l0Select.destSel <= x"8000";
  
    U_TPG : entity lcls_timing_core.TPGMini
      generic map (
        NARRAYSBSA     => 1,
        STREAM_INTF    => true )
      port map (
        -- Register Interface
        statusO        => open,
        configI        => tpgConfig,
        -- TPG Interface
        txClk          => evrClk,
        txRst          => evrRst,
        txRdy          => '1',
        streams    (0) => tpgStream,
        advance    (0) => tpgAdvance,
        fiducial       => tpgFiducial );

    xpmStream.fiducial   <= tpgFiducial;
    xpmStream.advance(0) <= tpgAdvance;
    xpmStream.streams(0) <= tpgStream;

    --  This doesn't xil_defaultlib!
    --  tpgAdvance <= tpgStream.ready;
    --
    --  Use a TimingSerializer to generate advance signal
    --
    U_TS : entity lcls_timing_core.TimingSerializer
      port map ( clk          => evrClk,
                 rst          => evrRst,
                 fiducial     => tpgFiducial,
                 streams  (0) => tpgStream,
                 streamIds(0) => x"0",
                 advance  (0) => tpgAdvance );
    

    U_Xpm : entity l2si_core.XpmMini
      generic map ( NUM_DS_LINKS_G => 1 )
      port map ( regclk       => axilClk,
                 regrst       => axilRst,
                 update       => '0',
                 config       => xpmConfig,
                 status       => open,
                 dsRxClk  (0) => evrClk,
                 dsRxRst  (0) => evrRst,
                 dsRx     (0) => TIMING_RX_INIT_C,
                 dsTx     (0) => xPhy,
                 timingClk    => evrClk,
                 timingRst    => evrRst,
                 timingStream => xpmStream );

    xData.data  <= xPhy.data;
    xData.dataK <= xPhy.dataK;
    
    U_TPR : entity lcls_timing_core.TimingFrameRx
      port map ( rxClk               => evrClk,
                 rxRst               => evrRst,
                 rxData              => xData,
                 messageDelay        => (others=>'0'),
                 messageDelayRst     => '0',
                 timingMessage       => evrBus.message,
                 timingMessageStrobe => evrBus.strobe,
                 timingMessageValid  => evrBus.valid,
                 timingExtension     => evrBus.extension,
                 rxVersion           => open,
                 staData             => open );

    evrBus.modesel <= '1';
  end generate;
                      
  U_DUT : entity xil_defaultlib.EvrV2Core
    generic map ( AXIL_BASEADDR0 => AXI_MASTERS_CONFIG_C(CSR_INDEX_C).baseAddr,
                  AXIL_BASEADDR1 => AXI_MASTERS_CONFIG_C(TPR_INDEX_C).baseAddr )
    port map ( axiClk              => axilClk,
               axiRst              => axilRst,
               axilWriteMaster     => mAxiWriteMasters,
               axilWriteSlave      => mAxiWriteSlaves ,
               axilReadMaster      => mAxiReadMasters ,
               axilReadSlave       => mAxiReadSlaves  ,
               irqActive           => '1',
               irqEnable           => open,
               irqReq              => open,
               -- DMA
               dmaRxIbMaster       => dmaIbMaster,
               dmaRxIbSlave        => dmaIbSlave,
               dmaRxTranFromPci    => TRAN_FROM_PCIE_INIT_C,
               dmaReady            => open,
               -- EVR Ports
               evrClk              => evrClk,
               evrRst              => evrRst,
               evrBus              => evrBus,
               gtxDebug            => x"00",
               -- Trigger and Sync Port
               syncL               => '1',
               trigOut             => trigOut,
               evrModeSel          => evrBus.modesel,
               delay_ld            => open,
               delay_wr            => open,
               delay_rd            => (others=>"000000") );

  --U_MOD : entity lcls_timing_core.EvrV2Module
  --  generic map ( AXIL_BASEADDR => AXI_MASTERS_CONFIG_C(MODU_INDEX_C).baseAddr,
  --                NTRIGGERS_G   => 2 )
  --  port map ( axiClk              => axilClk,
  --             axiRst              => axilRst,
  --             axilWriteMaster     => mAxiWriteMasters(MODU_INDEX_C),
  --             axilWriteSlave      => mAxiWriteSlaves (MODU_INDEX_C),
  --             axilReadMaster      => mAxiReadMasters (MODU_INDEX_C),
  --             axilReadSlave       => mAxiReadSlaves  (MODU_INDEX_C),
  --             -- EVR Ports
  --             evrClk              => evrClk,
  --             evrRst              => evrRst,
  --             evrBus              => evrBus,
  --             exptBus             => EXPT_BUS_INIT_C,
  --             -- Trigger and Sync Port
  --             trigOut             => open,
  --             evrModeSel          => '1' );

  U_AxiXbar : entity surf.AxiLiteCrossbar
    generic map ( NUM_SLAVE_SLOTS_G  => 1,
                  NUM_MASTER_SLOTS_G => 2,
                  MASTERS_CONFIG_G   => AXI_MASTERS_CONFIG_C )
    port map ( axiClk              => axilClk,
               axiClkRst           => axilRst,
               sAxiWriteMasters(0) => axilWriteMaster,
               sAxiWriteSlaves (0) => axilWriteSlave,
               sAxiReadMasters (0) => axilReadMaster,
               sAxiReadSlaves  (0) => axilReadSlave,
               mAxiWriteMasters    => mAxiWriteMasters,
               mAxiWriteSlaves     => mAxiWriteSlaves,
               mAxiReadMasters     => mAxiReadMasters,
               mAxiReadSlaves      => mAxiReadSlaves );

  U_AxiLite : entity xil_defaultlib.AxiLiteWriteMasterSim
    generic map ( CMDS => axiLiteWriteConfig )
    port map ( clk    => axilClk,
               rst    => axilRst,
               master => axilWriteMaster,
               slave  => axilWriteSlave,
               done   => axilDone );

end top_level_app;
