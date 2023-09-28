-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2BsaChannel.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2023-09-27
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


library surf;
use surf.StdRtlPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use work.DspLogicPkg.all;
use lcls_timing_core.EvrV2Pkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity EvrV2BsaChannelDSP is
  generic (
    TPD_G : time := 1ns;
    CHAN_G  : integer := 0;
    DEBUG_G : boolean := false );
  port (
    evrClk        : in  sl;
    evrRst        : in  sl;
    channelConfig : in  EvrV2ChannelConfig;
    evtSelect     : in  sl;                  -- latch event
    strobeIn      : in  sl;                  -- process and push to DMA
    dataIn        : in  TimingMessageType;
    dmaData       : out EvrV2DmaDataType );
end EvrV2BsaChannelDSP;


architecture mapping of EvrV2BsaChannelDSP is

  type BsaIntState is (IDLE_S, DELAY_S, INTEG_S);
  type BsaReadState is ( IDLR_S , TAG_S,
                         PIDL_S , PIDU_S,
                         ACTL_S , ACTU_S,
                         AVDL_S , AVDU_S,
                         UTSL_S , UTSU_S,
                         UPDL_S , UPDU_S );
  
  type RegType is record
    state : BsaIntState;
    rstate : BsaReadState;
    addra : slv( 8 downto 0);
    addrb : slv( 8 downto 0);
    count : slv(19 downto 0);
    phase       : slv(2 downto 0);
    strobe      : sl;
    evtSelect   : sl;
    ramen       : sl;
    pulseId     : slv(63 downto 0); -- last pulseId for Active
    apulseId    : slv(63 downto 0); -- last pulseId for AvgDone
    timeStamp   : slv(63 downto 0); -- timestamp for Done/Update
    pendAvgDoneOp : DspLogicOpType;
    pendActiveOp  : DspLogicOpType;
    pendDoneOp    : DspLogicOpType;
    newDoneOp     : DspLogicOpType;
    newAvgDoneOp  : DspLogicOpType;
    newActiveOp   : DspLogicOpType;
--    pendActive  : slv(63 downto 0); -- mask of EDEFs gone active
--    pendAvgDone : slv(63 downto 0); -- mask of EDEFs awaiting AvgDone
--    pendDone    : slv(63 downto 0); -- mask of EDEFs awaiting Done/Update
--    newActive   : slv(63 downto 0); -- mask of EDEFs just gone active
--    newAvgDone  : slv(63 downto 0);
--    newDone     : slv(63 downto 0);
--    newActiveOr : sl;
--    newAvgDoneOr: sl;
--    newDoneOr   : sl;
    dmaData     : EvrV2DmaDataType;
  end record;

  constant REG_TYPE_INIT_C : RegType := (
    state  => IDLE_S,
    rstate => IDLR_S,
    addra  => (others=>'0'),
    addrb  => (others=>'0'),
    count  => (others=>'0'),
    phase  => (others=>'0'),
    strobe => '0',
    evtSelect  => '0',
    ramen  => '0',
    pulseId     => (others=>'0'),
    apulseId    => (others=>'0'),
    timeStamp   => (others=>'0'),
    pendAvgDoneOp => OP_Clear,
    pendActiveOp  => OP_Clear,
    pendDoneOp    => OP_Clear,
    newDoneOp     => OP_Clear,
    newAvgDoneOp  => OP_Clear,
    newActiveOp   => OP_Clear,
--    pendActive  => (others=>'0'),
--    pendAvgDone => (others=>'0'),
--    pendDone    => (others=>'0'),
--    newActive   => (others=>'0'),
--    newAvgDone  => (others=>'0'),
--    newDone     => (others=>'0'),
--    newActiveOr => '0',
--    newAvgDoneOr=> '0',
--    newDoneOr   => '0',
    dmaData     => EVRV2_DMA_DATA_INIT_C );
  
  signal r    : RegType := REG_TYPE_INIT_C;
  signal rin  : RegType;

  signal frame, frameIn, frameOut : slv(63 downto 0);

  signal newActive    : slv(63 downto 0);
  signal newActiveOr  : sl;
  
  signal newAvgDone   : slv(63 downto 0);
  signal newAvgDoneOr : sl;
  
  signal newDone      : slv(63 downto 0);
  signal newDoneOr    : sl;
  
  signal pendDone     : slv(63 downto 0);
  signal pendAvgDone  : slv(63 downto 0);
  signal pendActive   : slv(63 downto 0);
  
  component ila_0
    port ( clk : in sl;
           probe0 : in slv(255 downto 0) );
  end component;

  signal r_state  : slv(1 downto 0);
  signal r_rstate : slv(3 downto 0);
  
