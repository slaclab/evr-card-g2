-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Gtx.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-10
-- Last update: 2015-09-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
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
      evrClk     : out sl;
      evrRst     : out sl;
      rxLinkUp   : out sl;
      rxError    : out sl;
      rxData     : out slv(15 downto 0);
      rxDataK    : out slv(1 downto 0));
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
   constant RXCDR_CFG_C       : bit_vector := ite(EVR_VERSION_G, x"03000023ff20400020", x"03000023ff40200020");

   signal gtRefClk      : sl;
   signal gtRefClkDiv2  : sl;
   signal stableClk     : sl;
   signal stableRst     : sl;
   signal gtRxResetDone : sl;
   signal dataValid     : sl;
   signal evrRxRecClk   : sl;
   signal linkUp        : sl;
   signal decErr        : slv(1 downto 0);
   signal dispErr       : slv(1 downto 0);
   signal cnt           : slv(7 downto 0);
   signal gtRxData      : slv(19 downto 0);
   
begin

   rxError   <= not(dataValid) and linkUp;
   rxLinkUp  <= linkUp;
   evrClk    <= evrRxRecClk;
   evrRst    <= not(gtRxResetDone);
   evrRefClk <= stableClk;
   evrRecClk <= evrRxRecClk;

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
         dataOut  => rxData,
         dataKOut => rxDataK,
         codeErr  => decErr,
         dispErr  => dispErr);

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

   Gtx7Core_Inst : entity work.Gtx7Core
      generic map (
         TPD_G                 => TPD_G,
         SIM_GTRESET_SPEEDUP_G => "FALSE",
         SIM_VERSION_G         => "4.0",
         SIMULATION_G          => false,
         STABLE_CLOCK_PERIOD_G => 4.0E-9,
         CPLL_REFCLK_SEL_G     => CPLL_REFCLK_SEL_C,
         CPLL_FBDIV_G          => CPLL_FBDIV_C,
         CPLL_FBDIV_45_G       => CPLL_FBDIV_45_C,
         CPLL_REFCLK_DIV_G     => CPLL_REFCLK_DIV_C,
         RXOUT_DIV_G           => RXOUT_DIV_C,
         TXOUT_DIV_G           => TXOUT_DIV_C,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_C,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_C,
         TX_PLL_G              => "QPLL",
         RX_PLL_G              => "CPLL",
         TX_EXT_DATA_WIDTH_G   => 16,
         TX_INT_DATA_WIDTH_G   => 20,
         TX_8B10B_EN_G         => true,
         RX_EXT_DATA_WIDTH_G   => 20,
         RX_INT_DATA_WIDTH_G   => 20,
         RX_8B10B_EN_G         => false,
         TX_BUF_EN_G           => false,
         TX_OUTCLK_SRC_G       => "PLLREFCLK",
         TX_DLY_BYPASS_G       => '0',
         TX_PHASE_ALIGN_G      => "MANUAL",
         RX_BUF_EN_G           => false,
         RX_OUTCLK_SRC_G       => "OUTCLKPMA",
         RX_USRCLK_SRC_G       => "RXOUTCLK",
         RX_DLY_BYPASS_G       => '1',
         RX_DDIEN_G            => '0',
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
         rxUserResetIn    => stableRst,
         rxResetDoneOut   => gtRxResetDone,
         -- Manual Comma Align signals
         rxDataValidIn    => dataValid,
         rxSlideIn        => '0',
         -- Rx Data and decode signals
         rxDataOut        => gtRxData,
         rxCharIsKOut     => open,
         rxDecErrOut      => open,
         rxDispErrOut     => open,
         rxPolarityIn     => '0',
         rxBufStatusOut   => open,
         -- Rx Channel Bonding
         rxChBondLevelIn  => (others => '0'),
         rxChBondIn       => (others => '0'),
         rxChBondOut      => open,
         -- Tx Clock Related Signals
         txOutClkOut      => open,
         txUsrClkIn       => '0',
         txUsrClk2In      => '0',
         txUserRdyOut     => open,
         txMmcmResetOut   => open,
         txMmcmLockedIn   => '1',
         -- Tx User Reset signals
         txUserResetIn    => '0',
         txResetDoneOut   => open,
         -- Tx Data
         txDataIn         => (others => '0'),
         txCharIsKIn      => (others => '0'),
         txBufStatusOut   => open,
         -- Misc.
         loopbackIn       => (others => '0'),
         txPowerDown      => (others => '1'),
         rxPowerDown      => (others => '0'));         

end rtl;
