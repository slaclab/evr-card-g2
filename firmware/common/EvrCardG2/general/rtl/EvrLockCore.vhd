-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrLockCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2023-08-20
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use work.SsiPciePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.TPGMiniEDefPkg.all;
use lcls_timing_core.TPGPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EvrLockCore is
   generic (
      TPD_G : time := 1 ns;
      BUILD_INFO_G : BuildInfoType ); 
   port (
      -- XADC Ports
      vPIn       : in    sl;
      vNIn       : in    sl;
      -- Boot Memory Ports
      flashData  : inout slv(15 downto 0);
      flashAddr  : out   slv(23 downto 0);
      -- flashRs    : inout slv(1 downto 0);
      flashCe    : out   sl;
      flashOe    : out   sl;
      flashWe    : out   sl;
      flashAdv   : out   sl;
      flashWait  : in    sl;
      promVersion: in    sl;
      -- Crossbar Ports
      xBarSin    : out   slv(1 downto 0);
      xBarSout   : out   slv(1 downto 0);
      xBarConfig : out   sl;
      xBarLoad   : out   sl;
      -- PCIe Ports
      pciRstL    : in    sl;
      pciRefClkP : in    sl;
      pciRefClkN : in    sl;
      pciRxP     : in    slv(3 downto 0);
      pciRxN     : in    slv(3 downto 0);
      pciTxP     : out   slv(3 downto 0);
      pciTxN     : out   slv(3 downto 0);
      -- EVR Ports
      evrRefClkP : in    slv(1 downto 0);
      evrRefClkN : in    slv(1 downto 0);
      evrRxP     : in    slv(1 downto 0);
      evrRxN     : in    slv(1 downto 0);
      evrTxP     : out   slv(1 downto 0);
      evrTxN     : out   slv(1 downto 0);
      -- Trigger and Sync Port
      syncL      : in    sl;
      trigOut    : out   slv(11 downto 0);
      -- Misc.
      debugIn    : in    slv(11 downto 0);
      ledRedL    : out   slv(1 downto 0);
      ledGreenL  : out   slv(1 downto 0);
      ledBlueL   : out   slv(1 downto 0);
      testPoint  : out   sl);  
end EvrLockCore;

