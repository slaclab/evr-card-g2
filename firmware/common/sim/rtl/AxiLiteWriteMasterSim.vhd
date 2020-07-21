-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : AxiLiteSimPkg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-25
-- Last update: 2018-12-28
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use work.AxiLiteSimPkg.all;

entity AxiLiteWriteMasterSim is
  generic ( CMDS : AxiLiteWriteCmdArray );
  port ( clk    : in sl;
         rst    : in  sl;
         master : out AxiLiteWriteMasterType;
         slave  : in  AxiLiteWriteSlaveType;
         done   : out sl );
end entity;

architecture behavior of AxiLiteWriteMasterSim is

  type RegType is record
    icmd : integer;
    master : AxiLiteWriteMasterType;
  end record;
  constant REG_INIT_C : RegType := (
    icmd => 0,
    master => AXI_LITE_WRITE_MASTER_INIT_C
    );
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
begin

  comb : process ( r, rst, slave ) is
    variable v : RegType;
  begin
    v := r;

    if slave.awready = '1' then
      v.master.awvalid := '0';
    end if;

    if slave.wready = '1' then
      v.master.wvalid := '0';
    end if;

    if slave.bvalid = '1' then
      v.master.bready := '0';
    end if;

    if v.master.bready = '0' and r.icmd < CMDS'length then
      v.master.awaddr  := CMDS(r.icmd).addr;
      v.master.awvalid := '1';
      v.master.wdata   := CMDS(r.icmd).value;
      v.master.wvalid  := '1';
      v.master.bready  := '1';
      v.icmd           := r.icmd + 1;
    end if;

    if rst = '1' then
      v := REG_INIT_C;
      v.master.bready := '0';
    end if;

    master <= r.master;
--    master.bready <= rin.master.bready;

    if (r.icmd = CMDS'length and v.master.bready = '0') then
      done   <= '1';
    else
      done   <= '0';
    end if;
    
    rin <= v;
  end process comb;

  seq : process(clk) is
  begin
    if rising_edge(clk) then
      r <= rin;
    end if;
  end process seq;
  
end behavior;
