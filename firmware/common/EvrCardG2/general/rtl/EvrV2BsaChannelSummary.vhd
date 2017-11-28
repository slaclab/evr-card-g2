-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2BsaChannel.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-11-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Integrates the BSA Active and AvgDone bits over a configured interval of
-- timing frames with respect to <evtSelect>.  If another <evtSelect> occurs
-- before the completion of the interval, the partially integrated result is
-- taken.  The <strobeOut> signal indicates validity of the integrated result.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.DspLogicPkg.all;
use work.EvrV2Pkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity EvrV2BsaChannelSummary is
  generic (
    TPD_G : time := 1ns );
  port (
    evrClk        : in  sl;
    evrRst        : in  sl;
    enable        : in  sl;
    evtSelect     : in  slv(15 downto 0);
    strobeIn      : in  sl;
    dataIn        : in  TimingMessageType;
    dmaData       : out EvrV2DmaDataType );
end EvrV2BsaChannelSummary;


architecture mapping of EvrV2BsaChannelSummary is

  type BsaReadState is ( IDLR_S , TAG_S,
                         PIDL_S , PIDU_S,
                         ACTL_S , ACTU_S,
                         AVDL_S , AVDU_S,
                         UTSL_S , UTSU_S,
                         UPDL_S , UPDU_S );
  
  type RegType is record
    rstate        : BsaReadState;
    strobe        : slv(1 downto 0);
    evtSelect     : slv(15 downto 0);
    newDoneOp     : DspLogicOpType;
    newAvgDoneOp  : DspLogicOpType;
    newActiveOp   : DspLogicOpType;
    dmaData       : EvrV2DmaDataType;
  end record;

  constant REG_TYPE_INIT_C : RegType := (
    rstate        => IDLR_S,
    strobe        => (others=>'0'),
    evtSelect     => (others=>'0'),
    newDoneOp     => OP_Clear,
    newAvgDoneOp  => OP_Clear,
    newActiveOp   => OP_Clear,
    dmaData       => EVRV2_DMA_DATA_INIT_C );
  
  signal r    : RegType := REG_TYPE_INIT_C;
  signal rin  : RegType;

  signal newActive    : slv(63 downto 0);
  signal newActiveOr  : sl;
  
  signal newAvgDone   : slv(63 downto 0);
  signal newAvgDoneOr : sl;
  
  signal newDone      : slv(63 downto 0);
  signal newDoneOr    : sl;
  
begin  -- mapping

  dmaData    <= r.dmaData;
  
  U_NewActive : entity work.Logic64b
    generic map ( AREG => 1 )
    port map (  clk   => evrClk,
                op    => r.newActiveOp,
                A     => dataIn.bsaActive,
                B     => (others=>'0'),
                P     => newActive,
                Pnz   => newActiveOr );
  
  U_NewAvgDone : entity work.Logic64b
    generic map ( AREG => 1 )
     port map (  clk   => evrClk,
                 op    => r.newAvgDoneOp,
                 A     => dataIn.bsaAvgDone,
                 B     => (others=>'0'),
                 P     => newAvgDone,
                 Pnz   => newAvgDoneOr );
  
  U_NewDone : entity work.Logic64b
    generic map ( AREG => 1 )
     port map (  clk   => evrClk,
                 op    => r.newDoneOp,
                 A     => dataIn.bsaDone,
                 B     => (others=>'0'),
                 P     => newDone,
                 Pnz   => newDoneOr );

  process (r, strobeIn, enable, evrRst, evtSelect, dataIn,
           newActive, newActiveOr,
           newAvgDone, newAvgDoneOr,
           newDone, newDoneOr )
    variable v : RegType;
  begin  -- process
    v := r;
    v.strobe    := r.strobe(r.strobe'left-1 downto 0) & strobeIn;
    v.evtSelect := r.evtSelect or evtSelect;

    v.newActiveOp   := OP_Hold;
    v.newAvgDoneOp  := OP_Hold;
    v.newDoneOp     := OP_Hold;
    
    if strobeIn='1' then
      if r.evtSelect/=0 then
        v.newActiveOp  := OP_A;
        v.newAvgDoneOp := OP_A;
        v.newDoneOp    := OP_A;
      end if;
    end if;

    -- 2 cycles after strobe
    if r.strobe(1)='1' then
      if (newActiveOr='1' or newAvgDoneOr='1' or newDoneOr='1') then
        v.rstate       := TAG_S;
      end if;
    end if;

    if r.rstate = IDLR_S then
      v.dmaData.tValid := '0';
    else
      v.dmaData.tValid := '1';
    end if;
    
    case r.rstate is
      when TAG_S =>
        v.dmaData.tData := EVRV2_BSA_CHANNEL_TAG & r.evtSelect;
        v.rstate := PIDL_S;
        v.evtSelect := (others=>'0');
      when PIDL_S =>
        v.dmaData.tData  := dataIn.pulseId(31 downto 0);
        v.rstate := PIDU_S;
      when PIDU_S =>
        v.dmaData.tData  := dataIn.pulseId(63 downto 32);
        v.rstate := ACTL_S;
      when ACTL_S =>
        v.dmaData.tData  := newActive(31 downto 0);
        v.rstate := ACTU_S;
      when ACTU_S =>
        v.dmaData.tData  := newActive(63 downto 32);
        v.rstate := AVDL_S;
      when AVDL_S =>
        v.dmaData.tData  := newAvgDone(31 downto 0);
        v.rstate := AVDU_S;
      when AVDU_S =>
        v.dmaData.tData  := newAvgDone(63 downto 32);
        v.rstate := UTSL_S;
      when UTSL_S =>
        v.dmaData.tData  := dataIn.timeStamp(31 downto 0);
        v.rstate := UTSU_S;
      when UTSU_S =>
        v.dmaData.tData  := dataIn.timeStamp(63 downto 32);
        v.rstate := UPDL_S;
      when UPDL_S =>
        v.dmaData.tData  := newDone(31 downto 0);
        v.rstate := UPDU_S;
      when UPDU_S =>
        v.dmaData.tData  := newDone(63 downto 32);
        v.rstate := IDLR_S;
        v.newActiveOp  := OP_Clear;
        v.newAvgDoneOp := OP_Clear;
        v.newDoneOp    := OP_Clear;
      when others => null;
    end case;
    
    if evrRst='1' or enable='0' then
      v := REG_TYPE_INIT_C;
      v.newActiveOp  := OP_Clear;
      v.newAvgDoneOp := OP_Clear;
      v.newDoneOp    := OP_Clear;
    end if;

    rin <= v;
  end process;    

  process (evrClk)
  begin  -- process
    if rising_edge(evrClk) then
      r <= rin;
    end if;
  end process;

end mapping;