architecture mapping of EvrLockCore is

   -- Constants
   constant BAR_SIZE_C : positive := 1;
   constant DMA_SIZE_C : positive := 1;
   constant AXI_CLK_FREQ_C : real := 125.0e6;
   
   -- AXI-Lite Signals
   signal axiLiteWriteMaster : AxiLiteWriteMasterArray(BAR_SIZE_C-1 downto 0);
   signal axiLiteWriteSlave  : AxiLiteWriteSlaveArray (BAR_SIZE_C-1 downto 0);
   signal axiLiteReadMaster  : AxiLiteReadMasterArray (BAR_SIZE_C-1 downto 0);
   signal axiLiteReadSlave   : AxiLiteReadSlaveArray  (BAR_SIZE_C-1 downto 0);

   constant NUM_AXI_MASTERS_C : natural := 8;

   constant VERSION_INDEX_C  : natural := 0;
   constant BOOT_MEM_INDEX_C : natural := 1;
   constant XADC_INDEX_C     : natural := 2;
   constant XBAR_INDEX_C     : natural := 3;
   constant LED_INDEX_C      : natural := 4;
   constant APP_INDEX_C      : natural := 5;
   constant CORE_INDEX_C     : natural := 6;
   constant CORE_INDEX2_C    : natural := 7;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      VERSION_INDEX_C  => (
         baseAddr      => x"00010000",
         addrBits      => 16,
         connectivity  => X"0001"),
      BOOT_MEM_INDEX_C => (
         baseAddr      => X"00020000",
         addrBits      => 16,
         connectivity  => X"0001"),
      XADC_INDEX_C     => (
         baseAddr      => X"00030000",
         addrBits      => 16,
         connectivity  => X"0001"),
      XBAR_INDEX_C     => (
         baseAddr      => X"00040000",
         addrBits      => 16,
         connectivity  => X"0001"),
      LED_INDEX_C      => (
         baseAddr      => X"00050000",
         addrBits      => 16,
         connectivity  => X"0001"),
      APP_INDEX_C      => (
         baseAddr      => X"00060000",
         addrBits      => 16,
         connectivity  => X"0001"),
      CORE_INDEX_C     => (
         baseAddr      => X"00080000",
         addrBits      => 18,
         connectivity  => X"0001"),
      CORE_INDEX2_C    => (
         baseAddr      => X"000C0000",
         addrBits      => 18,
         connectivity  => X"0001"));

   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);
   
   -- DMA Signals      
   signal dmaTxTranFromPci : TranFromPcieArray(DMA_SIZE_C-1 downto 0)    := (others => TRAN_FROM_PCIE_INIT_C);
   signal dmaRxTranFromPci : TranFromPcieArray(DMA_SIZE_C-1 downto 0)    := (others => TRAN_FROM_PCIE_INIT_C);
   signal dmaTxObMasters   : AxiStreamMasterArray(DMA_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal dmaTxObSlaves    : AxiStreamSlaveArray(DMA_SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal dmaTxIbMasters   : AxiStreamMasterArray(DMA_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal dmaTxIbSlaves    : AxiStreamSlaveArray(DMA_SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal dmaRxIbMasters   : AxiStreamMasterArray(DMA_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal dmaRxIbSlaves    : AxiStreamSlaveArray(DMA_SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   constant XBAR_DEFAULT_C : Slv2Array(3 downto 0) := (
     3 => "01",                        -- OUT[3] = IN[1]
     2 => "00",                        -- OUT[2] = IN[0]
     1 => "01",                        -- OUT[1] = IN[1]
     0 => "00");                       -- OUT[0] = IN[0]   


   --  GTX Signals
   signal evrClk      : slv(1 downto 0);
   signal evrRst      : slv(1 downto 0);
   signal evrTxClk    : slv(1 downto 0);
   signal evrTxRst    : slv(1 downto 0);
   signal rxLinkUp    : slv(1 downto 0);
   signal rxError     : slv(1 downto 0);
   signal loopback    : Slv3Array (1 downto 0);
   signal rxDecErr    : Slv2Array (1 downto 0);
   signal rxDspErr    : Slv2Array (1 downto 0);
   signal rxDataK     : Slv2Array (1 downto 0);
   signal rxData      : Slv16Array(1 downto 0);
   signal txDataK     : Slv2Array (1 downto 0);
   signal txData      : Slv16Array(1 downto 0);

   signal rxControl   : TimingPhyControlArray(1 downto 0);
   signal rxStatus    : TimingPhyStatusArray (1 downto 0) := (others=>TIMING_PHY_STATUS_INIT_C);
   signal axiClk       : sl;
   signal axiRst       : sl;
   signal pciLinkUp    : sl;
   signal cardRst      : sl;
   signal irqActive    : sl;
   signal irqEnable    : slv(BAR_SIZE_C-1 downto 0);
   signal irqReq       : slv(BAR_SIZE_C-1 downto 0);
   signal trig         : slv(11 downto 0);
   signal serialNumber : slv(127 downto 0);

   signal ncTrigDelay  : slv(19 downto 0);
   signal heartBeat    : slv(1 downto 0);
   signal appTimingBus : TimingBusArray(1 downto 0);
   signal dmaReady     : sl;

   signal urxLinkUp    : sl;
   signal urxError     : sl;
   signal uhbeat       : sl;
   
   signal userValues : Slv32Array(0 to 63) := (others => x"00000000");

   signal tpgConfig : TpgConfigType := TPG_CONFIG_INIT_C;
   signal fiducial0 : sl;

   signal mmcmClk, mmcmRst : slv(2 downto 0);
   signal lockedLoc, clockLoc, clkFb : sl;
   signal psclk, psen, psincdec : sl;
   signal itxClk, itxRst : slv(1 downto 0);

   signal irxClk, irxRst : slv (1 downto 0);
   signal irxData   : Slv16Array(1 downto 0);
   signal irxDataK  : Slv2Array (1 downto 0);
   signal irxDspErr : Slv2Array (1 downto 0);
   signal irxDecErr : Slv2Array (1 downto 0);
   signal irxStatus : TimingPhyStatusArray (1 downto 0) := (others=>TIMING_PHY_STATUS_INIT_C);
   -- RX_MODE determines mode for NC Timing only
   -- RX_MODE = "REAL" rxData goes into TimingCore (from GTX)
   -- RX_MODE = "LOOP" txData goes into TimingCore (bypass GTX)
   -- RX_MODE = "SIM"  simulated fiducial is fed directly into phase detector
   constant RX_MODE : string := "REAL";
   signal rx_mode_v : slv(1 downto 0) := "00";
   
begin

  RX_MODE_P : process (rx_mode_v,
                       rxData, rxDataK, txData, txDataK,
                       rxStatus, rxDspErr, rxDecErr) is
  begin
    if rx_mode_v(0) = '0' then
      irxStatus <= rxStatus;
      irxDspErr <= rxDspErr;
      irxDecErr <= rxDecErr;
    else
      irxStatus <= rxStatus(1) & TIMING_PHY_STATUS_FORCE_C;
      irxDspErr <= rxDspErr(1) & "00";
      irxDecErr <= rxDecErr(1) & "00";
    end if;

    --irxData (1) <= rxData (1);
    --irxDataK(1) <= rxDataK(1);
    --if rx_mode_v(1) = '0' then
    --  irxData (0)  <= rxData (0);
    --  irxDataK(0)  <= rxDataK(0);
    --else
    --  irxData (0)  <= txData (0);
    --  irxDataK(0)  <= txDataK(0);
    --end if;
  end process RX_MODE_P;

  --U_IRXCLK0_MUX : entity work.EvrClkMux
  --  generic map ( CLKIN_PERIOD_G => 8.4,
  --                CLK_MULT_F_G   => 6.0 )
  --  port map ( clkSel  => rx_mode_v(1),
  --             clkIn0  => evrClk(0),
  --             clkIn1  => mmcmClk(2),
  --             rstIn0  => evrRst(0),
  --             rstIn1  => mmcmrst(2),
  --             clkOut  => irxClk(0),
  --             rstOut  => irxRst(0) );
  
  --irxClk(1) <= evrClk(1);
  --irxRst(1) <= evrRst(1);
  irxClk   <= evrClk;
  irxRst   <= evrRst;
  irxData  <= rxData;
  irxDataK <= rxDataK;
  
  --U_ITXCLK0_MUX : entity work.EvrClkMux
  --  generic map ( CLKIN_PERIOD_G => 8.4,
  --                CLK_MULT_F_G   => 6.0 )
  --  port map ( clkSel  => rx_mode_v(0),
  --             clkIn0  => evrClk(0),
  --             clkIn1  => mmcmClk(2),
  --             rstIn0  => evrRst(0),
  --             rstIn1  => mmcmrst(2),
  --             clkOut  => itxClk(0),
  --             rstOut  => itxRst(0) );

  --itxClk(1) <= evrTxClk(1);
  --itxRst(1) <= evrTxRst(1);
  itxClk <= evrTxClk;
  itxRst <= evrTxRst;
  
   userValues(0)(0) <= promVersion;
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

   testPoint <= pciLinkUp;

   -----------------  
   -- Trigger Output
   -----------------
   -- diagnostics only
   -----------------
  trigOut <= trig;

  U_Trig : entity work.EvrLockTrig
    port map ( timingClk => irxClk,
               timingRst => irxRst,
               timingBus => appTimingBus,
               ncDelay   => ncTrigDelay,
               trigOut   => trig );
  
   ------------
   -- PCIe Core
   ------------
   PciCore_Inst : entity work.EvrCardG2PciCore
      generic map (
         TPD_G      => TPD_G,
         DMA_SIZE_G => DMA_SIZE_C,
         BAR_SIZE_G => BAR_SIZE_C)
      port map (
         -- System Interface
         irqActive           => irqActive,
         irqEnable           => irqEnable,
         irqReq              => irqReq,
         serialNumber        => serialNumber(63 downto 0),
         cardRst             => cardRst,
         pciLinkUp           => pciLinkUp,
         -- AXI-Lite Interface
         mAxiLiteWriteMaster => axiLiteWriteMaster,
         mAxiLiteWriteSlave  => axiLiteWriteSlave,
         mAxiLiteReadMaster  => axiLiteReadMaster,
         mAxiLiteReadSlave   => axiLiteReadSlave,
         -- DMA Interface
         dmaTxTranFromPci    => dmaTxTranFromPci,
         dmaRxTranFromPci    => dmaRxTranFromPci,
         dmaTxObMasters      => dmaTxObMasters,
         dmaTxObSlaves       => dmaTxObSlaves,
         dmaTxIbMasters      => dmaTxIbMasters,
         dmaTxIbSlaves       => dmaTxIbSlaves,
         dmaRxIbMasters      => dmaRxIbMasters,
         dmaRxIbSlaves       => dmaRxIbSlaves,
         -- Clock and reset
         pciClk              => axiClk,
         pciRst              => axiRst,
         -- PCIe Ports 
         pciRstL             => pciRstL,
         pciRefClkP          => pciRefClkP,
         pciRefClkN          => pciRefClkN,
         pciRxP              => pciRxP,
         pciRxN              => pciRxN,
         pciTxP              => pciTxP,
         pciTxN              => pciTxN);     

    -------------------------
   -- AXI-Lite Crossbar Core
   -------------------------  
   AxiLiteCrossbar_Inst : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
      port map (
         axiClk              => axiClk,
         axiClkRst           => axiRst,
         sAxiWriteMasters    => axiLiteWriteMaster,
         sAxiWriteSlaves     => axiLiteWriteSlave,
         sAxiReadMasters     => axiLiteReadMaster,
         sAxiReadSlaves      => axiLiteReadSlave,
         mAxiWriteMasters    => mAxiWriteMasters,
         mAxiWriteSlaves     => mAxiWriteSlaves,
         mAxiReadMasters     => mAxiReadMasters,
         mAxiReadSlaves      => mAxiReadSlaves);   

   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   AxiVersion_Inst : entity surf.AxiVersion
      generic map (
         TPD_G           => TPD_G,
         BUILD_INFO_G    => BUILD_INFO_G,
         BUFR_CLK_DIV_G  => 4,
         EN_DEVICE_DNA_G => true)   
      port map (
         -- Optional: user values
         userValues     => userValues,
         -- Serial Number outputs
         dnaValueOut    => serialNumber,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMasters(VERSION_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(VERSION_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(VERSION_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(VERSION_INDEX_C),
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);   

   --------------------
   -- Boot Flash Module
   --------------------
   AxiMicronP30Core_Inst : entity work.BpiPromCore
      generic map (
         TPD_G          => TPD_G,
         AXI_CLK_FREQ_G => AXI_CLK_FREQ_C)  -- units of Hz
      port map (
         -- FLASH Interface 
         flashIn.flashWait           => flashWait,
         flashInOut.dq               => flashData,
         flashOut.ceL                => flashCe,
         flashOut.oeL                => flashOe,
         flashOut.weL                => flashWe,
         flashOut.addr(23 downto 0)  => flashAddr,
         flashOut.addr(30 downto 24) => open,
         flashOut.adv                => flashAdv,
         flashOut.clk                => open,
         flashOut.rstL               => open,
         -- AXI-Lite Register Interface
         axiReadMaster               => mAxiReadMasters(BOOT_MEM_INDEX_C),
         axiReadSlave                => mAxiReadSlaves(BOOT_MEM_INDEX_C),
         axiWriteMaster              => mAxiWriteMasters(BOOT_MEM_INDEX_C),
         axiWriteSlave               => mAxiWriteSlaves(BOOT_MEM_INDEX_C),
         -- Clocks and Resets
         axiClk                      => axiClk,
         axiRst                      => axiRst);  

   -----------------------
   -- AXI-Lite XADC Module
   -----------------------
   --AxiXadcMinimumCore_Inst : entity surf.AxiXadcMinimumCore
   --   generic map (
   --      TPD_G => TPD_G) 
   --   port map (
   --      -- XADC Ports
   --      vPIn           => vPIn,
   --      vNIn           => vNIn,
   --      -- AXI-Lite Register Interface
   --      axiReadMaster  => mAxiReadMasters(XADC_INDEX_C),
   --      axiReadSlave   => mAxiReadSlaves(XADC_INDEX_C),
   --      axiWriteMaster => mAxiWriteMasters(XADC_INDEX_C),
   --      axiWriteSlave  => mAxiWriteSlaves(XADC_INDEX_C),
   --      -- Clocks and Resets
   --      axiClk         => axiClk,
   --      axiRst         => axiRst);
   U_JtagBridge : entity work.JtagBridgeWrapper
     port map ( axilClk            => axiClk,
                axilRst            => axiRst,
                axilReadMaster     => mAxiReadMasters (XADC_INDEX_C),
                axilReadSlave      => mAxiReadSlaves  (XADC_INDEX_C),
                axilWriteMaster    => mAxiWriteMasters(XADC_INDEX_C),
                axilWriteSlave     => mAxiWriteSlaves (XADC_INDEX_C) );

   ---------------------------------------------------------
   -- AXI-Lite LCLS-I & LCLS-II Timing Clock Crossbar Module
   ---------------------------------------------------------
   AxiSy56040Reg_Inst : entity surf.AxiSy56040Reg
      generic map (
         TPD_G          => TPD_G,
         AXI_CLK_FREQ_G => AXI_CLK_FREQ_C,
         XBAR_DEFAULT_G => XBAR_DEFAULT_C) 
      port map (
         -- XBAR Ports 
         xBarSin        => xBarSin,
         xBarSout       => xBarSout,
         xBarConfig     => xBarConfig,
         xBarLoad       => xBarLoad,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMasters(XBAR_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(XBAR_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(XBAR_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(XBAR_INDEX_C),
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);    

   --------------
   -- GTX7 Module
   --------------
   GEN_GTX : for i in 0 to 1 generate
     U_Gtx : entity work.EvrCardG2Gtx
       generic map ( EVR_VERSION_G => i>0 )
       port map ( evrRefClkP => evrRefClkP(i),
                  evrRefClkN => evrRefClkN(i),
                  evrRxP     => evrRxP(i),
                  evrRxN     => evrRxN(i),
                  evrTxP     => evrTxP(i),
                  evrTxN     => evrTxN(i),
                  evrRefClk  => open,
                  evrRecClk  => open,
                  -- EVR Interface
                  rxReset    => rxControl(i).reset,
                  rxPolarity => rxControl(i).polarity,
                  evrClk     => evrClk   (i),
                  evrRst     => evrRst   (i),
                  rxLinkUp   => rxLinkUp (i),
                  rxError    => rxError  (i),
                  rxDspErr   => rxDspErr (i),
                  rxDecErr   => rxDecErr (i),
                  rxData     => rxData   (i),
                  rxDataK    => rxDataK  (i),
                  evrTxClk   => evrTxClk (i),
                  evrTxRst   => evrTxRst (i),
                  loopback   => loopback (i),
                  txInhibit  => '0',
                  txData     => txData   (i),
                  txDataK    => txDataK  (i) );
     rxStatus(i).locked       <= rxLinkUp(i);
     rxStatus(i).resetDone    <= rxLinkUp(i);
   end generate;

   urxLinkUp <= uAnd(rxLinkUp);
   urxError  <= uOr (rxError);
   uhbeat    <= uOr (heartbeat);
   
   -----------------         
   -- EVR LED Status
   -----------------         
   U_LEDs : entity work.EvrCardG2LedRgb
      generic map (
         TPD_G => TPD_G)
      port map (
         -- EVR Interface
         evrClk          => evrClk(0),
         evrRst          => evrRst(0),
         rxLinkUp        => urxLinkUp,
         rxError         => urxError,
         strobe          => uhbeat,
         -- AXI-Lite and IRQ Interface
         axilClk         => axiClk,
         axilRst         => axiRst,
         axilReadMaster  => mAxiReadMasters (LED_INDEX_C),
         axilReadSlave   => mAxiReadSlaves  (LED_INDEX_C),
         axilWriteMaster => mAxiWriteMasters(LED_INDEX_C),
         axilWriteSlave  => mAxiWriteSlaves (LED_INDEX_C),
         -- LEDs
         ledRedL         => ledRedL  (0),
         ledGreenL       => ledGreenL(0),
         ledBlueL        => ledBlueL (0));           

   ------------------------------------------------------------------------------------------------
   -- Timing Core
   -- Decode timing message from GTX and distribute to system
   ------------------------------------------------------------------------------------------------
   GEN_TIMING_BUS : for i in 1 downto 0 generate
     TimingCore_1: entity lcls_timing_core.TimingCore
       generic map (
         TPD_G             => TPD_G,
         CLKSEL_MODE_G     => ite(i>0, "LCLSII", "LCLSI"),
         TPGEN_G           => false,
         USE_TPGMINI_G     => false,
         AXIL_RINGB_G      => false,
         ASYNC_G           => false,
         AXIL_BASE_ADDR_G  => AXI_CROSSBAR_MASTERS_CONFIG_C(CORE_INDEX_C+i).baseAddr )
       port map (
         gtTxUsrClk      => evrTxClk (i),
         gtTxUsrRst      => evrTxRst (i),
         gtRxRecClk      => irxClk   (i),
         gtRxData        => irxData  (i),
         gtRxDataK       => irxDataK (i),
         gtRxDispErr     => irxDspErr(i),
         gtRxDecErr      => irxDecErr(i),
         gtRxControl     => rxControl(i),
         gtRxStatus      => irxStatus(i),
         gtTxReset       => open,
         gtLoopback      => open,
         tpgMiniTimingPhy => open,
         timingClkSel    => open,
         --
         appTimingClk    => irxClk      (i),
         appTimingRst    => irxRst      (i),
         appTimingBus    => appTimingBus(i),
         appTimingMode   => open,
         --
         axilClk         => axiClk,
         axilRst         => axiRst,
         axilReadMaster  => mAxiReadMasters (CORE_INDEX_C+i),
         axilReadSlave   => mAxiReadSlaves  (CORE_INDEX_C+i),
         axilWriteMaster => mAxiWriteMasters(CORE_INDEX_C+i),
         axilWriteSlave  => mAxiWriteSlaves (CORE_INDEX_C+i));
   end generate;

   heartBeat(1) <= appTimingBus(1).message.fixedRates(0) and appTimingBus(1).strobe;
   heartBeat(0) <= appTimingBus(0).stream.eventCodes(45) and appTimingBus(0).strobe;

   --
   --  Simulate a locked NC timing stream
   --
   U_130M : entity surf.ClockManager7
     generic map ( NUM_CLOCKS_G => 1,
                   CLKIN_PERIOD_G => 5.4,
                   CLKFBOUT_MULT_F_G => 3.5,
                   CLKOUT0_DIVIDE_F_G => 5.0 )
     port map ( clkIn     => evrTxClk(1),
                rstIn     => evrTxRst(1),
                clkOut(0) => mmcmClk(0),
                rstOut(0) => mmcmRst(0) );
   
   U_70M : entity surf.ClockManager7
     generic map ( NUM_CLOCKS_G => 1,
                   CLKIN_PERIOD_G => 7.7,
                   CLKFBOUT_MULT_F_G => 7.0,
                   CLKOUT0_DIVIDE_F_G => 13.0 )
     port map ( clkIn     => mmcmClk(0),
                rstIn     => mmcmRst(0),
                clkOut(0) => mmcmClk(1),
                rstOut(0) => mmcmRst(1) );
   
   U_119M : MMCME2_ADV
     generic map ( BANDWIDTH          => "OPTIMIZED",
                   CLKOUT4_CASCADE    => false,
                   STARTUP_WAIT       => false,
                   CLKIN1_PERIOD      => 14.3,
                   DIVCLK_DIVIDE      => 1,
                   CLKFBOUT_MULT_F    => 17.0,
                   CLKOUT0_DIVIDE_F   => 10.0,
                   CLKOUT1_DIVIDE     => 1,
                   CLKOUT2_DIVIDE     => 1,
                   CLKOUT3_DIVIDE     => 1,
                   CLKOUT4_DIVIDE     => 1,
                   CLKOUT5_DIVIDE     => 1,
                   CLKOUT6_DIVIDE     => 1,
                   CLKOUT0_PHASE      => 0.0,
                   CLKOUT1_PHASE      => 0.0,
                   CLKOUT2_PHASE      => 0.0,
                   CLKOUT3_PHASE      => 0.0,
                   CLKOUT4_PHASE      => 0.0,
                   CLKOUT5_PHASE      => 0.0,
                   CLKOUT6_PHASE      => 0.0,
                   CLKOUT0_DUTY_CYCLE => 0.5,
                   CLKOUT1_DUTY_CYCLE => 0.5,
                   CLKOUT2_DUTY_CYCLE => 0.5,
                   CLKOUT3_DUTY_CYCLE => 0.5,
                   CLKOUT4_DUTY_CYCLE => 0.5,
                   CLKOUT5_DUTY_CYCLE => 0.5,
                   CLKOUT6_DUTY_CYCLE => 0.5,
                   CLKOUT0_USE_FINE_PS=> true)
     port map (
            DCLK     => axiClk,
            DRDY     => open,
            DEN      => '0',
            DWE      => '0',
            DADDR    => (others=>'0'),
            DI       => (others=>'0'),
            DO       => open,
            PSCLK    => psclk,
            PSEN     => psen,
            PSINCDEC => psincdec,
            PWRDWN   => '0',
            RST      => mmcmRst(1),
            CLKIN1   => mmcmClk(1),
            CLKIN2   => '0',
            CLKINSEL => '1',
            CLKFBOUT => clkFb,
            CLKFBIN  => clkFb,
            LOCKED   => lockedLoc,
            CLKOUT0  => clockLoc,
            CLKOUT1  => open,
            CLKOUT2  => open,
            CLKOUT3  => open,
            CLKOUT4  => open,
            CLKOUT5  => open,
            CLKOUT6  => open);

   U_119M_BUFG : BUFG
     port map ( I => clockLoc,
                O => mmcmClk(2) );

   U_119M_RST : entity surf.RstSync
     generic map ( IN_POLARITY_G => '0',
                   OUT_POLARITY_G => '1',
                   BYPASS_SYNC_G  => false,
                   RELEASE_DELAY_G => 3 )
     port map ( clk      => mmcmClk(2),
                asyncRst => lockedLoc,
                syncRst  => mmcmRst(2) );
   
   U_EVG : entity lcls_timing_core.TPGMiniStream
     port map (
       config     => TPG_CONFIG_INIT_C,
       edefConfig => TPG_MINI_EDEF_CONFIG_INIT_C,
       txClk      => itxClk(0),
       txRst      => itxRst(0),
       txRdy      => '1',
       txData     => txData(0),
       txDataK    => txDataK(0),
       simStrobe  => fiducial0 );

   --
   --  Simulate the SC Timing stream
   --
   U_TPG : entity lcls_timing_core.TPGMini
     port map (
       statusO    => open,
       configI    => tpgConfig,
       txClk      => itxClk(1),
       txRst      => itxRst(1),
       txRdy      => '1',
       txData     => txData(1),
       txDataK    => txDataK(1) );
     
   U_App : entity work.EvrLockApp
     port map (
         timingClk       => irxClk,
         timingRst       => irxRst,
         timingBus       => appTimingBus,

         txClk0          => itxClk(0),
         txRst0          => itxRst(0),
         fiducial0       => fiducial0,
         txData          => txData,
         txDataK         => txDataK,

         loopback        => loopback,
         nctrigdelay     => ncTrigDelay,
         psclk           => psclk,
         psen            => psen,
         psincdec        => psincdec,
--         rxmode          => rx_mode_v,
       
         axilClk         => axiClk,
         axilRst         => axiRst,
         axilReadMaster  => mAxiReadMasters (APP_INDEX_C),
         axilReadSlave   => mAxiReadSlaves  (APP_INDEX_C),
         axilWriteMaster => mAxiWriteMasters(APP_INDEX_C),
         axilWriteSlave  => mAxiWriteSlaves (APP_INDEX_C));
   
end mapping;
