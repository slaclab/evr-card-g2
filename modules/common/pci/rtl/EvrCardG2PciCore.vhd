-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2PciCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-10
-- Last update: 2015-06-10
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPciePkg.all;

entity EvrCardG2PciCore is
   generic (
      TPD_G      : time     := 1 ns;
      BAR_SIZE_G : positive := 2;
      DMA_SIZE_G : positive := 1);
   port (
      -- System Interface
      irqActive           : out  sl;      
      irqEnable           : in  slv(BAR_SIZE_G-1 downto 0) := (others => '0');
      irqReq              : in  slv(BAR_SIZE_G-1 downto 0) := (others => '0');
      serialNumber        : in  slv(63 downto 0);
      cardRst             : out sl;
      pciLinkUp           : out sl;
      -- AXI-Lite Interface
      mAxiLiteWriteMaster : out AxiLiteWriteMasterArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteWriteSlave  : in  AxiLiteWriteSlaveArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteReadMaster  : out AxiLiteReadMasterArray(BAR_SIZE_G-1 downto 0);
      mAxiLiteReadSlave   : in  AxiLiteReadSlaveArray(BAR_SIZE_G-1 downto 0);
      -- DMA Interface      
      dmaTxTranFromPci    : out TranFromPcieArray(DMA_SIZE_G-1 downto 0);
      dmaRxTranFromPci    : out TranFromPcieArray(DMA_SIZE_G-1 downto 0);
      dmaTxObMasters      : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaTxObSlaves       : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaTxIbMasters      : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaTxIbSlaves       : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbMasters      : in  AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaRxIbSlaves       : out AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- Clock and reset
      pciClk              : out sl;
      pciRst              : out sl;
      -- PCIe Ports 
      pciRstL             : in  sl;
      pciRefClkP          : in  sl;
      pciRefClkN          : in  sl;
      pciRxP              : in  slv(3 downto 0);
      pciRxN              : in  slv(3 downto 0);
      pciTxP              : out slv(3 downto 0);
      pciTxN              : out slv(3 downto 0));      
end EvrCardG2PciCore;

architecture mapping of EvrCardG2PciCore is

   signal pciClock    : sl;
   signal pciReset    : sl;
   signal cfgFromPci  : PcieCfgOutType;
   signal cfgToPci    : PcieCfgInType;
   signal pciIbMaster : AxiStreamMasterType;
   signal pciIbSlave  : AxiStreamSlaveType;
   signal pciObMaster : AxiStreamMasterType;
   signal pciObSlave  : AxiStreamSlaveType;

begin

   pciClk <= pciClock;
   pciRst <= pciReset;

   EvrCardG2PciFrontEnd_Inst : entity work.EvrCardG2PciFrontEnd
      generic map (
         TPD_G => TPD_G)
      port map (
         -- PCIe Interface      
         cfgFromPci  => cfgFromPci,
         cfgToPci    => cfgToPci,
         pciIbMaster => pciIbMaster,
         pciIbSlave  => pciIbSlave,
         pciObMaster => pciObMaster,
         pciObSlave  => pciObSlave,
         -- Clock and Resets
         pciClk      => pciClock,
         pciRst      => pciReset,
         pciLinkUp   => pciLinkUp,
         -- PCIe Ports 
         pciRstL     => pciRstL,
         pciRefClkP  => pciRefClkP,
         pciRefClkN  => pciRefClkN,
         pciRxP      => pciRxP,
         pciRxN      => pciRxN,
         pciTxP      => pciTxP,
         pciTxN      => pciTxN);           

   SsiPcieCore_Inst : entity work.SsiPcieCore
      generic map (
         TPD_G      => TPD_G,
         DMA_SIZE_G => DMA_SIZE_G,
         BAR_SIZE_G => BAR_SIZE_G,
         BAR_MASK_G => (others => x"FFF00000"))
      port map (
         -- System Interface
         irqActive           => irqActive,
         irqEnable           => irqEnable,
         irqReq              => irqReq,
         serialNumber        => serialNumber,
         cardRst             => cardRst,
         -- AXI-Lite Interface
         mAxiLiteWriteMaster => mAxiLiteWriteMaster,
         mAxiLiteWriteSlave  => mAxiLiteWriteSlave,
         mAxiLiteReadMaster  => mAxiLiteReadMaster,
         mAxiLiteReadSlave   => mAxiLiteReadSlave,
         -- DMA Interface      
         dmaTxTranFromPci    => dmaTxTranFromPci,
         dmaRxTranFromPci    => dmaRxTranFromPci,
         dmaTxObMasters      => dmaTxObMasters,
         dmaTxObSlaves       => dmaTxObSlaves,
         dmaTxIbMasters      => dmaTxIbMasters,
         dmaTxIbSlaves       => dmaTxIbSlaves,
         dmaRxIbMasters      => dmaRxIbMasters,
         dmaRxIbSlaves       => dmaRxIbSlaves,
         -- PCIe Interface      
         cfgFromPci          => cfgFromPci,
         cfgToPci            => cfgToPci,
         pciIbMaster         => pciIbMaster,
         pciIbSlave          => pciIbSlave,
         pciObMaster         => pciObMaster,
         pciObSlave          => pciObSlave,
         -- Clock and Resets
         pciClk              => pciClock,
         pciRst              => pciReset);   

end mapping;
