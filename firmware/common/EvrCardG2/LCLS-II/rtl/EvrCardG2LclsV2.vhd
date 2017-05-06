-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2LclsV2.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2016-11-02
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
      delay_ld            : out slv      (11 downto 0);
      delay_wr            : out Slv6Array(11 downto 0);
      delay_rd            : in  Slv6Array(11 downto 0);
      -- DMA Interface
      dmaRxIbMaster       : out AxiStreamMasterType;
      dmaRxIbSlave        : in  AxiStreamSlaveType;
      dmaRxTranFromPci    : in  TranFromPcieType;
      -- Trigger and Sync Port
      syncL               : in  sl;
      trigOut             : out slv(11 downto 0);
      -- Misc.
      debugIn             : in  slv(11 downto 0);
      cardRst             : in  sl;
      ledRedL             : out sl;
      ledGreenL           : out sl;
      ledBlueL            : out sl);  
end EvrCardG2LclsV2;

architecture mapping of EvrCardG2LclsV2 is

   constant USE_PLL           : boolean := false;
   constant NUM_AXI_MASTERS_C : natural := 2;
   constant EVR_INDEX_C       : natural := 0;
   constant CORE_INDEX_C      : natural := 1;
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      EVR_INDEX_C      => (
         baseAddr      => x"00000000",
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
   signal exptBus      : ExptBusType;
   
   signal recClk   : sl;
   signal evrClk   : sl;
   signal evrRst   : sl;
   signal rxLinkUp : sl;
   signal rxDspErr : slv(1 downto 0);
   signal rxDecErr : slv(1 downto 0);
   signal rxData   : slv(15 downto 0);
   signal rxDataK  : slv(1 downto 0);
   signal rxControl : TimingPhyControlType;
   signal rxStatus  : TimingPhyStatusType := TIMING_PHY_STATUS_INIT_C;
   signal timingPhy : TimingPhyType;
   signal txPhyClk : sl;
   signal txPhyRst : sl;
   signal txData   : slv(15 downto 0);
   signal txDataK  : slv( 1 downto 0);
   signal dmaReady : sl;
   signal pllClk   : sl;
   signal intTrig  : slv(11 downto 0);
   
begin

   rxStatus.resetDone <= not evrRst;
   
   GEN_PLL: if (USE_PLL) generate
     U_PLL: entity work.ClockManager7
       generic map ( TYPE_G          => "PLL",
                     INPUT_BUFG_G    => false,
                     NUM_CLOCKS_G    => 1,
                     BANDWIDTH_G     => "LOW",
                     CLKIN_PERIOD_G  => 5.4,
                     CLKOUT0_PHASE_G => 0.0 )
       port map ( clkIn     => recClk,
                  clkOut(0) => pllClk );
     U_TRIGSYNC: entity work.SynchronizerVector
       generic map ( WIDTH_G => intTrig'length )
       port map ( clk     => pllClk,
                  dataIn  => intTrig,
                  dataOut => trigOut );
     evrRecClk <= pllClk;
   end generate GEN_PLL;

   NOGEN_PLL: if (not USE_PLL) generate
     evrRecClk <= recClk;
     trigOut   <= intTrig;
   end generate NOGEN_PLL;
   
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
         rxReset    => rxControl.reset,
         rxPolarity => rxControl.polarity,
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
         txData     => txData,
         txDataK    => txDataK);

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
       dmaReady            => dmaReady,
       -- EVR Ports
       evrClk              => recClk,
       evrRst              => evrRst,
       evrBus              => appTimingBus,
       exptBus             => exptBus,
       txPhyClk            => txPhyClk,
       txPhyRst            => txPhyRst,
       gtxDebug            => (others=>'0'),
       -- Trigger and Sync Port
       syncL               => syncL,
       trigOut             => intTrig,
       evrModeSel          => evrModeSel,
       delay_ld            => delay_ld,
       delay_wr            => delay_wr,
       delay_rd            => delay_rd,
       -- Misc.
       cardRst             => cardRst,
       ledRedL             => ledRedL,
       ledGreenL           => ledGreenL,
       ledBlueL            => ledBlueL );  
     
   ------------------------------------------------------------------------------------------------
   -- Timing Core
   -- Decode timing message from GTX and distribute to system
   ------------------------------------------------------------------------------------------------
   TimingCore_1: entity work.TimingCore
     generic map (
       TPD_G             => TPD_G,
       TPGEN_G           => false,
       USE_TPGMINI_G     => false,
       AXIL_RINGB_G      => false,
       ASYNC_G           => false,
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
       gtRxControl     => rxControl,
       gtRxStatus      => rxStatus,
       appTimingClk    => evrClk,
       appTimingRst    => evrRst,
       appTimingBus    => appTimingBus,
       exptBus         => exptBus,
       timingPhy       => timingPhy,
       axilClk         => axiClk,
       axilRst         => axiRst,
       axilReadMaster  => mAxiReadMasters (CORE_INDEX_C),
       axilReadSlave   => mAxiReadSlaves  (CORE_INDEX_C),
       axilWriteMaster => mAxiWriteMasters(CORE_INDEX_C),
       axilWriteSlave  => mAxiWriteSlaves (CORE_INDEX_C));

   DaqControlTx_1 : entity work.DaqControlTx
     port map (
       txclk           => txPhyClk,
       txrst           => txPhyRst,
       rxrst           => evrRst,
       ready           => dmaReady,
       -- status          => debugIn, + register bus for programmable control
       --                             + input timing for tag caching
       data            => txData,
       dataK           => txDataK );
       
end mapping;
