-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Sim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-07-10
-- Last update: 2019-04-07
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

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.TimingPkg.all;
use work.TimingExtnPkg.all;
use work.XpmPkg.all;
use work.SsiPciePkg.all;
use work.TPGPkg.all;
use work.EvrV2Pkg.all;
use work.XpmPkg.all;
use work.XpmMiniPkg.all;

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
  signal exptBus  : ExptBusType   := EXPT_BUS_INIT_C;

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

begin

  xpmConfig.partition.l0Select.enabled <= '1';
  xpmConfig.partition.l0Select.rateSel <= toSlv(0,16);
  xpmConfig.partition.l0Select.destSel <= x"8000";
  
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
    wait for 2.7 ns;
    evrClk <= '0';
    wait for 2.7 ns;
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
    
  --U_TPG : entity work.TPGMini
  --  port map ( statusO => open,
  --             configI => tpgConfig,
  --             txClk   => evrClk,
  --             txRst   => evrRst,
  --             txRdy   => '1',
  --             txData  => xData.data,
  --             txDataK => xData.dataK );

  U_TPG : entity work.TPGMini
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

  --  This doesn't work!
  --  tpgAdvance <= tpgStream.ready;
  --
  --  Use a TimingSerializer to generate advance signal
  --
  U_TS : entity work.TimingSerializer
    port map ( clk          => evrClk,
               rst          => evrRst,
               fiducial     => tpgFiducial,
               streams  (0) => tpgStream,
               streamIds(0) => x"0",
               advance  (0) => tpgAdvance );
  

  U_Xpm : entity work.XpmMini
     generic map ( NDsLinks => 1 )
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
  
  U_TPR : entity work.TimingFrameRx
    port map ( rxClk               => evrClk,
               rxRst               => evrRst,
               rxData              => xData,
               messageDelay        => (others=>'0'),
               messageDelayRst     => '0',
               timingMessage       => evrBus.message,
               timingMessageStrobe => evrBus.strobe,
               timingMessageValid  => evrBus.valid,
               timingExtn          => evrBus.extn,
               timingExtnValid     => evrBus.extnValid,
               rxVersion           => open,
               staData             => open );
  
  U_DUT : entity work.EvrV2Core
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
               trigOut             => open,
               evrModeSel          => '1',
               delay_ld            => open,
               delay_wr            => open,
               delay_rd            => (others=>"000000") );

  --U_MOD : entity work.EvrV2Module
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

  U_AxiXbar : entity work.AxiLiteCrossbar
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
    
  -- Initialize the AxiStreamDmaRingWrite
  process is
    
    procedure wreg(addr : slv(31 downto 0); data : slv(31 downto 0)) is
    begin
       wait until axilClk='0';
       axilWriteMaster.awaddr  <= addr;
       axilWriteMaster.awvalid <= '1';
       axilWriteMaster.wdata   <= data;
       axilWriteMaster.wvalid  <= '1';
       axilWriteMaster.bready  <= '1';
       wait until axilClk='1';
       wait until axilClk='0';
       wait until axilWriteSlave.bvalid='1';
       wait until axilClk='1';
       wait until axilClk='0';
       axilWriteMaster.awvalid <= '0';
       axilWriteMaster.wvalid  <= '0';
       axilWriteMaster.bready  <= '0';
       wait until axilClk='1';
       wait until axilClk='0';
       wait until axilClk='1';
     end procedure;

     constant da : slv(31 downto 0) := x"00001000";
     variable a  : slv(31 downto 0) := x"00000000";
     constant DMA_BUFFERS_C : integer := 32;
   begin
     wait until axilRst='0';
     --a := toSlv(DMA_BUFFERS_C-1,32);
     --wreg(1024+260, a);
     --a := x"80001000";
     --wreg(1024+256, a);
     ----  Setup DMA buffers
     --for i in 0 to DMA_BUFFERS_C-1 loop
     --  wreg(1024+4*0, a); -- write to DMA engine 0
     --  a := a + da;
     --end loop;

     -- Setup triggers

     -- Setup event select
     a := x"00000001";
     wreg(x"00060000", a); -- irq enable
--     a := x"00000001";
--     wreg(20, a); -- trigSel (LCLS/LCLS-II)
     a := toSlv(DMA_BUFFERS_C,32);
     wreg(x"00060018", a); -- dmaFullThr?

     for i in 0 to ReadoutChannels-1 loop
--       a := x"40000000"; -- fixed rate 0
       a := x"40001800"; -- fixed rate 0
--       a := x"40000001"; -- fixed rate 1
       wreg(x"00080004"+4096*i, a); -- event select
--     a := x"00000004"; -- delay 4 cycles
--       a := x"00000000"; -- delay 0 cycles
--       a := x"00200000"; -- presample 2 cycles
       if i>2 then
         a := toSlv(0,32);
       else
         a := toSlv(2-i,12) & toSlv(0,20);
       end if;
       wreg(x"0008000C"+4096*i, a); -- bsa active setup/delay
       a := x"00000001";
       wreg(x"00080010"+4096*i, a); -- bsa active width
     end loop;
     
     wreg(x"000a0000", x"80010001");  -- enable
     wreg(x"000a0004", x"00000C01");  -- delay
     wreg(x"000a0008", x"00000004");  -- width
     
     wreg(x"000a1000", x"80010002");  -- enable
     wreg(x"000a1004", x"00000003");  -- delay
     wreg(x"000a1008", x"00000004");  -- width

     for i in 0 to ReadoutChannels-1 loop
       if i > 10 then
         a := toSlv(7,32);
       else
         a := toSlv(7,32);
       end if;
       wreg(x"00080000"+4096*i, a); -- enable + bsa + dma
     end loop;
     
     axilDone <= '1';
     wait;
   end process;

end top_level_app;
