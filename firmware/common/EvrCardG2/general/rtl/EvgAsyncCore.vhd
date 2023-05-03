-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvgAsyncCore.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2023-05-03
-- Last update: 2023-05-03
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

entity EvgAsyncCore is
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
end EvgAsyncCore;

architecture mapping of EvgAsyncCore is

   -- Constants
   constant BAR_SIZE_C : positive := 1;
   constant DMA_SIZE_C : positive := 1;
   constant AXI_CLK_FREQ_C : real := 125.0e6;
   
   -- AXI-Lite Signals
   signal axiLiteWriteMaster : AxiLiteWriteMasterArray(BAR_SIZE_C-1 downto 0);
   signal axiLiteWriteSlave  : AxiLiteWriteSlaveArray (BAR_SIZE_C-1 downto 0);
   signal axiLiteReadMaster  : AxiLiteReadMasterArray (BAR_SIZE_C-1 downto 0);
   signal axiLiteReadSlave   : AxiLiteReadSlaveArray  (BAR_SIZE_C-1 downto 0);

   constant NUM_AXI_MASTERS_C : natural := 7;

   constant VERSION_INDEX_C  : natural := 0;
   constant BOOT_MEM_INDEX_C : natural := 1;
   constant XADC_INDEX_C     : natural := 2;
   constant XBAR_INDEX_C     : natural := 3;
   constant LED_INDEX_C      : natural := 4;
   constant CSR_INDEX_C      : natural := 5;
   constant DRP_INDEX_C      : natural := 6;

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
      DRP_INDEX_C      => (
         baseAddr      => X"00070000",
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
   signal serialNumber : slv(127 downto 0);
   signal evrClkSel    : sl;

   signal heartBeat    : sl;
   signal dmaReady     : sl;
   signal timeStampWr  : slv(63 downto 0);
   signal timeStampRd  : slv(63 downto 0);
   signal timeStampWrEn: sl;
   signal eventCodes   : slv(255 downto 0);
   signal dataBuff     : TimingDataBuffType := TIMING_DATA_BUFF_INIT_C;
   
   type RegType is record
     pulseId  : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
     pulseId  => (others=>'0') );

   signal r    : RegType := REG_INIT_C;
   signal r_in : RegType;
   
begin

   testPoint <= pciLinkUp;
   trigOut(trigOut'left downto 1) <= (others=>'0');
   trigOut(0) <= syncL;

   mAxiReadSlaves  (MMCM_INDEX_C) <= AXI_LITE_READ_SLAVE_EMPTY_OK_C;
   mAxiWriteSlaves (MMCM_INDEX_C) <= AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;
   
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
         rxReset    => '0',
         rxPolarity => '0',
         evrClk     => open,
         evrRst     => open,
         rxLinkUp   => open,
         rxError    => open,
         rxDspErr   => open,
         rxDecErr   => open,
         rxData     => open,
         rxDataK    => open,
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
         evrClk          => txPhyClk,
         evrRst          => txPhyRst,
         rxLinkUp        => '1',
         rxError         => '0',
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

   ------------------------------------------------------------------------------------------------
   -- Timing Core
   -- Generate timing stream when syncL fires
   ------------------------------------------------------------------------------------------------
   TimingCore_1: entity lcls_timing_core.TimingStreamTx
     generic map (
       TPD_G => TPD_G )
     port map (
       -- Clock and reset
       clk       => txPhyClk,
       rst       => txPhyRst,
       fiducial  => fiducial,
       dataBuff  => dataBuff,
       pulseId   => r.pulseId,
       eventCodes=> eventCodes,
       data      => txPhy.data,
       dataK     => txPhy.dataK );

   U_Fiducial : entity surf.SynchronizerOneShot
     generic map (
       TPD_G         => TPD_G,
       IN_POLARITY_G => '0' )
     port map (
       clk     => txPhyClk,
       rst     => txPhyRst,
       dataIn  => syncL,
       dataOut => fiducial );
     
   txPhy.control.inhibit     <= '0';
   txPhy.control.polarity    <= '0';
   txPhy.control.bufferByRst <= '0';

   heartBeat <= not syncL;

   dmaRxIbMasters(0) <= AXI_STREAM_MASTER_INIT_C;
   dmaReady          <= '0';

   irqEnable <= '0';
   irqReq    <= '0';

  U_ClockTime : entity lcls_timing_core.ClockTime
    generic map (
      TPD_G => TPD_G)
    port map (
      step      => toSlv(8,5),
      remainder => toSlv(2,5),
      divisor   => toSlv(5,5),
      rst    => axiRst,
      clkA   => axiClk,
      wrEnA  => timeStampWrEn,
      wrData => timeStampWr,
      rdData => timeStampRd,
      clkB   => txPhyClk,
      wrEnB  => fiducial,
      dataO  => epicsTime);

   U_Regs : entity work.EvgAsyncControl
     generic map (
       TPD_G            => TPD_G )
     port map (
       -- AXI-Lite and IRQ Interface
       axilClk            => axiClk,
       axilRst            => axiRst,
       axilReadMaster     => mAxiReadMasters (CSR_INDEX_C),
       axilReadSlave      => mAxiReadSlaves  (CSR_INDEX_C),
       axilWriteMaster    => mAxiWriteMasters(CSR_INDEX_C),
       axilWriteSlave     => mAxiWriteSlaves (CSR_INDEX_C),
       --
       pllReset           => txPhy.control.pllReset,
       phyReset           => txPhy.control.reset,
       timeStampWr        => timeStampWr,
       timeStampWrEn      => timeStampWrEn,
       timeStampRd        => timeStampRd,
       eventCodes         => eventCodes );

   dataBuff.epicsTime <= epicsTime(31 downto 17) & (r.pulseId(16 downto 0)+toSlv(2,17)) & epicsTime(63 downto 32);
   dataBuff.dtype                            <= X"0001";
   dataBuff.version                          <= X"0001";
   
   comb : process ( r, txPhyRst, fiducial ) is
     variable v : RegType;
   begin
     v := r;

     if fiducial = '1' then
       if r.pulseId=x"0001FFDF" then
         v.pulseId := (others=>'0');
       else
         v.pulseId := r.pulseId+1;
       end if;
     end if;
         
     if txPhyRst='1' then
       v := REG_INIT_C;
     end if;

     r_in <= v;
     
   end process comb;

   seq : process ( txPhyClk ) is
   begin
     if rising_edge(txPhyClk) then
       r <= r_in;
     end if;
   end process seq;
   
end mapping;
