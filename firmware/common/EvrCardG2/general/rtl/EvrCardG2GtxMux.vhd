-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2GtxMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-10
-- Last update: 2017-03-08
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
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EvrCardG2GtxMux is
   generic (
      TPD_G         : time    := 1 ns );
   port (
      -- AxiLite/DRP interface
      axiClk     : in  sl;
      axiRst     : in  sl;
      evrSel     : in  sl := '0';  -- LCLS/LCLS-II
      -- EVR Ports
      evrRefClkP : in  slv(1 downto 0);
      evrRefClkN : in  slv(1 downto 0);
      evrRxP     : in  sl;
      evrRxN     : in  sl;
      evrTxP     : out sl;
      evrTxN     : out sl;
      -- EVR Interface
      rxReset    : in  sl := '0';
      rxPolarity : in  sl := '0';
      evrClk     : out sl;
      evrRst     : out sl;
      rxLinkUp   : out sl;
      rxError    : out sl;
      rxDspErr   : out slv(1 downto 0);
      rxDecErr   : out slv(1 downto 0);
      rxData     : out slv(15 downto 0);
      rxDataK    : out slv(1 downto 0);
      evrTxClk   : out sl;
      evrTxRst   : out sl;
      txInhibit  : in  sl := '1';
      txData     : in  slv(15 downto 0) := (others=>'0');
      txDataK    : in  slv( 1 downto 0) := (others=>'0'));
end EvrCardG2GtxMux;

architecture rtl of EvrCardG2GtxMux is

--   constant CPLL_REFCLK_SEL_C : bit_vector := "001"; -- LCLS-II = "010"
   constant CPLL_FBDIV_C      : integer    := 2; -- LCLS-II = 1
   constant CPLL_FBDIV_45_C   : integer    := 5;
   constant CPLL_REFCLK_DIV_C : integer    := 1;
   constant RXOUT_DIV_C       : integer    := 2; -- LCLS-II = 1
   constant TXOUT_DIV_C       : integer    := 2; -- LCLS-II = 1
   constant RX_CLK25_DIV_C    : integer    := 10; -- LCLS-II = 15
   constant TX_CLK25_DIV_C    : integer    := 10; -- LCLS-II = 15
   --  compensate for sync clock jitter
   constant RXCDR_CFG_C       : bit_vector := x"03000023ff40200020"; -- LCLS
--   constant RXCDR_CFG_C       : bit_vector := x"03000023ff10200020"; -- LCLS-II
   constant STABLE_CLK_PERIOD_C : real := 4.0E-9;

   signal gtRefClk      : slv(1 downto 0);
   signal gtRefClkDiv2  : slv(1 downto 0);
   signal stableClk     : sl;
   signal stableRst     : sl;
   signal rxRst         : sl;
   signal txRst         : sl;
   signal gtRxResetDone : sl;
   signal dataValid     : sl;
   signal evrRxRecClk   : sl;
   signal linkUp        : sl;
   signal decErr        : slv(1 downto 0);
   signal dispErr       : slv(1 downto 0);
   signal cnt           : slv(7 downto 0);
   signal gtRxData      : slv(19 downto 0);
   signal data          : slv(15 downto 0);
   signal dataK         : slv(1 downto 0);

   signal txResetDone   : sl;
   signal txOutClk      : sl;
   signal txUsrClk      : sl;

   signal drpRdy  : sl;

   constant NDRP_PROG : integer := 5;

   -- LCLS GTX settings
   constant DRP0_PROG : Slv25Array(0 to NDRP_PROG-1) := (
     (toSlv(169,9) & x"4020"),
     (toSlv( 17,9) & x"1A74"),
     (toSlv( 94,9) & x"1080"),
     (toSlv(106,9) & x"0009"),
     (toSlv(136,9) & x"0011") );

   -- LCLS-II GTX settings
   constant DRP1_PROG : Slv25Array(0 to NDRP_PROG-1) := (
     (toSlv(169,9) & x"1020"),
     (toSlv( 17,9) & x"1BB4"),
     (toSlv( 94,9) & x"10C0"),
     (toSlv(106,9) & x"000E"),
     (toSlv(136,9) & x"0000") );
   
   type RegType is record
     evrSel  : sl;
     cpllSel : slv(2 downto 0);
     pllRst  : sl;
     idle    : sl;
     iprog   : integer range 0 to NDRP_PROG;
     drpWe   : sl;
     drpAddr : slv( 8 downto 0);
     drpDi   : slv(15 downto 0);
   end record;
   constant REG_INIT_C : RegType := (
     evrSel  => '0',
     cpllSel => "001",
     pllRst  => '0',
     idle    => '0',
     iprog   => 0,
     drpWe   => '0',
     drpAddr => (others=>'0'),
     drpDi   => (others=>'0') );

   signal r    : RegType := REG_INIT_C;
   signal r_in : RegType;
