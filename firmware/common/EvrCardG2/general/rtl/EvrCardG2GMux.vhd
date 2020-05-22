-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2GMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-10
-- Last update: 2018-07-19
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
use surf.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity EvrCardG2GMux is
   generic (
      TPD_G         : time    := 1 ns );
   port (
      -- AxiLite/DRP interface
      axiClk     : in  sl;
      axiRst     : in  sl;
      axiWriteMaster     : in  AxiLiteWriteMasterType;
      axiWriteSlave      : out AxiLiteWriteSlaveType;
      axiReadMaster      : in  AxiLiteReadMasterType;
      axiReadSlave       : out AxiLiteReadSlaveType;
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

  signal drpRdy          : sl;
  signal drpEn           : sl;
  signal drpWe           : sl;
  signal drpUsrRst       : sl;
  signal drpAddr         : slv(8 downto 0);
  signal drpDi           : slv(15 downto 0);
  signal drpDo           : slv(15 downto 0);
  signal mdrpRdy         : slv(1 downto 0);
  signal mdrpEn          : slv(1 downto 0);
  signal mdrpWe          : slv(1 downto 0);
  signal mdrpUsrRst      : slv(1 downto 0);
  signal mdrpAddr        : Slv9Array (1 downto 0);
  signal mdrpDi          : Slv16Array(1 downto 0);
  signal mdrpDo          : Slv16Array(1 downto 0);
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

  evrSel_p : process (evrSel, intEvrRst,
                      intRxLinkUp, intRxError, intRxDspErr, intRxDecErr,
                      intRxData, intRxDataK, intEvrTxRst,
                      mdrpRdy, mdrpDo,
                      txInhibit, drpEn, drpWe, drpUsrRst, drpAddr, drpDi) is
    variable ievrSel : integer;
  begin
    if evrSel = '0' then
      ievrSel := 0;
    else
      ievrSel := 1;
    end if;
    
    evrRst   <= intEvrRst  (ievrSel);
    rxLinkUp <= intRxLinkUp(ievrSel);
    rxError  <= intRxError (ievrSel);
    rxDspErr <= intRxDspErr(ievrSel);
    rxDecErr <= intRxDecErr(ievrSel);
    rxData   <= intRxData  (ievrSel);
    rxDataK  <= intRxDataK (ievrSel);
    evrTxRst <= intEvrTxRst(ievrSel);
    drpRdy   <= mdrpRdy    (ievrSel);
    drpDo    <= mdrpDo     (ievrSel);
    
    intTxInhibit          <= "11";
    intTxInhibit(ievrSel) <= txInhibit;
    mdrpEn                <= "00";
    mdrpEn      (ievrSel) <= drpEn;
    mdrpWe                <= "00";
    mdrpWe      (ievrSel) <= drpWe;
    mdrpUsrRst            <= "00";
    mdrpUsrRst  (ievrSel) <= drpUsrRst;
    mdrpAddr              <= drpAddr & drpAddr;
    mdrpDi                <= drpDi   & drpDi;
  end process;
  
  U_DRP : entity surf.AxiLiteToDrp
    generic map ( COMMON_CLK_G => true,
                  ADDR_WIDTH_G => 9 )
    port map (
      -- AXI-Lite Port
      axilClk         => axiClk,
      axilRst         => axiRst,
      axilReadMaster  => axiReadMaster,
      axilReadSlave   => axiReadSlave,
      axilWriteMaster => axiWriteMaster,
      axilWriteSlave  => axiWriteSlave,
      -- DRP Interface
      drpClk          => axiClk,
      drpRst          => axiRst,
      drpRdy          => drpRdy,
      drpEn           => drpEn,
      drpWe           => drpWe,
      drpUsrRst       => drpUsrRst,
      drpAddr         => drpAddr,
      drpDi           => drpDi,
      drpDo           => drpDo );
     
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
                 txDataK    => txDataK,
                 -- DRP Interface (drpClk Domain)      
                 drpClk     => axiClk,
                 drpRdy     => mdrpRdy (i),
                 drpEn      => mdrpEn  (i),
                 drpWe      => mdrpWe  (i),
                 drpAddr    => mdrpAddr(i),
                 drpDi      => mdrpDi  (i),
                 drpDo      => mdrpDo  (i));
  end generate;
  
end rtl;
