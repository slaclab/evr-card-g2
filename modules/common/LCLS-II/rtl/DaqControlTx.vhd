-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DaqControlTx.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-25
-- Last update: 2016-04-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Programmable configuration and status fields
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

use work.StdRtlPkg.all;
use work.TimingPkg.all;

entity DaqControlTx is
  port (
    txclk    : in  sl;
    txrst    : in  sl;
    rxrst    : in  sl;
    ready    : in  sl;
    data     : out slv(15 downto 0);
    dataK    : out slv( 1 downto 0) );
end DaqControlTx;

architecture rtl of DaqControlTx is

  type TxStateType is (TX_IDLE_S, TX_START_S, TX_FRAME_S, TX_VALID_S, TX_END_S);
  
  constant MAX_IDLE_C : slv(7 downto 0) := x"0F";

  type TxRegType is record
    txState             : TxStateType;
    txClkCnt            : slv(31 downto 0);
    idleCnt             : slv(MAX_IDLE_C'range);
    txData              : slv(15 downto 0);
    txDataK             : slv( 1 downto 0);
    full                : sl;
    fullCnt             : slv(31 downto 0);
    l1pop               : sl;
  end record;

  constant TX_REG_INIT_C : TxRegType := (
    txState             => TX_IDLE_S,
    txClkCnt            => (others=>'0'),
    idleCnt             => (others=>'0'),
    txData              => (D_215_C & K_COM_C),
    txDataK             => "01",
    full                => '0',
    fullCnt             => (others=>'0'),
    l1pop               => '0');

  signal rtx   : TxRegType := TX_REG_INIT_C;
  signal rtxin : TxRegType;

  signal l1strobe :  sl := '0';
  signal l1tag    :  slv(4 downto 0) := (others=>'0');
  signal l1tword  :  slv(8 downto 0) := (others=>'0');
  
  signal full       : sl;
  signal txnotready : sl;
  signal rxnotready : sl;

  signal l1dout   :  slv(13 downto 0);
  signal l1dvalid :  sl;
  
begin

  data   <= rtx.txData;
  dataK  <= rtx.txDataK;

  full   <= rxnotready or txnotready;
  
  Synchronizer_Tx : entity work.Synchronizer
    generic map (
      OUT_POLARITY_G => '0')
    port map (
      clk     => txclk,
      dataIn  => ready,
      dataOut => txnotready);

  Synchronizer_Rx : entity work.Synchronizer
    generic map (
      OUT_POLARITY_G => '1')
    port map (
      clk     => txclk,
      dataIn  => rxrst,
      dataOut => rxnotready);

  Fifo_L1 : entity work.FifoSync
    generic map ( DATA_WIDTH_G => l1tword'length+l1tag'length,
                  ADDR_WIDTH_G => 4 )
    port map    ( clk               => txClk,
                  wr_en             => l1strobe,
                  rd_en             => rtx.l1pop,
                  din(l1tword'left+l1tag'length downto l1tag'length) => l1tword,
                  din(l1tag'left downto 0) => l1tag,
                  dout              => l1dout,
                  valid             => l1dvalid );
                  
  txcomb: process (rtx, full, l1strobe, l1dout, l1dvalid, txrst) is
    variable v : TxRegType;
  begin
    v       := rtx;
    v.l1pop := '0';
    v.txClkCnt := rtx.txClkCnt+1;
    
    case (rtx.txState) is
      when TX_IDLE_S =>
        v.txData  := D_215_C & K_COM_C;
        v.txDataK := "01";
        --
        -- fixme: we can't miss sending on l1strobe
        --        we must guarantee we are in the idle state when l1strobe comes
        --
        if (full/=rtx.full or l1strobe='1' or rtx.idleCnt=MAX_IDLE_C) then
          v.txState := TX_START_S;
        end if;
        v.idleCnt := rtx.idleCnt+1;
      when TX_START_S =>
        v.txData  := D_215_C & K_SOF_C;
        v.txDataK := "01";
        v.txState := TX_FRAME_S;
      when TX_FRAME_S =>
        if (full='1') then
          v.fullCnt := rtx.fullCnt+1;
        end if;
        v.full    := full;
        if (l1dvalid='1') then
          v.l1pop   := '1';
          v.txData  := full & l1dvalid & l1dout;
        else
          v.txData  := full & "000" & x"000";
        end if;
        v.txDataK := "00";
        v.txState := TX_VALID_S;
      when TX_VALID_S =>
        if (full='1') then
          v.txData  := x"FFFF";
        else
          v.txData  := x"EEEE";
        end if;
        v.txDataK := "00";
        v.txState := TX_END_S;
      when TX_END_S =>
        v.txData  := D_215_C & K_EOF_C;
        v.txDataK := "01";
        v.txState := TX_IDLE_S;
        v.idleCnt := (others=>'0');
      when others => null;
    end case;

    if (txrst='1') then
      v := TX_REG_INIT_C;
    end if;
    
    rtxin <= v;

  end process txcomb;

  txseq : process (txClk) is
  begin
    if (rising_edge(txClk)) then
      rtx <= rtxin;
    end if;
  end process txseq;

end rtl;
