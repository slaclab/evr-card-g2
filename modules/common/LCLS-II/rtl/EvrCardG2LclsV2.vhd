-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2LclsV2.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2016-01-15
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.TimingPkg.all;
use work.SsiPciePkg.all;

entity EvrCardG2LclsV2 is
   generic (
      TPD_G      : time := 1 ns;
      DMA_SIZE_G : integer := 1); 
   port (
      -- AXI-Lite and IRQ Interface
      axiClk              : in  sl;
      axiRst              : in  sl;
      sAxiLiteWriteMaster : in  AxiLiteWriteMasterType;
      sAxiLiteWriteSlave  : out AxiLiteWriteSlaveType;
      sAxiLiteReadMaster  : in  AxiLiteReadMasterType;
      sAxiLiteReadSlave   : out AxiLiteReadSlaveType;
      irqActive           : in  sl;
      irqEnable           : out sl;
      irqReq              : out sl;
      -- EVR Ports
      evrRefClkP          : in  sl;
      evrRefClkN          : in  sl;
      evrRxP              : in  sl;
      evrRxN              : in  sl;
      evrTxP              : out sl;
      evrTxN              : out sl;
      evrRefClk           : out sl;
      evrRecClk           : out sl;
      evrModeSel          : out sl;
      -- DMA Interface
      dmaRxIbMaster       : out AxiStreamMasterType;
      dmaRxIbSlave        : in  AxiStreamSlaveType;
      dmaRxTranFromPci    : in  TranFromPcieType;
      -- Trigger and Sync Port
      syncL               : in  sl;
      trigOut             : out slv(11 downto 0);
      -- Misc.
      cardRst             : in  sl;
      ledRedL             : out sl;
      ledGreenL           : out sl;
      ledBlueL            : out sl);  
end EvrCardG2LclsV2;

architecture mapping of EvrCardG2LclsV2 is

   constant NUM_AXI_MASTERS_C : natural := 3;
   constant EVR_INDEX_C       : natural := 0;
   constant XBAR_INDEX_C      : natural := 1;
   constant CORE_INDEX_C      : natural := 2;
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      EVR_INDEX_C      => (
         baseAddr      => x"00000000",
         addrBits      => 18,
         connectivity  => X"0001"),
      XBAR_INDEX_C => (
         baseAddr      => x"00010000",
         addrBits      => 18,
         connectivity  => X"0001"),
      CORE_INDEX_C  => (
         baseAddr      => x"00040000",
         addrBits      => 18,
         connectivity  => X"0001"));

   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

   signal appTimingBus : TimingBusType;
   
   signal recClk   : sl;
   signal evrClk   : sl;
   signal evrRst   : sl;
   signal rxLinkUp : sl;
   signal rxDspErr : slv(1 downto 0);
   signal rxDecErr : slv(1 downto 0);
   signal rxData   : slv(15 downto 0);
   signal rxDataK  : slv(1 downto 0);
   signal rxReset  : sl;
   signal rxResetDone : sl;
   signal rxPolarity  : sl;
   signal timingPhy : TimingPhyType;
   signal txPhyClk : sl;
   signal txPhyRst : sl;
   signal gtxDebug : slv(7 downto 0);
