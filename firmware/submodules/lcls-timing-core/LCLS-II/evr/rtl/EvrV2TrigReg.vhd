-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2TrigReg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-04-07
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
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.EvrV2Pkg.all;

entity EvrV2TrigReg is
  generic (
    TPD_G      : time    := 1 ns;
    TRIGGERS_C : integer := 1;
    USE_TAP_C  : boolean := false );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    -- configuration
    triggerConfig       : out EvrV2TriggerConfigArray(TRIGGERS_C-1 downto 0);
    delay_rd            : in  Slv6Array(TRIGGERS_C-1 downto 0) := (others=>"000000") );
end EvrV2TrigReg;

architecture mapping of EvrV2TrigReg is

  type RegType is record
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
    triggerConfig  : EvrV2TriggerConfigArray(TRIGGERS_C-1 downto 0);
    loadShift      : Slv4Array(TRIGGERS_C-1 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    triggerConfig  => (others=>EVRV2_TRIGGER_CONFIG_INIT_C),
    loadShift      => (others=>(others=>'0')) );
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin  -- mapping

  triggerConfig  <= r.triggerConfig;
  axilReadSlave  <= r.axilReadSlave;
  axilWriteSlave <= r.axilWriteSlave;

  process (axiClk)
  begin  -- process
    if rising_edge(axiClk) then
      r <= rin;
    end if;
  end process;

  process (r,axilReadMaster,axilWriteMaster,axiRst,delay_rd)
    variable v : RegType;
    variable axilStatus : AxiLiteStatusType;
    procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv) is
    begin
      axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg);
    end procedure;
    procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
    begin
      axiSlaveRegister(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, addr, offset, reg);
    end procedure;
    procedure axilSlaveDefault (
      axilResp : in slv(1 downto 0)) is
    begin
      axiSlaveDefault(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus, axilResp);
    end procedure;
  begin  -- process
    v  := r;
    axiSlaveWaitTxn(axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave, axilStatus);

    for i in 0 to TRIGGERS_C-1 loop
      axilSlaveRegisterW(slv(conv_unsigned(512+i*16,12)),   0, v.triggerConfig(i).channel);
      axilSlaveRegisterW(slv(conv_unsigned(512+i*16,12)),  16, v.triggerConfig(i).polarity);
      axilSlaveRegisterW(slv(conv_unsigned(512+i*16,12)),  31, v.triggerConfig(i).enabled);
      axilSlaveRegisterW(slv(conv_unsigned(516+i*16,12)),   0, v.triggerConfig(i).delay);
      axilSlaveRegisterW(slv(conv_unsigned(520+i*16,12)),   0, v.triggerConfig(i).width);

      if USE_TAP_C then
        --  Special handling of delay tap
        v.triggerConfig(i).loadTap := r.loadShift(i)(3);
        v.loadShift(i) := r.loadShift(i)(2 downto 0) & '0';
        if (axilStatus.readEnable = '1') then
          if (std_match(axilReadMaster.araddr(11 downto 0), toSlv(524+i*16,12))) then
            v.axilReadSlave.rdata(31 downto 6) := (others=>'0');
            v.axilReadSlave.rdata( 5 downto 0) := delay_rd(i);
            axiSlaveReadResponse(v.axilReadSlave);
          end if;
        end if;

        if (axilStatus.writeEnable = '1') then
          if (std_match(axilWriteMaster.awaddr(11 downto 0), toSlv(524+i*16,12))) then
            v.triggerConfig(i).delayTap := axilWriteMaster.wdata(5 downto 0);
            axiSlaveWriteResponse(v.axilWriteSlave);
            v.loadShift(i)(0) := '1';
          end if;
        end if;
      end if;
      
    end loop;   -- i
    axilSlaveDefault(AXI_RESP_OK_C);
    rin <= v;
  end process;

end mapping;
