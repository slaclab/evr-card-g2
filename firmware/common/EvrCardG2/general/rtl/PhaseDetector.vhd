-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PhaseDetector.vhd
-- Author     : Matt Weaver
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-12-14
-- Last update: 2023-06-19
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Interface to sensor link MGT
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 XPM Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 XPM Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;


entity PhaseDetector is
  generic ( WIDTH_G : integer := 27;
            CKWID_G : integer := 12;
            RFDIV_G : integer := 10;
            TSDIV_G : integer := 20;
            DEBUG_G : boolean := false );
  port (
    stableClk      : in  sl;
    latch          : in  sl := '0';
    refClk         : in  sl;
    refClkRst      : in  sl;
    refResync      : in  sl;
    refMark        : in  sl;
    testMark       : in  sl;
    refSync        : out sl;
    tmo            : out sl;
    testClk        : in  sl;
    testClkRst     : in  sl;
    testResync     : in  sl;
    testDelay      : in  slv( 3 downto 0);
    clks           : out slv(CKWID_G-1 downto 0);
    ready          : out sl;
    phase          : out slv(WIDTH_G-1 downto 0);
    phasen         : out slv(WIDTH_G-1 downto 0);
    valid          : out slv(WIDTH_G-1 downto 0) );
end PhaseDetector;