begin

   rxError   <= not(dataValid) and linkUp;
   rxDspErr  <= dispErr;
   rxDecErr  <= decErr;
   rxLinkUp  <= linkUp;
   evrClk    <= evrRxRecClk;
   evrRst    <= not(gtRxResetDone);
   evrTxClk  <= txUsrClk;
   evrTxRst  <= not txResetDone;
   rxRst     <= stableRst or rxReset or r.pllRst;
   txRst     <= stableRst or r.pllRst;

   GEN_GTREF : for i in 0 to 1 generate
     IBUFDS_GTE2_Inst : IBUFDS_GTE2
       port map (
         I     => evrRefClkP(i),
         IB    => evrRefClkN(i),
         CEB   => '0',
         ODIV2 => gtRefClkDiv2(i),
         O     => gtRefClk(i));   
   end generate;
   
   BUFG_Inst : BUFG
      port map (
         I => gtRefClkDiv2(0),
         O => stableClk);   

   PwrUpRst_Inst : entity surf.PwrUpRst
      generic map(
         TPD_G => TPD_G)
      port map (
         clk    => stableClk,
         rstOut => stableRst);            

   Decoder8b10b_Inst : entity surf.Decoder8b10b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '0',         -- Active low polarity
         NUM_BYTES_G    => 2)
      port map (
         clk      => evrRxRecClk,
         rst      => gtRxResetDone,
         dataIn   => gtRxData,
         dataOut  => data,
         dataKOut => dataK,
         codeErr  => decErr,
         dispErr  => dispErr);

   rxData    <= data  when(linkUp = '1') else (others => '0');
   rxDataK   <= dataK when(linkUp = '1') else (others => '0');
   dataValid <= not (uOr(decErr) or uOr(dispErr));
   
   process(evrRxRecClk)
   begin
      if rising_edge(evrRxRecClk) then
         if gtRxResetDone = '0' then
            cnt    <= (others => '0') after TPD_G;
            linkUp <= '0'             after TPD_G;
         else
            if cnt = x"FF" then
               linkUp <= '1' after TPD_G;
            else
               cnt <= cnt + 1 after TPD_G;
            end if;
         end if;
      end if;
   end process;

   TxBUFG_Inst : BUFG
      port map (
         I => txOutClk,
         O => txUsrClk);   
   
   Gtx7Core_Inst : entity work.Gtx7CoreAdv
      generic map (
         TPD_G                 => TPD_G,
         SIM_GTRESET_SPEEDUP_G => "FALSE",
         SIM_VERSION_G         => "4.0",
         SIMULATION_G          => false,
         STABLE_CLOCK_PERIOD_G => STABLE_CLK_PERIOD_C,
--         CPLL_REFCLK_SEL_G     => CPLL_REFCLK_SEL_C,
         CPLL_FBDIV_G          => CPLL_FBDIV_C,
         CPLL_FBDIV_45_G       => CPLL_FBDIV_45_C,
         CPLL_REFCLK_DIV_G     => CPLL_REFCLK_DIV_C,
         RXOUT_DIV_G           => RXOUT_DIV_C,
         TXOUT_DIV_G           => TXOUT_DIV_C,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_C,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_C,
         TX_PLL_G              => "CPLL",
         RX_PLL_G              => "CPLL",
         TX_EXT_DATA_WIDTH_G   => 16,
         TX_INT_DATA_WIDTH_G   => 20,
         TX_8B10B_EN_G         => true,
         RX_EXT_DATA_WIDTH_G   => 20,
         RX_INT_DATA_WIDTH_G   => 20,
         RX_8B10B_EN_G         => false,
         TX_BUF_EN_G           => false,
         TX_OUTCLK_SRC_G       => "OUTCLKPMA",
         TX_DLY_BYPASS_G       => '1',
         TX_PHASE_ALIGN_G      => "NONE",
         RX_BUF_EN_G           => false,
         RX_OUTCLK_SRC_G       => "OUTCLKPMA",
         RX_USRCLK_SRC_G       => "RXOUTCLK",
         RX_DLY_BYPASS_G       => '1',
         RX_DDIEN_G            => '1',
         RX_ALIGN_MODE_G       => "FIXED_LAT",
         RX_DFE_KL_CFG2_G      => X"301148AC",
         RX_OS_CFG_G           => "0000010000000",
         RXCDR_CFG_G           => RXCDR_CFG_C,
         RXDFEXYDEN_G          => '1',
         RX_EQUALIZER_G        => "DFE",
         RXSLIDE_MODE_G        => "PMA",
         FIXED_COMMA_EN_G      => "0011",
         FIXED_ALIGN_COMMA_0_G => "----------0101111100",  -- Normal Comma
         FIXED_ALIGN_COMMA_1_G => "----------1010000011",  -- Inverted Comma
         FIXED_ALIGN_COMMA_2_G => "XXXXXXXXXXXXXXXXXXXX",  -- Unused
         FIXED_ALIGN_COMMA_3_G => "XXXXXXXXXXXXXXXXXXXX")  -- Unused         
      port map (
         stableClkIn      => stableClk,
         gtRefClk0        => gtRefClk(0),
         gtRefClk1        => gtRefClk(1),
         cpllRefClkSel    => r.cpllSel,
         cPllLockOut      => open,
         qPllRefClkIn     => '0',
         qPllClkIn        => '0',
         qPllLockIn       => '1',
         qPllRefClkLostIn => '0',
         qPllResetOut     => open,
         gtRxRefClkBufg   => stableClk,
         -- Serial IO
         gtTxP            => evrTxP,
         gtTxN            => evrTxN,
         gtRxP            => evrRxP,
         gtRxN            => evrRxN,
         -- Rx Clock related signals
         rxOutClkOut      => evrRxRecClk,
         rxUsrClkIn       => evrRxRecClk,
         rxUsrClk2In      => evrRxRecClk,
         rxUserRdyOut     => open,
         rxMmcmResetOut   => open,
         rxMmcmLockedIn   => '1',
         -- Rx User Reset Signals
         rxUserResetIn    => rxRst,
         rxResetDoneOut   => gtRxResetDone,
         -- Manual Comma Align signals
         rxDataValidIn    => dataValid,
         rxSlideIn        => '0',
         -- Rx Data and decode signals
         rxDataOut        => gtRxData,
         rxCharIsKOut     => open,
         rxDecErrOut      => open,
         rxDispErrOut     => open,
         rxPolarityIn     => rxPolarity,
         rxBufStatusOut   => open,
         -- Rx Channel Bonding
         rxChBondLevelIn  => (others => '0'),
         rxChBondIn       => (others => '0'),
         rxChBondOut      => open,
         -- Tx Clock Related Signals
         txOutClkOut      => txOutClk,
         txUsrClkIn       => txUsrClk,
         txUsrClk2In      => txUsrClk,
         txUserRdyOut     => open,
         txMmcmResetOut   => open,
         txMmcmLockedIn   => '1',
         -- Tx User Reset signals
         txUserResetIn    => txRst,
         --txResetDoneOut   => open,
         txResetDoneOut   => txResetDone,
         -- Tx Data
         txDataIn         => txData,
         txCharIsKIn      => txDataK,
         txBufStatusOut   => open,
         -- Misc.
         loopbackIn       => (others => '0'),
         txPowerDown      => (others => txInhibit),
         rxPowerDown      => (others => '0'),
         -- DRP Interface
         drpClk           => axiClk,
         drpRdy           => drpRdy,
         drpEn            => r.drpWe,
         drpWe            => r.drpWe,
         drpAddr          => r.drpAddr,
         drpDi            => r.drpDi,
         drpDo            => open );

  process( r, axiRst, drpRdy, evrSel ) is
    variable v : RegType;
    variable i : integer;
  begin
    v := r;
    v.pllRst := '0';
    v.drpWe  := '0';

    if r.idle = '0' then
      if drpRdy = '1' then
        v.iprog   := r.iprog+1;
        if r.iprog = NDRP_PROG then
          v.pllRst := '1';
          v.idle   := '1';
        elsif r.iprog = NDRP_PROG-1 then
          if r.evrSel='0' then
            v.cpllSel := "001";
          else
            v.cpllSel := "010";
          end if;
        else
          if r.evrSel='0' then
            v.drpDi   := DRP0_PROG(r.iprog)(15 downto 0);
            v.drpAddr := DRP0_PROG(r.iprog)(24 downto 16);
          else
            v.drpDi   := DRP1_PROG(r.iprog)(15 downto 0);
            v.drpAddr := DRP1_PROG(r.iprog)(24 downto 16);
          end if;
          v.drpWe   := '1';
        end if;
      end if;
    elsif evrSel /= r.evrSel then
      v.evrSel := evrSel;
      v.idle   := '0';
      v.iprog  := 0;
    end if;

    if axiRst = '1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process;

  process (axiClk) is
  begin
    if rising_edge(axiClk) then
      r <= r_in;
    end if;
  end process;
   
end rtl;
