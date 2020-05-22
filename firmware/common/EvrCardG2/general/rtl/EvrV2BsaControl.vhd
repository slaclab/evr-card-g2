-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2BsaControl.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-11-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use lcls_timing_core.EvrV2Pkg.all;

entity EvrV2BsaControl is
  generic (
    TPD_G   : time    := 1ns);
  port (
    evrClk        : in  sl;
    evrRst        : in  sl;
    enable        : in  sl;
    strobeIn      : in  sl;
    dataIn        : in  TimingMessageType;
    dmaData       : out EvrV2DmaDataType );
end EvrV2BsaControl;


architecture mapping of EvrV2BsaControl is

  type BsaReadState is ( IDLR_S, TAG_S,
                         PIDL_S, PIDU_S,
                         TIML_S, TIMU_S,
                         INIL_S, INIU_S,
                         ACTL_S, ACTU_S,
                         AVGL_S, AVGU_S );

  type RegType is record
    state   : BsaReadState;
    dmaData : EvrV2DmaDataType;
  end record;

  constant REG_TYPE_INIT_C : RegType := (
    state   => IDLR_S,
    dmaData => EVRV2_DMA_DATA_INIT_C );
  
  signal r    : RegType := REG_TYPE_INIT_C;
  signal r_in : RegType;

  
begin  -- mapping

  dmaData <= r.dmaData;
  
  process (r, dataIn, strobeIn, evrRst, enable)
    variable v : RegType;
  begin  -- process
    v := r;

    if r.state = IDLR_S then
      v.dmaData.tValid := '0';
    else
      v.dmaData.tValid := '1';
    end if;

    case r.state is
      when IDLR_S => if (strobeIn='1' and enable='1' and uOr(dataIn.bsaInit)='1') then
                       v.state := TAG_S;
                     end if;
      when TAG_S  => v.dmaData.tData := EVRV2_BSA_CONTROL_TAG & x"0000";
                     v.state := PIDL_S;
      when PIDL_S => v.dmaData.tData := dataIn.pulseId(31 downto 0);
                     v.state := PIDU_S;
      when PIDU_S => v.dmaData.tData := dataIn.pulseId(63 downto 32);
                     v.state := TIML_S;
      when TIML_S => v.dmaData.tData := dataIn.timeStamp(31 downto 0);
                     v.state := TIMU_S;
      when TIMU_S => v.dmaData.tData := dataIn.timeStamp(63 downto 32);
                     v.state := INIL_S;
      when INIL_S => v.dmaData.tData := dataIn.bsaInit(31 downto 0);
                     v.state := INIU_S;
      when INIU_S => v.dmaData.tData := dataIn.bsaInit(63 downto 32);
                     v.state := ACTL_S;
      when ACTL_S => v.dmaData.tData := dataIn.bsaInit(31 downto 0) and dataIn.bsaActive(31 downto 0);
                     v.state := ACTU_S;
      when ACTU_S => v.dmaData.tData := dataIn.bsaInit(63 downto 32) and dataIn.bsaActive(63 downto 32);
                     v.state := AVGL_S;
      when AVGL_S => v.dmaData.tData := dataIn.bsaInit(31 downto 0) and dataIn.bsaAvgDone(31 downto 0);
                     v.state := AVGU_S;
      when AVGU_S => v.dmaData.tData := dataIn.bsaInit(63 downto 32) and dataIn.bsaAvgDone(63 downto 32);
                     v.state := IDLR_S;
      when others => null;
    end case;

    if evrRst='1' then
      v := REG_TYPE_INIT_C;
    end if;

    r_in <= v;
  end process;    

  process (evrClk)
  begin  -- process
    if rising_edge(evrClk) then
      r <= r_in;
    end if;
  end process;

end mapping;
