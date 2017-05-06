-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2GMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-10
-- Last update: 2017-03-09
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

entity EvrCardG2GMux is
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
      evrRxP     : in  slv(1 downto 0);
      evrRxN     : in  slv(1 downto 0);
      evrTxP     : out slv(1 downto 0);
      evrTxN     : out slv(1 downto 0);
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
end EvrCardG2GMux;

architecture rtl of EvrCardG2GMux is

  signal intEvrRefClk : slv(1 downto 0);
  signal intEvrClk    : slv(1 downto 0);
  signal intEvrRst    : slv(1 downto 0);
  signal intRxLinkUp  : slv(1 downto 0);
  signal intRxError   : slv(1 downto 0);
  signal intRxDspErr  : Slv2Array (1 downto 0);
  signal intRxDecErr  : Slv2Array (1 downto 0);
  signal intRxData    : Slv16Array(1 downto 0);
  signal intRxDataK   : Slv2Array (1 downto 0);
  signal intEvrTxClk  : slv(1 downto 0);
  signal intEvrTxRst  : slv(1 downto 0);
  signal intTxInhibit : slv(1 downto 0);
  signal nevrSel      : sl;
  signal crst, crst0, crst1 : sl;
  signal evrClkFbO, evrClkFbI, evrClkI : sl;
  signal evrTxClkFbO, evrTxClkFbI, evrTxClkI : sl;
  signal evrLocked, evrTxLocked : sl;
begin

  nevrSel <= not evrSel;
  
  U_EVRCLKMUX : MMCME2_ADV
     generic map ( CLKFBOUT_MULT_F      => 6.0,
                   CLKFBOUT_USE_FINE_PS => true,
                   CLKIN1_PERIOD        => 8.4,
                   CLKIN2_PERIOD        => 5.6,
                   CLKOUT0_DIVIDE_F     => 6.0 )
     port map ( CLKFBOUT   => evrClkFbO,
                CLKOUT0    => evrClkI,
                LOCKED     => evrLocked,
                CLKFBIN    => evrClkFbI,
                CLKIN1     => intEvrClk(0),
                CLKIN2     => intEvrClk(1),
                CLKINSEL   => nevrSel,
                DADDR      => (others=>'0'),
                DCLK       => '0',
                DEN        => '0',
                DI         => (others=>'0'),
                DWE        => '0',
                PSCLK      => '0',
                PSEN       => '0',
                PSINCDEC   => '0',
                PWRDWN     => '0',
                RST        => crst );
                   
  U_EVRCLKBUFG : BUFG
   port map (
     O  => evrClk,
     I  => evrClkI );

  U_EVRCLKFBBUFG : BUFG
   port map (
     O  => evrClkFbI,
     I  => evrClkFbO );

  U_EVRTXCLKMUX : MMCME2_ADV
     generic map ( CLKFBOUT_MULT_F      => 6.0,
                   CLKFBOUT_USE_FINE_PS => true,
                   CLKIN1_PERIOD        => 8.4,
                   CLKIN2_PERIOD        => 5.6,
                   CLKOUT0_DIVIDE_F     => 6.0 )
     port map ( CLKFBOUT   => evrTxClkFbO,
                CLKOUT0    => evrTxClkI,
                LOCKED     => evrTxLocked,
                CLKFBIN    => evrTxClkFbI,
                CLKIN1     => intEvrTxClk(0),
                CLKIN2     => intEvrTxClk(1),
                CLKINSEL   => nevrSel,
                DADDR      => (others=>'0'),
                DCLK       => '0',
                DEN        => '0',
                DI         => (others=>'0'),
                DWE        => '0',
                PSCLK      => '0',
                PSEN       => '0',
                PSINCDEC   => '0',
                PWRDWN     => '0',
                RST        => crst );

  U_EVRTXCLKBUFG : BUFG
    port map    ( O  => evrTxClk,
                  I  => evrTxClkI );
    
  U_EVRTXCLKFBBUFG : BUFG
    port map    ( O  => evrTxClkFbI,
                  I  => evrTxClkFbO );

  seq: process (intEvrRefClk) is
     variable v : slv(10 downto 0) := (others=>'1');
   begin
     crst <= v(0);
     if rising_edge(intEvrRefClk(1)) then
       if (crst0='1' or crst1='1') then
         v := (others=>'1');
       else
         v := '0' & v(10 downto 1);
       end if;
     end if;
   end process seq;

  evrRst   <= intEvrRst(0) when evrSel='0' else
              intEvrRst(1);
  
  rxLinkUp <= intRxLinkUp(0) when evrSel='0' else
              intRxLinkUp(1);

  rxError  <= intRxError(0) when evrSel='0' else
              intRxError(1);

  rxDspErr <= intRxDspErr(0) when evrSel='0' else
              intRxDspErr(1);

  rxDecErr <= intRxDecErr(0) when evrSel='0' else
              intRxDecErr(1);

  rxData   <= intRxData(0) when evrSel='0' else
              intRxData(1);

  rxDataK  <= intRxDataK(0) when evrSel='0' else
              intRxDataK(1);

  evrTxRst <= intEvrTxRst(0) when evrSel='0' else
              intEvrTxRst(1);

  intTxInhibit(0) <= txInhibit when evrSel='0' else '1';
  intTxInhibit(1) <= txInhibit when evrSel='1' else '1';
  
  GEN_GTX : for i in 0 to 1 generate
    U_Gtx : entity work.EvrCardG2Gtx
      generic map ( EVR_VERSION_G => i>0 )
   port map ( evrRefClkP => evrRefClkP(i),
              evrRefClkN => evrRefClkN(i),
              evrRxP     => evrRxP(i),
              evrRxN     => evrRxN(i),
              evrTxP     => evrTxP(i),
              evrTxN     => evrTxN(i),
              evrRefClk  => intEvrRefClk(i),
              evrRecClk  => open,
              -- EVR Interface
              rxReset    => rxReset,
              rxPolarity => rxPolarity,
              evrClk     => intEvrClk(i),
              evrRst     => intEvrRst(i),
              rxLinkUp   => intRxLinkUp(i),
              rxError    => intRxError(i),
              rxDspErr   => intRxDspErr(i),
              rxDecErr   => intRxDecErr(i),
              rxData     => intRxData(i),
              rxDataK    => intRxDataK(i),
              evrTxClk   => intEvrTxClk(i),
              evrTxRst   => intEvrTxRst(i),
              txInhibit  => intTxInhibit(i),
              txData     => txData,
              txDataK    => txDataK );
  end generate;
  
end rtl;
