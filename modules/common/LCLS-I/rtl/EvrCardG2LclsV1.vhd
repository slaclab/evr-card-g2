-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2LclsV1.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2015-07-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.EvrCardG2Pkg.all;

entity EvrCardG2LclsV1 is
   generic (
      TPD_G : time := 1 ns); 
   port (
      -- AXI-Lite and IRQ Interface
      axiClk              : in    sl;
      axiRst              : in    sl;
      sAxiLiteWriteMaster : in    AxiLiteWriteMasterType;
      sAxiLiteWriteSlave  : out   AxiLiteWriteSlaveType;
      sAxiLiteReadMaster  : in    AxiLiteReadMasterType;
      sAxiLiteReadSlave   : out   AxiLiteReadSlaveType;
      irqActive           : in    sl;
      irqEnable           : out   sl;
      irqReq              : out   sl;
      -- XADC Ports
      vPIn                : in    sl;
      vNIn                : in    sl;
      -- Boot Memory Ports
      flashData           : inout slv(15 downto 0);
      flashAddr           : out   slv(23 downto 0);
      flashRs             : inout slv(1 downto 0);
      flashCe             : out   sl;
      flashOe             : out   sl;
      flashWe             : out   sl;
      flashAdv            : out   sl;
      flashWait           : in    sl;
      -- Clock Crossbar Ports
      xBarSin             : out   slv(1 downto 0);
      xBarSout            : out   slv(1 downto 0);
      xBarConfig          : out   sl;
      xBarLoad            : out   sl;
      -- EVR Ports
      evrRefClkP          : in    sl;
      evrRefClkN          : in    sl;
      evrRxP              : in    sl;
      evrRxN              : in    sl;
      evrTxP              : out   sl;
      evrTxN              : out   sl;
      evrDebugClk         : out   slv(1 downto 0);
      -- Trigger and Sync Port
      syncL               : in    sl;
      trigOut             : out   slv(11 downto 0);
      -- Misc.
      cardRst             : in    sl;
      serialNumber        : out   slv(63 downto 0);
      ledRedL             : out   sl;
      ledGreenL           : out   sl;
      ledBlueL            : out   sl);  
end EvrCardG2LclsV1;

architecture mapping of EvrCardG2LclsV1 is

   constant NUM_AXI_MASTERS_C : natural := 5;

   constant EVR_INDEX_C      : natural := 0;
   constant VERSION_INDEX_C  : natural := 1;
   constant BOOT_MEM_INDEX_C : natural := 2;
   constant XADC_INDEX_C     : natural := 3;
   constant XBAR_INDEX_C     : natural := 4;

   constant EVR_ADDR_C      : slv(31 downto 0) := X"00000000";
   constant VERSION_ADDR_C  : slv(31 downto 0) := X"00010000";
   constant BOOT_MEM_ADDR_C : slv(31 downto 0) := X"00020000";
   constant XADC_ADDR_C     : slv(31 downto 0) := X"00030000";
   constant XBAR_ADDR_C     : slv(31 downto 0) := X"00040000";
   
   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
      EVR_INDEX_C      => (
         baseAddr      => EVR_ADDR_C,
         addrBits      => 16,
         connectivity  => X"0001"),
      VERSION_INDEX_C  => (
         baseAddr      => VERSION_ADDR_C,
         addrBits      => 16,
         connectivity  => X"0001"),
      BOOT_MEM_INDEX_C => (
         baseAddr      => BOOT_MEM_ADDR_C,
         addrBits      => 16,
         connectivity  => X"0001"),
      XADC_INDEX_C     => (
         baseAddr      => XADC_ADDR_C,
         addrBits      => 16,
         connectivity  => X"0001"),
      XBAR_INDEX_C     => (
         baseAddr      => XBAR_ADDR_C,
         addrBits      => 16,
         connectivity  => X"0001"));  

   constant XBAR_DEFAULT_C : Slv2Array(3 downto 0) := (
      3 => "01",                        -- OUT[3] = IN[1]
      2 => "00",                        -- OUT[2] = IN[0]
      1 => "01",                        -- OUT[1] = IN[1]
      0 => "00");                       -- OUT[0] = IN[0]   

   signal mAxiWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

   signal fpgaReload : sl;
   signal evrClk     : sl;
   signal evrRst     : sl;
   signal rxLinkUp   : sl;
   signal rxError    : sl;
   signal rxData     : slv(15 downto 0);
   signal rxDataK    : slv(1 downto 0);

