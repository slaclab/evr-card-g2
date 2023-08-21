-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrLockApp.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2023-06-14
-- Last update: 2023-08-21
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

entity EvrLockApp is
   port (
      -- Timing Ports
      timingClk       : in  slv(1 downto 0);
      timingRst       : in  slv(1 downto 0);
      timingBus       : in  TimingBusArray(1 downto 0);
      -- Debug
      txClk0          : in  sl;
      txRst0          : in  sl;
      fiducial0       : in  sl;
      txData          : in  Slv16Array(1 downto 0);
      txDataK         : in  Slv2Array (1 downto 0);
      loopback        : out Slv3Array (1 downto 0);
      nctrigdelay     : out slv(19 downto 0);
      psclk           : out sl;
      psen            : out sl;
      psincdec        : out sl;
      rxmode          : out slv(1 downto 0);
      -- Register Ports
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType );
end EvrLockApp;

architecture mapping of EvrLockApp is

  constant WIDTH_C : integer := 27;
  constant CKWID_C : integer := 11;  -- 119MHz * 14us
  constant CKDIV_C : integer := 2;
  constant DEBUG_C : boolean := false;
  
  type RegType is record
    psen           : sl;
    psincdec       : sl;
    ack            : sl;
    loopback       : Slv3Array(1 downto 0);
    rxmode         : slv(1 downto 0);
    nctrigdelay    : slv(nctrigdelay'range);
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    psen           => '0',
    psincdec       => '0',
    ack            => '0',
    loopback       => (others=>"000"),
    rxmode         => "00",
    nctrigdelay    => (others=>'0'),
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  type R0RegType is record
    mark       : sl;
    oneHz      : sl;
  end record;

  constant R0REG_INIT_C : R0RegType := (
    mark       => '0',
    oneHz      => '0');
  
  signal r0   : R0RegType := R0REG_INIT_C;
  signal r0in : R0RegType;

  type R1RegType is record
    mark       : sl;
    count      : slv(16 downto 0);
    latch      : slv(16 downto 0);
  end record;

  constant R1REG_INIT_C : R1RegType := (
    mark       => '0',
    count      => (others=>'0'),
    latch      => (others=>'0') );
  
  signal r1   : R1RegType := R1REG_INIT_C;
  signal r1in : R1RegType;

  signal refMark  , testMark   : sl;
  signal ref1Hz   , test1Hz    : sl;
  signal testMarkS             : sl;
  signal test1HzF, test1HzS    : sl;
  signal fid360                : sl;
  signal test1HzCnt            : slv(16 downto 0);
  signal tmo                   : sl;
  signal ready                 : sl;
  signal clks                  : slv(CKWID_C-1 downto 0);
  signal phase, phaseN, valid  : slv(WIDTH_C-1 downto 0);
  signal tmoCnt, refMarkCnt, testMarkCnt : slv(19 downto 0);
  signal timingRstS            : slv(2 downto 0);
  signal txDataS               : Slv18Array(1 downto 0);
  signal itimingClk            : slv(1 downto 0);
  signal itimingRst            : slv(1 downto 0);

  signal refMarkIntErr, testMarkIntErr : slv(15 downto 0);
  signal refClkRate, testClkRate       : slv(27 downto 0);
  
begin

  loopback <= r.loopback;
  psclk    <= axilClk;
  psen     <= r.psen;
  psincdec <= r.psincdec;
  rxmode   <= r.rxmode;

  U_NCTrigDelay : entity surf.SynchronizerVector
    generic map ( WIDTH_G => nctrigdelay'length )
    port map ( clk     => timingClk(0),
               dataIn  => r.nctrigdelay,
               dataOut => nctrigdelay );
  
  itimingClk  <= timingClk;
  itimingRst  <= timingRst;

  refMark <= fiducial0 when r.rxmode="11" else
             r0.mark;
  test1Hz <= test1HzF when r.rxmode="11" else
             r0.oneHz;
  
  U_SYNC_ONEHZ : entity surf.SynchronizerOneShot
    port map ( clk     => itimingClk(1),
               dataIn  => test1Hz,
               dataOut => test1HzS );
  
  U_FID360 : entity lcls_timing_core.Divider
    generic map ( Width => 9 )
    port map ( sysClk   => itimingClk(0),
               sysReset => itimingRst(0),
               enable   => fiducial0,
               clear    => '1',
               divisor  => toSlv(360,9),
               trigO    => test1HzF );

  testMark <= r1.mark;
  
  U_SYNC_TESTS : entity surf.SynchronizerOneShot
    port map ( clk     => itimingClk(0),
               dataIn  => testMark,
               dataOut => testMarkS );
  
  U_PD : entity work.PhaseDetector
    generic map ( WIDTH_G => WIDTH_C,
                  CKWID_G => CKWID_C,
                  RFDIV_G => 833,
                  TSDIV_G => 2600,
                  DEBUG_G => DEBUG_C )
      port map ( stableClk  => axilClk,
                 refClk     => itimingClk(0),
                 refClkRst  => itimingRst(0),
                 refResync  => refMark,
                 refSync    => open,
                 refMark    => refMark,
                 tmo        => tmo,
                 testMark   => testMarkS,
                 testClk    => itimingClk(1),
                 testClkRst => itimingRst(1),
                 testResync => testMark,
                 testDelay  => x"4",
                 clks       => clks,
                 ready      => ready,
                 ack        => r.ack,
                 phase      => phase,
                 phaseN     => phasen,
                 valid      => valid );

  S_tmo : entity surf.SynchronizerOneShotCnt
    generic map ( CNT_WIDTH_G => 20 )
    port map ( wrClk   => itimingClk(0),
               wrRst   => itimingRst(0),
               dataIn  => tmo,
               rdClk   => axilClk,
               rdRst   => axilRst,
               rollOverEn => '1',
               cntRst  => '0',
               dataOut => open,
               cntOut  => tmoCnt );
               
  S_refMark : entity surf.SynchronizerOneShotCnt
    generic map ( CNT_WIDTH_G => 20 )
    port map ( wrClk   => itimingClk(0),
               wrRst   => itimingRst(0),
               dataIn  => refMark,
               rdClk   => axilClk,
               rdRst   => axilRst,
               rollOverEn => '1',
               cntRst  => '0',
               dataOut => open,
               cntOut  => refMarkCnt );
               
  S_testMark : entity surf.SynchronizerOneShotCnt
    generic map ( CNT_WIDTH_G => 20 )
    port map ( wrClk   => itimingClk(1),
               wrRst   => itimingRst(1),
               dataIn  => testMark,
               rdClk   => axilClk,
               rdRst   => axilRst,
               rollOverEn => '1',
               cntRst  => '0',
               dataOut => open,
               cntOut  => testMarkCnt );

  S_timingRst : entity surf.SynchronizerVector
    generic map ( WIDTH_G => 3 )
    port map ( clk     => axilClk,
               rst     => axilRst,
               dataIn(0) => timingRst(0),
               dataIn(1) => timingRst(1),
               dataIn(2) => txRst0,
               dataOut => timingRstS );

  GEN_TXDATA : for i in 0 to 1 generate
    U_TxData : entity surf.SynchronizerFifo
      generic map ( DATA_WIDTH_G => 18 )
      port map ( rst               => itimingRst(i),
                 wr_clk            => timingClk(i),
                 din(15 downto  0) => txData(i),
                 din(17 downto 16) => txDataK(i),
                 rd_clk            => axilClk,
                 dout              => txDataS(i) );
  end generate;

  U_INT_CHECK0 : entity work.IntervalCheck
    generic map (
      INTERVAL_G    => 1666,
      COUNT_WIDTH_G => refMarkIntErr'length )
    port map (
      clk     => itimingClk(0),
      rst     => itimingRst(0),
      mark    => refMark,
      axilClk => axilClk,
      axilRst => axilRst,
      errCnt  => refMarkIntErr );
  
  U_INT_CHECK1 : entity work.IntervalCheck
    generic map (
      INTERVAL_G    => 2600,
      COUNT_WIDTH_G => testMarkIntErr'length )
    port map (
      clk     => itimingClk(1),
      rst     => itimingRst(1),
      mark    => testMark,
      axilClk => axilClk,
      axilRst => axilRst,
      errCnt  => testMarkIntErr );

  U_CLKFREQ0 : entity surf.SyncClockFreq
    generic map ( REF_CLK_FREQ_G => 125.0E+6,
                  REFRESH_RATE_G => 1.0,
                  COMMON_CLK_G   => true,
                  CNT_WIDTH_G    => 28 )
    port map ( freqOut    => refClkRate,
               clkIn      => itimingClk(0),
               locClk     => axilClk,
               refClk     => axilClk );
  
  U_CLKFREQ1 : entity surf.SyncClockFreq
    generic map ( REF_CLK_FREQ_G => 125.0E+6,
                  REFRESH_RATE_G => 1.0,
                  COMMON_CLK_G   => true,
                  CNT_WIDTH_G    => 28 )
    port map ( freqOut    => testClkRate,
               clkIn      => itimingClk(1),
               locClk     => axilClk,
               refClk     => axilClk );
  
  r0comb : process( r0, itimingRst, timingBus ) is
    variable v   : R0RegType;
  begin
    v := r0;
    v.mark := '0';

    if timingBus(0).strobe = '1' then
      if (timingBus(0).stream.eventCodes(1)='1') then
        v.mark  := '1';
      end if;
    end if;
      
    if itimingRst(0) = '1' then
      v := R0REG_INIT_C;
    end if;

    r0in <= v;
  end process r0comb;

  r0seq: process( itimingClk )
  begin
    if rising_edge(itimingClk(0)) then
      r0 <= r0in;
    end if;
  end process r0seq;

  r1comb : process( r1, itimingRst, timingBus, test1HzS ) is
    variable v   : R1RegType;
  begin
    v := r1;
    v.mark := '0';
    
    if timingBus(1).strobe = '1' then
      if (timingBus(1).message.acRates(5) = '1' and
          timingBus(1).message.acTimeSlot = "001") then
        v.latch := r1.count;
      end if;
      if (timingBus(1).message.fixedRates(5)='1') then
        v.mark  := '1';
        v.count := r1.count+1;
      end if;
    end if;
      
    if test1HzS = '1' then
      v.count := (others=>'0');
    end if;

    if itimingRst(1) = '1' then
      v := R1REG_INIT_C;
    end if;

    r1in <= v;
  end process r1comb;

  r1seq: process( itimingClk )
  begin
    if rising_edge(itimingClk(1)) then
      r1 <= r1in;
    end if;
  end process r1seq;

  U_Test1HzCnt : entity surf.SynchronizerVector
    generic map ( WIDTH_G => test1HzCnt'length )
    port map ( clk     => axilClk,
               dataIn  => r1.latch,
               dataOut => test1HzCnt );
  
  comb: process( r, axilRst, axilWriteMaster, axilReadMaster,
                 ready, phase, phasen, valid, clks,
                 tmoCnt, refMarkCnt, testMarkCnt, test1HzCnt,
                 timingRstS, txDataS,
                 refMarkIntErr, testMarkIntErr,
                 refClkRate, testClkRate) is
    variable regCon   : AxiLiteEndPointType;
    variable v        : RegType;
  begin
    v := r;
    v.ack  := '0';
    v.psen := '0';
    
    -- Determine the transaction type
    axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

    axiSlaveRegisterR(regCon, x"00", 0, ready);
    axiWrDetect(regCon, x"00", v.ack);
    axiSlaveRegisterR(regCon, x"04", 0, phase);
    axiSlaveRegisterR(regCon, x"08", 0, phasen);
    axiSlaveRegisterR(regCon, x"0C", 0, valid);
    axiSlaveRegisterR(regCon, x"10", 0, clks);
    axiSlaveRegisterR(regCon, x"14", 0, tmoCnt);
    axiSlaveRegisterR(regCon, x"18", 0, refMarkCnt);
    axiSlaveRegisterR(regCon, x"1C", 0, testMarkCnt);
    axiSlaveRegisterR(regCon, x"20", 0, test1HzCnt);
    axiSlaveRegisterR(regCon, x"20", 30, timingRstS);
    axiSlaveRegisterR(regCon, x"24", 0, txDataS(0));
    axiSlaveRegisterR(regCon, x"28", 0, txDataS(1));
    axiSlaveRegister (regCon, x"2C", 0, v.psincdec);
    axiWrDetect(regCon, x"2C", v.psen);
    axiSlaveRegister (regCon, x"30", 0, v.loopback(0));
    axiSlaveRegister (regCon, x"34", 0, v.loopback(1));
    axiSlaveRegister (regCon, x"38", 0, v.rxmode);
    axiSlaveRegister (regCon, x"3C", 0, v.nctrigdelay);
    axiSlaveRegisterR(regCon, x"40", 0, refMarkIntErr);
    axiSlaveRegisterR(regCon, x"44", 0, testMarkIntErr);
    axiSlaveRegisterR(regCon, x"48", 0, refClkRate);
    axiSlaveRegisterR(regCon, x"4C", 0, testClkRate);
    
    -- Closeout the transaction
    axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_OK_C);

    if axilRst='1' then
      v := REG_INIT_C;
    end if;
    
    rin <= v;

    -- Outputs
    axilWriteSlave <= r.axilWriteSlave;
    axilReadSlave  <= r.axilReadSlave;
  end process comb;

  seq: process ( axilClk ) is
  begin
    if rising_edge(axilClk) then
      r <= rin;
    end if;
  end process seq;
  
end mapping;