begin  -- mapping

  GEN_DBUG : if DEBUG_G generate
    r_state <= "00" when r.state = IDLE_S else
               "01" when r.state = DELAY_S else
               "10";
    r_rstate <= x"0" when r.rstate = IDLR_S else
                x"1" when r.rstate = TAG_S else
                x"2" when r.rstate = PIDL_S else
                x"3" when r.rstate = PIDU_S else
                x"4" when r.rstate = ACTL_S else
                x"5" when r.rstate = ACTU_S else
                x"6" when r.rstate = AVDL_S else
                x"7" when r.rstate = AVDU_S else
                x"8" when r.rstate = UTSL_S else
                x"9" when r.rstate = UTSU_S else
                x"A" when r.rstate = UPDL_S else
                x"B" when r.rstate = UPDU_S else
                x"F";
    U_ILA : ila_0
      port map ( clk         => evrClk,
                 probe0(1 downto 0) => r_state,
                 probe0(5 downto 2) => r_rstate,
                 probe0(14 downto 6) => r.addra,
                 probe0(23 downto 15) => r.addrb,
                 probe0(43 downto 24) => r.count,
                 probe0(46 downto 44) => r.phase,
                 probe0(47)           => r.strobe,
                 probe0(48)           => r.evtSelect,
                 probe0(60 downto 49) => r.pulseId    (11 downto 0),
                 probe0(64 downto 61) =>   pendActive (19 downto 16),
                 probe0(68 downto 65) =>   pendAvgDone(19 downto 16),
                 probe0(72 downto 69) =>   newActive  (19 downto 16),
                 probe0(76 downto 73) =>   newAvgDone (19 downto 16),
                 probe0(80 downto 77) =>   newDone    (19 downto 16),
                 probe0(81)           =>   newActiveOr,
                 probe0(82)           =>   newAvgDoneOr,
                 probe0(83)           =>   newDoneOr,
                 probe0(84)           => evtSelect,
                 probe0(85)           => strobeIn,
                 probe0(149 downto 86) => frame,
                 probe0(255 downto 150) => (others=>'0') );
  end generate;
  
  dmaData    <= r.dmaData;
  
  frameIn    <= dataIn.bsaActive  when r.phase="000" else
                dataIn.pulseId    when r.phase="001" else
                dataIn.bsaAvgDone when r.phase="010" else
                dataIn.timeStamp  when r.phase="011" else
                dataIn.bsaDone;
  
  frame      <= frameIn when allBits(channelConfig.bsaActiveSetup,'0') else
                frameOut;

  -- Could save half of the BRAM by instrumenting as double wide SinglePort
  U_Pipeline : entity surf.SimpleDualPortRam
    generic map ( TPD_G        => TPD_G,
                  DATA_WIDTH_G => 64,
                  ADDR_WIDTH_G => 9 )
    port map    ( clka         => evrClk,
                  ena          => '1',
                  wea          => rin.ramen,
                  addra        => r.addra,
                  dina         => frameIn,
                  clkb         => evrClk,
                  enb          => '1',
                  addrb        => r.addrb,
                  doutb        => frameOut );

  U_NewActive : entity work.Logic64b
    generic map ( AREG => 1 )
    port map (  clk   => evrClk,
                op    => r.newActiveOp,
                A     => frame,
                B     => pendActive,
                P     => newActive,
                Pnz   => newActiveOr );
  
  U_NewAvgDone : entity work.Logic64b
    generic map ( AREG => 1 )
     port map (  clk   => evrClk,
                 op    => r.newAvgDoneOp,
                 A     => frame,
                 B     => pendAvgDone,
                 P     => newAvgDone,
                 Pnz   => newAvgDoneOr );
  
  U_NewDone : entity work.Logic64b
    generic map ( AREG => 1 )
     port map (  clk   => evrClk,
                 op    => r.newDoneOp,
                 A     => frame,
                 B     => pendDone,
                 P     => newDone,
                 Pnz   => newDoneOr );

  U_PendDone : entity work.Logic64b 
    generic map ( BREG => 1 )
     port map (  clk   => evrClk,
                 op    => r.pendDoneOp,
                 A     => newAvgDone,
                 B     => frame,
                 P     => pendDone );
  
  U_PendAvgDone : entity work.Logic64b
    generic map ( BREG => 1 )
     port map (  clk   => evrClk,
                 op    => r.pendAvgDoneOp,
                 A     => newActive,
                 B     => frame,
                 P     => pendAvgDone );

  U_PendActive : entity work.Logic64b
     port map (  clk   => evrClk,
                 op    => r.pendActiveOp,
                 A     => newActive,
                 P     => pendActive );

  process (r, frame, strobeIn, channelConfig, dataIn, evrRst, evtSelect,
           newActive, newActiveOr,
           newAvgDone, newAvgDoneOr,
           newDone, newDoneOr,
           pendDone, pendAvgDone, pendActive )
    variable v : RegType;
    variable pendActiveClear : sl;
  begin  -- process
    v := r;
    v.strobe    := strobeIn;
    if evtSelect = '1' then
      v.evtSelect := '1';
    end if;

    pendActiveClear := '0';
    v.newActiveOp   := OP_Hold;
    v.newAvgDoneOp  := OP_Hold;
    v.newDoneOp     := OP_Hold;
    v.pendActiveOp  := OP_Hold;
    v.pendAvgDoneOp := OP_Hold;
    v.pendDoneOp    := OP_Hold;
    
    if r.phase/="000" then
      v.phase := r.phase+1;
    else
      v.ramen := '0';
    end if;

    if strobeIn='1' or r.addrb(2 downto 0)/="000" then
      v.addrb := r.addrb+1;
    end if;
    
    v.addra := r.addrb+(channelConfig.bsaActiveSetup & "000");

    if r.strobe='1' then
      v.count := r.count+1;
      v.phase := r.phase+1;
      v.ramen := '1';
      v.evtSelect := '0';
      
      -- premature termination
      if r.evtSelect='1' then
        if channelConfig.bsaActiveDelay=x"00000" then
          v.state := INTEG_S;
          pendActiveClear   := '1';
          v.pendActiveOp    := OP_Clear;
        else
          v.state := DELAY_S;
        end if;
        v.count := x"00001";
      elsif r.state=DELAY_S then
        if r.count=channelConfig.bsaActiveDelay then
          v.state := INTEG_S;
          v.count := x"00001";
          pendActiveClear   := '1';
          v.pendActiveOp    := OP_Clear;
        end if;
      elsif r.state=INTEG_S then
        if r.count=channelConfig.bsaActiveWidth then
          v.state := IDLE_S;
        end if;
      end if;
    end if;

    if v.ramen='1' then
      case r.phase is
        when "000" =>
          if v.state=INTEG_S then
            if pendActiveClear = '1' then
              v.newActiveOp   := OP_A;
            else
              v.newActiveOp   := OP_AandNotB;
            end if;
          end if;
        when "001" =>
          if r.state=INTEG_S then
            v.pendAvgDoneOp := OP_OrA;
          end if;
          v.pendActiveOp:= OP_OrA;
          v.pulseId       := frame;
        when "010" =>
          v.newAvgDoneOp  := OP_AandB;
          v.pendAvgDoneOp := OP_AndNotB;
        when "011" =>
          v.pendDoneOp  := OP_OrA;
          v.timeStamp   := frame;
        when "100" =>
          v.newDoneOp   := OP_AandB;
          v.pendDoneOp  := OP_AndNotB;
        when others => null;
      end case;
    end if;

    -- 8 cycles after strobe
    if r.ramen='1' and r.phase="000" and r.rstate=IDLR_S then 
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
        v.dmaData.tData         := EVRV2_BSA_CHANNEL_TAG & toSlv(0,16);
        v.dmaData.tData(CHAN_G) := '1';
        v.rstate := PIDL_S;
      when PIDL_S =>
        v.dmaData.tData  := r.pulseId(31 downto 0);
        v.rstate := PIDU_S;
      when PIDU_S =>
        v.dmaData.tData  := r.pulseId(63 downto 32);
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
        v.dmaData.tData  := r.timeStamp(31 downto 0);
        v.rstate := UTSU_S;
      when UTSU_S =>
        v.dmaData.tData  := r.timeStamp(63 downto 32);
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
    
    if evrRst='1' or channelConfig.bsaEnabled='0' then
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
