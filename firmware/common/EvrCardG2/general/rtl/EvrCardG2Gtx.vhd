-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Gtx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-10
-- Last update: 2018-08-15
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

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EvrCardG2Gtx is
   generic (
      TPD_G         : time    := 1 ns;
      EVR_VERSION_G : boolean := false);  -- V1 = false, V2 = true      
   port (
      -- EVR Ports
      evrRefClkP : in  sl;
      evrRefClkN : in  sl;
      evrRxP     : in  sl;
      evrRxN     : in  sl;
      evrTxP     : out sl;
      evrTxN     : out sl;
      evrRefClk  : out sl;
      evrRecClk  : out sl;
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
      txDataK    : in  slv(1 downto 0)  := (others=>'0'));
end EvrCardG2Gtx;

architecture rtl of EvrCardG2Gtx is

   constant CPLL_REFCLK_SEL_C : bit_vector := ite(EVR_VERSION_G, "010", "001");
   constant CPLL_FBDIV_C      : integer    := ite(EVR_VERSION_G, 1, 2);
   constant CPLL_FBDIV_45_C   : integer    := 5;
   constant CPLL_REFCLK_DIV_C : integer    := 1;
   constant RXOUT_DIV_C       : integer    := ite(EVR_VERSION_G, 1, 2);
   constant TXOUT_DIV_C       : integer    := ite(EVR_VERSION_G, 1, 2);
   constant RX_CLK25_DIV_C    : integer    := ite(EVR_VERSION_G, 15, 10);
   constant TX_CLK25_DIV_C    : integer    := ite(EVR_VERSION_G, 15, 10);
--   constant RXCDR_CFG_C       : bit_vector := ite(EVR_VERSION_G, x"03000023ff20400020", x"03000023ff40200020");
   --  compensate for sync clock jitter
   constant RXCDR_CFG_C       : bit_vector := ite(EVR_VERSION_G, x"03800023ff10200020", x"03000023ff40200020");
   constant STABLE_CLK_PERIOD_C : real := 4.0E-9;

   signal gtRefClk      : sl;
   signal gtRefClkDiv2  : sl;
   signal stableClk     : sl;
   signal stableRst     : sl;
   signal rxRst         : sl;
   signal gtRxResetDone : sl;
   signal dataValid     : sl;
   signal evrRxRecClk   : sl;
   signal linkUp        : sl;
   signal decErr        : slv(1 downto 0);
   signal dispErr       : slv(1 downto 0);
   signal cnt           : slv(23 downto 0);
   signal gtRxData      : slv(19 downto 0);
   signal data          : slv(15 downto 0);
   signal dataK         : slv(1 downto 0);

   signal txResetDone   : sl;
   signal txOutClk      : sl;
   signal txUsrClk      : sl;

   constant DEBUG_C : boolean := true;

   component ila_0
     port ( clk     : in sl;
            probe0  : in slv(255 downto 0) );
   end component;

begin

  GEN_DEBUG : if DEBUG_C generate
    U_ILA : ila_0
      port map ( clk        => evrRxRecClk,
                 probe0(0)  => rxRst,
                 probe0(1)  => stableRst,
                 probe0(2)  => rxReset,
                 probe0(3)  => gtRxResetDone,
                 probe0(4)  => linkUp,
                 probe0(6 downto 5) => dispErr,
                 probe0(8 downto 7) => decErr,
                 probe0(9)          => dataValid,
                 probe0( 29 downto 10) => gtRxData,
                 probe0( 45 downto 30) => data,
                 probe0( 47 downto 46) => dataK,
                 probe0( 71 downto 48) => cnt,
                 probe0(255 downto 72) => (others=>'0') );
  end generate;
    
   rxError   <= not(dataValid) and linkUp;
   rxDspErr  <= dispErr;
   rxDecErr  <= decErr;
   rxLinkUp  <= linkUp;
   evrClk    <= evrRxRecClk;
   evrRst    <= not(gtRxResetDone);
   evrRefClk <= stableClk;
   evrRecClk <= evrRxRecClk;
   evrTxClk  <= txUsrClk;
   evrTxRst  <= not txResetDone;
   rxRst     <= stableRst or rxReset;
   
   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => evrRefClkP,
         IB    => evrRefClkN,
         CEB   => '0',
         ODIV2 => gtRefClkDiv2,
         O     => gtRefClk);   

   BUFG_Inst : BUFG
      port map (
         I => gtRefClkDiv2,
         O => stableClk);   

   PwrUpRst_Inst : entity work.PwrUpRst
      generic map(
         TPD_G => TPD_G)
      port map (
         clk    => stableClk,
         rstOut => stableRst);            

   Decoder8b10b_Inst : entity work.Decoder8b10b
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
   
  process(evrRxRecClk, gtRxResetDone)
  begin
    if gtRxResetDone = '0' then
      cnt    <= (others => '0') after TPD_G;
      linkUp <= '0'             after TPD_G;
    elsif rising_edge(evrRxRecClk) then
      if cnt = x"0000FF" then
        linkUp <= '1' after TPD_G;
      end if;
      cnt <= cnt + 1 after TPD_G;
    end if;
  end process;

   TxBUFG_Inst : BUFG
      port map (
         I => txOutClk,
         O => txUsrClk);   
   
   Gtx7Core_Inst : entity work.Gtx7Core
      generic map (
         TPD_G                 => TPD_G,
         SIM_GTRESET_SPEEDUP_G => "FALSE",
         SIM_VERSION_G         => "4.0",
         SIMULATION_G          => false,
         STABLE_CLOCK_PERIOD_G => STABLE_CLK_PERIOD_C,
         CPLL_REFCLK_SEL_G     => CPLL_REFCLK_SEL_C,
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
         cPllRefClkIn     => gtRefClk,
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
         txUserResetIn    => stableRst,
         --txResetDoneOut   => open,
         txResetDoneOut   => txResetDone,
         -- Tx Data
         txDataIn         => txData,
         txCharIsKIn      => txDataK,
         txBufStatusOut   => open,
         -- Misc.
         loopbackIn       => (others => '0'),
         txPowerDown      => (others => txInhibit),
         rxPowerDown      => (others => '0'));

end rtl;