begin

   -- Undefined signals
   evrRecClk  <= recClk;

   rxResetDone <= not evrRst;
   
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
         sAxiWriteMasters(0) => sAxiLiteWriteMaster,
         sAxiWriteSlaves(0)  => sAxiLiteWriteSlave,
         sAxiReadMasters(0)  => sAxiLiteReadMaster,
         sAxiReadSlaves(0)   => sAxiLiteReadSlave,
         mAxiWriteMasters    => mAxiWriteMasters,
         mAxiWriteSlaves     => mAxiWriteSlaves,
         mAxiReadMasters     => mAxiReadMasters,
         mAxiReadSlaves      => mAxiReadSlaves);   

   EvrCardG2Gtx_Inst : entity work.EvrCardG2Gtx
      generic map (
         TPD_G         => TPD_G,
         EVR_VERSION_G => true) 
      port map (
         -- EVR Ports
         evrRefClkP => evrRefClkP,
         evrRefClkN => evrRefClkN,
         evrRxP     => evrRxP,
         evrRxN     => evrRxN,
         evrTxP     => evrTxP,
         evrTxN     => evrTxN,
         evrRefClk  => evrRefClk,
         evrRecClk  => recClk,
         -- EVR Interface
         rxReset    => rxReset,
         rxPolarity => rxPolarity,
         evrClk     => evrClk,
         evrRst     => evrRst,
         rxLinkUp   => rxLinkUp,
         rxError    => open,
         rxDspErr   => rxDspErr,
         rxDecErr   => rxDecErr,
         rxData     => rxData,
         rxDataK    => rxDataK,
         evrTxClk   => txPhyClk,
         evrTxRst   => txPhyRst,
         txInhibit  => '0',
         txData     => timingPhy.data,
         txDataK    => timingPhy.dataK,
         gtxDebug   => gtxDebug);

   --U_Axi_Evr : entity work.AxiLiteEmpty
   -- generic map ( TPD_G            => TPD_G )
   -- port map (
   --   -- AXI-Lite Bus
   --   axiClk         => axiClk,
   --   axiClkRst      => axiRst,
   --   axiReadMaster  => mAxiReadMasters (EVR_INDEX_C),
   --   axiReadSlave   => mAxiReadSlaves  (EVR_INDEX_C),
   --   axiWriteMaster => mAxiWriteMasters(EVR_INDEX_C),
   --   axiWriteSlave  => mAxiWriteSlaves (EVR_INDEX_C));

   U_Core : entity work.EvrV2Core
     generic map (
       TPD_G => TPD_G)
     port map (
       axiClk              => axiClk,
       axiRst              => axiRst,
       axilWriteMaster     => mAxiWriteMasters(EVR_INDEX_C),
       axilWriteSlave      => mAxiWriteSlaves (EVR_INDEX_C),
       axilReadMaster      => mAxiReadMasters (EVR_INDEX_C),
       axilReadSlave       => mAxiReadSlaves  (EVR_INDEX_C),
       irqActive           => irqActive,
       irqEnable           => irqEnable,
       irqReq              => irqReq,
       -- DMA
       dmaRxIbMaster       => dmaRxIbMaster,
       dmaRxIbSlave        => dmaRxIbSlave,
       dmaRxTranFromPci    => dmaRxTranFromPci,
       -- EVR Ports
       evrClk              => recClk,
       evrRst              => evrRst,
       evrBus              => appTimingBus,
       txPhyClk            => txPhyClk,
       txPhyRst            => txPhyRst,
       gtxDebug            => gtxDebug,
       -- Trigger and Sync Port
       syncL               => syncL,
       trigOut             => trigOut,
       evrModeSel          => evrModeSel,
       -- Misc.
       cardRst             => cardRst,
       ledRedL             => ledRedL,
       ledGreenL           => ledGreenL,
       ledBlueL            => ledBlueL );  
     
   U_Axi_Xbar : entity work.AxiLiteEmpty
    generic map ( TPD_G            => TPD_G )
    port map (
      -- AXI-Lite Bus
      axiClk         => axiClk,
      axiClkRst      => axiRst,
      axiReadMaster  => mAxiReadMasters (XBAR_INDEX_C),
      axiReadSlave   => mAxiReadSlaves  (XBAR_INDEX_C),
      axiWriteMaster => mAxiWriteMasters(XBAR_INDEX_C),
      axiWriteSlave  => mAxiWriteSlaves (XBAR_INDEX_C));
  
   ------------------------------------------------------------------------------------------------
   -- Timing Core
   -- Decode timing message from GTX and distribute to system
   ------------------------------------------------------------------------------------------------
   TimingCore_1: entity work.TimingCore
     generic map (
       TPD_G             => TPD_G,
       TPGEN_G           => false,
       AXIL_BASE_ADDR_G  => AXI_CROSSBAR_MASTERS_CONFIG_C(CORE_INDEX_C).baseAddr,
       AXIL_ERROR_RESP_G => AXI_RESP_DECERR_C)
     port map (
       gtTxUsrClk      => txPhyClk,
       gtTxUsrRst      => txPhyRst,
       gtRxRecClk      => recClk,
       gtRxData        => rxData,
       gtRxDataK       => rxDataK,
       gtRxDispErr     => rxDspErr,
       gtRxDecErr      => rxDecErr,
       gtRxReset       => rxReset,
       gtRxResetDone   => rxResetDone,
       gtRxPolarity    => rxPolarity,
       appTimingClk    => evrClk,
       appTimingRst    => evrRst,
       appTimingBus    => appTimingBus,
       timingPhy       => timingPhy,
       axilClk         => axiClk,
       axilRst         => axiRst,
       axilReadMaster  => mAxiReadMasters (CORE_INDEX_C),
       axilReadSlave   => mAxiReadSlaves  (CORE_INDEX_C),
       axilWriteMaster => mAxiWriteMasters(CORE_INDEX_C),
       axilWriteSlave  => mAxiWriteSlaves (CORE_INDEX_C));

end mapping;
