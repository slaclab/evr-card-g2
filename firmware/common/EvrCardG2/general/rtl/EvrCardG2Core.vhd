-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2022-04-01
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

library l2si_core;

entity EvrCardG2Core is
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
end EvrCardG2Core;

architecture mapping of EvrCardG2Core is

   -- Constants
   constant BAR_SIZE_C : positive := 1;
   constant DMA_SIZE_C : positive := 1;
   constant AXI_CLK_FREQ_C : real := 125.0e6;
   
   -- AXI-Lite Signals
   signal axiLiteWriteMaster : AxiLiteWriteMasterArray(BAR_SIZE_C-1 downto 0);
   signal axiLiteWriteSlave  : AxiLiteWriteSlaveArray (BAR_SIZE_C-1 downto 0);
   signal axiLiteReadMaster  : AxiLiteReadMasterArray (BAR_SIZE_C-1 downto 0);
   signal axiLiteReadSlave   : AxiLiteReadSlaveArray  (BAR_SIZE_C-1 downto 0);

   constant NUM_AXI_MASTERS_C : natural := 10;

   constant VERSION_INDEX_C  : natural := 0;
   constant BOOT_MEM_INDEX_C : natural := 1;
   constant XADC_INDEX_C     : natural := 2;
   constant XBAR_INDEX_C     : natural := 3;
   constant LED_INDEX_C      : natural := 4;
   constant CSR_INDEX_C      : natural := 5;
   constant TPR_INDEX_C      : natural := 6;
   constant CORE_INDEX_C     : natural := 7;
   constant DRP_INDEX_C      : natural := 8;
   constant MMCM_INDEX_C     : natural := 9;

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
      CSR_INDEX_C      => (
         baseAddr      => X"00060000",
         addrBits      => 16,
         connectivity  => X"0001"),
      TPR_INDEX_C     => (
         baseAddr      => X"00080000",
         addrBits      => 18,
         connectivity  => X"0001"),
      CORE_INDEX_C     => (
         baseAddr      => X"000C0000",
         addrBits      => 18,
         connectivity  => X"0001"),
      DRP_INDEX_C      => (
         baseAddr      => X"00070000",
         addrBits      => 15,
         connectivity  => X"0001"),
      MMCM_INDEX_C      => (
         baseAddr      => X"00078000",
         addrBits      => 15,
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
   signal evrClk      : sl;
   signal evrRst      : sl;
   signal rxLinkUp    : sl;
   signal rxError     : sl;
   signal rxDspErr    : slv(1 downto 0);
   signal rxDecErr    : slv(1 downto 0);
   signal rxDataK     : slv(1 downto 0);
   signal rxData      : slv(15 downto 0);

   signal rxControl   : TimingPhyControlType;
   signal rxStatus    : TimingPhyStatusType := TIMING_PHY_STATUS_INIT_C;
   signal txPhy       : TimingPhyType;
   signal txPhyId     : slv(31 downto 0) := x"f6000000";
   signal txPhyClk    : sl;
   signal txPhyRst    : sl;
   
   signal axiClk       : sl;
   signal axiRst       : sl;
   signal pciLinkUp    : sl;
   signal cardRst      : sl;
   signal irqActive    : sl;
   signal irqEnable    : slv(BAR_SIZE_C-1 downto 0);
   signal irqReq       : slv(BAR_SIZE_C-1 downto 0);
   signal trig         : slv(11 downto 0);
   signal delay_wr     : Slv6Array(11 downto 0);
   signal delay_rd     : Slv6Array(11 downto 0);
   signal delay_ld     : slv      (11 downto 0);
   signal serialNumber : slv(127 downto 0);
   signal evrRecClk    : sl;
   signal evrClkSel    : sl;

   signal heartBeat    : sl;
   signal appTimingBus : TimingBusType;
--   signal exptBus      : ExptBusType;
   signal dmaReady     : sl;

   signal refEnable    : sl;
   signal refClkOut    : sl;
   
   signal userValues : Slv32Array(0 to 63) := (others => x"00000000");

begin

   userValues(0)(0) <= promVersion;

   testPoint <= pciLinkUp;

   -----------------  
   -- Trigger Output
   -----------------   
   Trig_Inst : entity work.EvrCardG2Trig
      generic map (
         TPD_G   => TPD_G )
      port map (
         refclk     => axiClk,
         delay_ld   => delay_ld,
         delay_wr   => delay_wr,
         delay_rd   => delay_rd,
         refEnable  => refEnable,
         refClkOut  => refClkOut,
         -- Clock
         evrRecClk  => evrClk,
         -- Trigger Inputs
         trigIn     => trig,
         trigout    => trigOut );

   RefClk_Inst : entity work.EvrV2RefClk
      generic map (
         TPD_G   => TPD_G )
     port map (
         evrClk    => evrClk,
         evrRst    => evrRst,
         evrClkSel => evrClkSel,
         -- Axi Lite interface
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => mAxiReadMasters (MMCM_INDEX_C),
         axiReadSlave   => mAxiReadSlaves  (MMCM_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(MMCM_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves (MMCM_INDEX_C),
         -- 
         refClkOut => refClkOut );
   
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
   AxiMicronP30Core_Inst : entity surf.AxiMicronP30Core
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
     EvrCardG2Gtx_Inst : entity work.EvrCardG2GMux
       generic map (
         TPD_G         => TPD_G )
       port map (
         axiClk     => axiClk,
         axiRst     => axiRst,
         axiReadMaster  => mAxiReadMasters (DRP_INDEX_C),
         axiReadSlave   => mAxiReadSlaves  (DRP_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(DRP_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves (DRP_INDEX_C),
         evrSel     => evrClkSel,  -- selects the clock and the SFP port
         -- EVR Ports
         evrRefClkP => evrRefClkP,
         evrRefClkN => evrRefClkN,
         evrRxP     => evrRxP,
         evrRxN     => evrRxN,
         evrTxP     => evrTxP,
         evrTxN     => evrTxN,
         -- EVR Interface
         rxReset    => rxControl.reset,
         rxPolarity => rxControl.polarity,
         evrClk     => evrClk,
         evrRst     => evrRst,
         rxLinkUp   => rxLinkUp,
         rxError    => rxError ,
         rxDspErr   => rxDspErr,
         rxDecErr   => rxDecErr,
         rxData     => rxData  ,
         rxDataK    => rxDataK ,
         evrTxClk   => txPhyClk,
         evrTxRst   => txPhyRst,
         txInhibit  => '0',
         txData     => txPhy.data  ,
         txDataK    => txPhy.dataK );

      -----------------         
   -- EVR LED Status
   -----------------         
   U_LEDs : entity work.EvrCardG2LedRgb
      generic map (
         TPD_G => TPD_G)
      port map (
         -- EVR Interface
         evrClk          => evrClk,
         evrRst          => evrRst,
         rxLinkUp        => rxLinkUp,
         rxError         => rxError,
         strobe          => heartBeat,
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

--   rxStatus.resetDone    <= not evrRst;
   rxStatus.resetDone    <= rxLinkUp;
   
   ------------------------------------------------------------------------------------------------
   -- Timing Core
   -- Decode timing message from GTX and distribute to system
   ------------------------------------------------------------------------------------------------
   TimingCore_1: entity lcls_timing_core.TimingCore
     generic map (
       TPD_G             => TPD_G,
       TPGEN_G           => false,
       USE_TPGMINI_G     => false,
       AXIL_RINGB_G      => true,
       ASYNC_G           => false,
       AXIL_BASE_ADDR_G  => AXI_CROSSBAR_MASTERS_CONFIG_C(CORE_INDEX_C).baseAddr )
     port map (
       gtTxUsrClk      => txPhyClk,
       gtTxUsrRst      => txPhyRst,
       gtRxRecClk      => evrClk,
       gtRxData        => rxData,
       gtRxDataK       => rxDataK,
       gtRxDispErr     => rxDspErr,
       gtRxDecErr      => rxDecErr,
       gtRxControl     => rxControl,
       gtRxStatus      => rxStatus,
       gtTxReset       => open,
       gtLoopback      => open,
       tpgMiniTimingPhy => open,
       timingClkSel    => evrClkSel,
       --
       appTimingClk    => evrClk,
       appTimingRst    => evrRst,
       appTimingBus    => appTimingBus,
       appTimingMode   => open,
       --
       axilClk         => axiClk,
       axilRst         => axiRst,
       axilReadMaster  => mAxiReadMasters (CORE_INDEX_C),
       axilReadSlave   => mAxiReadSlaves  (CORE_INDEX_C),
       axilWriteMaster => mAxiWriteMasters(CORE_INDEX_C),
       axilWriteSlave  => mAxiWriteSlaves (CORE_INDEX_C));

   U_SyncId : entity surf.SynchronizerVector
     generic map ( WIDTH_G => 24 )
     port map (
       clk            => txPhyClk,
       dataIn         => serialNumber(23 downto 0),
       dataOut        => txPhyId     (23 downto 0) );
   
   U_XpmTimingFb : entity l2si_core.XpmTimingFb
     port map (
       clk            => txPhyClk,
       rst            => txPhyRst,
       id             => txPhyId,
       phy            => txPhy );
   
   heartBeat <= appTimingBus.message.fixedRates(6) when appTimingBus.modesel='1' else
                appTimingBus.stream.eventCodes(45);

   U_Core : entity work.EvrV2Core
     generic map ( TPD_G => TPD_G)
     port map (
       axiClk              => axiClk,
       axiRst              => axiRst,
       axilWriteMaster     => mAxiWriteMasters(TPR_INDEX_C downto CSR_INDEX_C),
       axilWriteSlave      => mAxiWriteSlaves (TPR_INDEX_C downto CSR_INDEX_C),
       axilReadMaster      => mAxiReadMasters (TPR_INDEX_C downto CSR_INDEX_C),
       axilReadSlave       => mAxiReadSlaves  (TPR_INDEX_C downto CSR_INDEX_C),
       irqActive           => irqActive,
       irqEnable           => irqEnable(0),
       irqReq              => irqReq   (0),
       -- DMA
       dmaRxIbMaster       => dmaRxIbMasters  (0),
       dmaRxIbSlave        => dmaRxIbSlaves   (0),
       dmaRxTranFromPci    => dmaRxTranFromPci(0),
       dmaReady            => dmaReady,
       -- EVR Ports
       evrClk              => evrClk,
       evrRst              => evrRst,
       evrBus              => appTimingBus,
       gtxDebug            => (others=>'0'),
       -- Trigger and Sync Port
       syncL               => syncL,
       trigOut             => trig,
       refEnable           => refEnable,
       evrModeSel          => appTimingBus.modesel,
       evrClkSel           => evrClkSel,
       delay_ld            => delay_ld,
       delay_wr            => delay_wr,
       delay_rd            => delay_rd );

end mapping;