architecture rtl of PhaseDetector is

  type RegType is record
    early  : slv(WIDTH_G-1 downto 0);
    late   : slv(WIDTH_G-1 downto 0);
    phase  : slv(WIDTH_G-1 downto 0);
    phasen : slv(WIDTH_G-1 downto 0);
    valid  : slv(WIDTH_G-1 downto 0);
    ready  : sl;
  end record;

  constant REG_INIT_C : RegType := (
    early  => (others=>'0'),
    late   => (others=>'0'),
    phase  => (others=>'0'),
    phasen => (others=>'0'),
    valid  => (others=>'0'),
    ready  => '0' );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal q   : RegType := REG_INIT_C;
  signal qin : RegType;

  type CRegType is record
    tmo   : sl;
    clks  : slv(clks'range);
    latch : slv(clks'range);
    latched : sl;
  end record;

  constant CREG_INIT_C : CRegType := (
    tmo   => '0',
    clks  => (others=>'0'),
    latch => (others=>'0'),
    latched => '1' );

  signal cr   : CRegType := CREG_INIT_C;
  signal crin : CRegType;
  
  signal testDelayS  : slv(testDelay'range);
  signal refS, testS : sl;
  
  signal clk   : sl;
  signal clki  : sl;
  signal a,b,c : sl;
  signal axorb : sl;
  signal bxorc : sl;
  signal early : sl;
  signal late  : sl;

  signal clkn  : sl;
  signal bn,cn  : sl;
  signal axorbn : sl;
  signal bxorcn : sl;
  signal earlyn : sl;
  signal laten  : sl;

  signal validi, valido, refValid, testValid : sl;
  signal refMarkS : sl;

  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;
  
begin

  assert (RFDIV_G > 1) report "RFDIV_G must be at least 2" severity failure;
  assert (TSDIV_G > 1) report "TSDIV_G must be at least 2" severity failure;
  
  GEN_DBUG : if DEBUG_G generate
    U_ILA_REF : ila_0
      port map ( clk                                  => refClk,
                 probe0(0)                            => testMark,
                 probe0(1)                            => refMark,
                 probe0(2)                            => clk,
                 probe0(3)                            => refResync,
                 probe0(4)                            => cr.tmo,
                 probe0(4+CKWID_G   downto 5)         => cr.clks,
                 probe0(4+CKWID_G*2 downto 5+CKWID_G) => cr.latch,
                 probe0(255 downto 5+CKWID_G*2)       => (others=>'0') );
    U_ILA_STB : ila_0
      port map ( clk                                    => stableClk,
                 probe0(0)                              => early,
                 probe0(1)                              => late,
                 probe0(2)                              => valido,
                 probe0(2+WIDTH_G   downto 3)           => r.early,
                 probe0(2+WIDTH_G*2 downto 3+WIDTH_G)   => r.late,
                 probe0(2+WIDTH_G*3 downto 3+WIDTH_G*2) => r.valid,
                 probe0(255 downto 3+WIDTH_G*3)         => (others=>'0') );
  end generate;
  
  U_BUFG : BUFG
    port map ( I => clki,
               O => clk );

  process (refClk) is
  begin
    if rising_edge(refClk) then
      refS <= refResync;
    end if;
  end process;

  U_SYNC_DELAY : entity surf.SynchronizerVector
    generic map ( WIDTH_G => testDelay'length )
    port map ( clk     => testClk,
               dataIn  => testDelay,
               dataOut => testDelayS );

  process (testClk) is
    variable tS : slv(15 downto 0);
  begin
    if rising_edge(testClk) then
      tS := '0' & tS(tS'left downto 1);
      if testResync = '1' then
        tS(conv_integer(testDelayS)) := '1';
      end if;
      testS <= tS(0);
    end if;
  end process;

  --
  --  Divide the clocks so they have a harmonic relationship
  --  freq_a = 1/2 freq_clk
  U_REFCLK : entity work.ResyncClock
    generic map ( DIVISOR_G => RFDIV_G )
    port map ( refClk    => refClk,
               refClkRst => refClkRst,
               resync    => refS,
               valid     => refValid,
               sync      => refSync,
               clkOut    => clki,
               clkO90    => clkn );

  U_TSTCLK : entity work.ResyncClock
    generic map ( DIVISOR_G => TSDIV_G )
    port map ( refClk    => testClk,
               refClkRst => testClkRst,
               resync    => testS,
               valid     => testValid,
               clkOut    => a );

  cseq : process ( clk ) is
  begin
    if rising_edge(clk) then
      b  <= a;
    end if;
    if falling_edge(clk) then
      c  <= b;
    end if;
  end process;

  cnseq : process ( clkn ) is
  begin
    if rising_edge(clkn) then
      bn <= a;
    end if;
    if falling_edge(clkn) then
      cn <= bn;
    end if;
  end process;
  
  axorb  <= a xor b;
  bxorc  <= b xor c;
  axorbn <= a  xor bn;
  bxorcn <= bn xor cn;
  
  validi <= refValid and testValid;
  
  U_SYNC_EARLY : entity surf.Synchronizer
    generic map ( TPD_G => 0 ns )
    port map ( clk     => stableClk,
               dataIn  => axorb,
               dataOut => early );
  
  U_SYNC_LATE : entity surf.Synchronizer
    generic map ( TPD_G => 0 ns )
    port map ( clk     => stableClk,
               dataIn  => bxorc,
               dataOut => late );
  
  U_SYNC_EARLYN : entity surf.Synchronizer
    generic map ( TPD_G => 0 ns )
    port map ( clk     => stableClk,
               dataIn  => axorbn,
               dataOut => earlyn );
  
  U_SYNC_LATEN : entity surf.Synchronizer
    generic map ( TPD_G => 0 ns )
    port map ( clk     => stableClk,
               dataIn  => bxorcn,
               dataOut => laten );
  
  U_SYNC_VALID : entity surf.Synchronizer
    generic map ( TPD_G => 0 ns )
    port map ( clk     => stableClk,
               dataIn  => validi,
               dataOut => valido );

  U_REFMARK_S : entity surf.SynchronizerOneShot
    port map ( clk     => stableClk,
               dataIn  => refMark,
               dataOut => refMarkS );
  
  comb : process ( r, q, latch, early, late, earlyn, laten, valido, refMarkS ) is
    variable v : RegType;
    variable w : RegType;
  begin
    v := r;
    w := q;

    if r.ready = '1' then
      if early = '1' then
        v.early := r.early+1;
      end if;
      if late = '1' then
        v.late := r.late+1;
      end if;
      if    early ='1' and late = '0' then
        v.phase := r.phase-1;
      elsif early ='0' and late = '1' then
        v.phase := r.phase+1;
      end if;

      if    earlyn ='1' and laten = '0' then
        v.phasen := r.phasen-1;
      elsif earlyn ='0' and laten = '1' then
        v.phasen := r.phasen+1;
      end if;
      v.valid := r.valid+1;
    end if;

    if v.ready = '0' and valido = '1' and refMarkS = '1' then
      v.ready := '1';
    end if;
    
    w.ready := '0';
    if r.valid(r.valid'left) = '1' and refMarkS = '1' then
      v := REG_INIT_C;
      w := r;
      w.ready := '1';
    end if;

    rin <= v;
    qin <= w;

    phase  <= q.phase;
    phasen <= q.phasen;
    valid  <= q.valid;
    ready  <= q.ready;
  end process;

  seq : process (stableClk) is
  begin
    if rising_edge(stableClk) then
      r <= rin;
      q <= qin;
    end if;
  end process;

  combcr : process ( cr, refMark, testMark ) is
    variable v : CRegType;
  begin
    v := cr;

    v.tmo  := '0';
    v.clks := cr.clks+1;
    
    if testMark = '1' and cr.latched = '0' then
      v.latch := cr.clks;
      v.latched := '1';
    end if;
    
    if refMark = '1' then
      v.clks := (others=>'0');
      v.latched := '0';
    end if;

    if uAnd(cr.clks) = '1' and cr.latched = '0' then
      v.tmo  := '1';
    end if;
    
    crin <= v;

    clks <= cr.latch;
    tmo  <= cr.tmo;
  end process combcr;
  
  seqcr : process (refClk) is
  begin
    if rising_edge(refClk) then
      cr <= crin;
    end if;
  end process seqcr;
                          
end rtl;
