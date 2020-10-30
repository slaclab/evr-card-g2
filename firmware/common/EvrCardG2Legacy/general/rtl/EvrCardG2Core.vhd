-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2020-10-29
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
      evrRefClkP : in    slv(0 downto 0);
      evrRefClkN : in    slv(0 downto 0);
      evrRxP     : in    slv(0 downto 0);
      evrRxN     : in    slv(0 downto 0);
      evrTxP     : out   slv(0 downto 0);
      evrTxN     : out   slv(0 downto 0);
      -- Trigger and Sync Port
      syncL      : in    sl;
      trigOut    : out   slv(11 downto 0);
      -- Misc.
      debugIn    : out   slv(11 downto 0);
      ledRedL    : out   slv(1 downto 0);
      ledGreenL  : out   slv(1 downto 0);
      ledBlueL   : out   slv(1 downto 0);
      testPoint  : out   sl);  
end EvrCardG2Core;

architecture mapping of EvrCardG2Core is

   -- Constants
   constant BAR_SIZE_C : positive := 2;
   constant DMA_SIZE_C : positive := 1;

   -- AXI-Lite Signals
   signal axiLiteWriteMaster : AxiLiteWriteMasterArray(BAR_SIZE_C-1 downto 0);
   signal axiLiteWriteSlave  : AxiLiteWriteSlaveArray(BAR_SIZE_C-1 downto 0);
   signal axiLiteReadMaster  : AxiLiteReadMasterArray(BAR_SIZE_C-1 downto 0);
   signal axiLiteReadSlave   : AxiLiteReadSlaveArray(BAR_SIZE_C-1 downto 0);

   -- DMA Signals      
   signal dmaTxTranFromPci : TranFromPcieArray(DMA_SIZE_C-1 downto 0)    := (others => TRAN_FROM_PCIE_INIT_C);
   signal dmaRxTranFromPci : TranFromPcieArray(DMA_SIZE_C-1 downto 0)    := (others => TRAN_FROM_PCIE_INIT_C);
   signal dmaTxObMasters   : AxiStreamMasterArray(DMA_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal dmaTxObSlaves    : AxiStreamSlaveArray(DMA_SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal dmaTxIbMasters   : AxiStreamMasterArray(DMA_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal dmaTxIbSlaves    : AxiStreamSlaveArray(DMA_SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);
   signal dmaRxIbMasters   : AxiStreamMasterArray(DMA_SIZE_C-1 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal dmaRxIbSlaves    : AxiStreamSlaveArray(DMA_SIZE_C-1 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal axiClk       : sl;
   signal axiRst       : sl;
   signal pciLinkUp    : sl;
   signal cardRst      : sl;
   signal irqActive    : sl;
   signal irqEnable    : slv(BAR_SIZE_C-1 downto 0);
   signal irqReq       : slv(BAR_SIZE_C-1 downto 0);
   signal trig         : Slv12Array(1 downto 0);
   signal serialNumber : slv(63 downto 0);
   signal evrRefClk    : slv(0 downto 0);
   signal evrRecClk    : slv(1 downto 0);

begin

   testPoint <= pciLinkUp;

   -----------------  
   -- Trigger Output
   -----------------   
   Trig_Inst : entity work.EvrCardG2Trig
      generic map (
         TPD_G => TPD_G)
      port map (
         evrModeSel => '0',
         -- Clock
         evrRecClk  => evrRecClk,
         -- Trigger Inputs
         trigIn     => trig,
         trigout    => trigOut);

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
         serialNumber        => serialNumber,
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

   ------------------         
   -- LCLS-I EVR Core
   ------------------         
   EvrCardG2LclsV1_Inst : entity work.EvrCardG2LclsV1
      generic map (
         TPD_G           => TPD_G,
         BUILD_INFO_G    => BUILD_INFO_G )
      port map (
         -- AXI-Lite and IRQ Interface
         axiClk              => axiClk,
         axiRst              => axiRst,
         sAxiLiteWriteMaster => axiLiteWriteMaster(0),
         sAxiLiteWriteSlave  => axiLiteWriteSlave(0),
         sAxiLiteReadMaster  => axiLiteReadMaster(0),
         sAxiLiteReadSlave   => axiLiteReadSlave(0),
         irqActive           => irqActive,
         irqEnable           => irqEnable(0),
         irqReq              => irqReq(0),
         -- XADC Ports
         vPIn                => vPIn,
         vNIn                => vNIn,
         -- FLASH Interface 
         flashData           => flashData,
         flashAddr           => flashAddr,
         -- flashRs             => flashRs,
         flashAdv            => flashAdv,
         flashCe             => flashCe,
         flashOe             => flashOe,
         flashWe             => flashWe,
         flashWait           => flashWait,
         -- Clock Management Ports
         xBarSin             => xBarSin,
         xBarSout            => xBarSout,
         xBarConfig          => xBarConfig,
         xBarLoad            => xBarLoad,
         -- EVR Ports
         evrRefClkP          => evrRefClkP(0),
         evrRefClkN          => evrRefClkN(0),
         evrRxP              => evrRxP(0),
         evrRxN              => evrRxN(0),
         evrTxP              => evrTxP(0),
         evrTxN              => evrTxN(0),
         evrRefClk           => evrRefClk(0),
         evrRecClk           => evrRecClk(0),
         -- Trigger and Sync Port
         syncL               => syncL,
         trigOut             => trig(0),
         -- Misc.
         cardRst             => cardRst,
         serialNumber        => serialNumber,
         ledRedL             => ledRedL(0),
         ledGreenL           => ledGreenL(0),
         ledBlueL            => ledBlueL(0));   


   axiLiteWriteSlave(1) <= AXI_LITE_WRITE_SLAVE_INIT_C;
   axiLiteReadSlave (1) <= AXI_LITE_READ_SLAVE_INIT_C;
   ledRedL  (1) <= '1';
   ledGreenL(1) <= '1';
   ledBlueL (1) <= '1';

end mapping;