begin

   -- Undefined signals
   ledRedL   <= '1';
   ledGreenL <= '1';
   ledBlueL  <= '1';

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

   --------------------------
   -- AXI-Lite Version Module
   --------------------------          
   AxiVersion_Inst : entity work.AxiVersion
      generic map (
         TPD_G           => TPD_G,
         EN_DEVICE_DNA_G => true)   
      port map (
         dnaValueOut    => serialNumber,
         fpgaReload     => fpgaReload,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMasters(VERSION_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(VERSION_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(VERSION_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(VERSION_INDEX_C),
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);           

   ---------------------
   -- FPGA Reboot Module
   ---------------------
   Iprog7Series_Inst : entity work.Iprog7Series
      generic map (
         TPD_G => TPD_G)   
      port map (
         clk         => axiClk,
         rst         => axiRst,
         start       => fpgaReload,
         bootAddress => X"00000000");   

   --------------------
   -- Boot Flash Module
   --------------------
   flashRs <= "11";
   AxiMicronP30Core_Inst : entity work.AxiMicronP30Core
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
   AxiXadcMinimumCore_Inst : entity work.AxiXadcMinimumCore
      generic map (
         TPD_G => TPD_G) 
      port map (
         -- XADC Ports
         vPIn           => vPIn,
         vNIn           => vNIn,
         -- AXI-Lite Register Interface
         axiReadMaster  => mAxiReadMasters(XADC_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(XADC_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(XADC_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(XADC_INDEX_C),
         -- Clocks and Resets
         axiClk         => axiClk,
         axiRst         => axiRst);         

   ---------------------------------
   -- AXI-Lite Clock Crossbar Module
   ---------------------------------
   AxiSy56040Reg_Inst : entity work.AxiSy56040Reg
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
   EvrCardG2Gtx_Inst : entity work.EvrCardG2Gtx
      generic map (
         TPD_G         => TPD_G,
         EVR_VERSION_G => false) 
      port map (
         -- EVR Ports
         evrRefClkP  => evrRefClkP,
         evrRefClkN  => evrRefClkN,
         evrRxP      => evrRxP,
         evrRxN      => evrRxN,
         evrTxP      => evrTxP,
         evrTxN      => evrTxN,
         evrDebugClk => evrDebugClk,
         -- EVR Interface
         evrClk      => evrClk,
         evrRst      => evrRst,
         rxLinkUp    => rxLinkUp,
         rxError     => rxError,
         rxData      => rxData,
         rxDataK     => rxDataK);    

   -----------
   -- EVR Core
   -----------
   EvrV1Core_Inst : entity work.EvrV1Core
      generic map (
         TPD_G           => TPD_G,
         SYNC_POLARITY_G => '0',        -- '0' = active LOW logic
         USE_WSTRB_G     => true,       -- true = using wstrb due to legacy PCIe driver
         ENDIAN_G        => true)       -- true = big endian  
      port map (
         -- AXI-Lite and IRQ Interface
         axiClk         => axiClk,
         axiRst         => axiRst,
         axiReadMaster  => mAxiReadMasters(EVR_INDEX_C),
         axiReadSlave   => mAxiReadSlaves(EVR_INDEX_C),
         axiWriteMaster => mAxiWriteMasters(EVR_INDEX_C),
         axiWriteSlave  => mAxiWriteSlaves(EVR_INDEX_C),
         irqActive      => irqActive,
         irqEnable      => irqEnable,
         irqReq         => irqReq,
         -- Trigger and Sync Port
         sync           => syncL,
         trigOut        => trigOut,
         -- EVR Interface
         evrClk         => evrClk,
         evrRst         => evrRst,
         rxLinkUp       => rxLinkUp,
         rxError        => rxError,
         rxData         => rxData,
         rxDataK        => rxDataK);    

end mapping;
