-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2Reg.vhd
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
use ieee.NUMERIC_STD.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.TimingPkg.all;
use work.EvrV2Pkg.all;

entity EvrV2Reg is
  generic (
    TPD_G        : time    := 1 ns;
    DMA_ENABLE_G : boolean := false );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    -- configuration
    irqEnable           : out sl;
    trigSel             : out sl;
    dmaFullThr          : out slv(23 downto 0);
    -- status
    irqReq              : in  sl := '0';
    partitionAddr       : in  slv(PADDR_LEN-1 downto 0) := (others=>'0');
    rstCount            : out sl;
    eventCount          : in  slv(31 downto 0);
    gtxDebug            : in  slv(7 downto 0) := (others=>'0') );
end EvrV2Reg;

architecture mapping of EvrV2Reg is

  type RegType is record
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
    irqEnable      : sl;
    countReset     : sl;
    trigSel        : sl;
    dmaFullThr     : slv(23 downto 0);
  end record;
  constant REG_INIT_C : RegType := (
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    irqEnable      => '0',
    countReset     => '0',
    trigSel        => '0',
    dmaFullThr     => (others=>'1') );
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin  -- mapping

  axilReadSlave  <= r.axilReadSlave;
  axilWriteSlave <= r.axilWriteSlave;
  irqEnable      <= r.irqEnable;
  trigSel        <= r.trigSel;
  rstCount       <= r.countReset;
  dmaFullThr     <= r.dmaFullThr;

  process (axiClk)
  begin  -- process
    if rising_edge(axiClk) then
      r <= rin;
    end if;
  end process;

  process (r,axilReadMaster,axilWriteMaster,axiRst,gtxDebug,eventCount,irqReq,partitionAddr)
    variable v  : RegType;
    variable ep : AxiLiteEndPointType;
    variable sReg : slv(0 downto 0);

    procedure axilSlaveRegisterR (addr : in slv; reg : in slv) is
    begin
      axiSlaveRegisterR(ep, addr, 0, reg);
    end procedure;
    procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout slv) is
    begin
      axiSlaveRegister(ep, addr, offset, reg);
    end procedure;
    procedure axilSlaveRegisterW (addr : in slv; offset : in integer; reg : inout sl) is
    begin
      axiSlaveRegister(ep, addr, offset, reg);
    end procedure;
    procedure axilSlaveDefault (
      axilResp : in slv(1 downto 0)) is
    begin
      axiSlaveDefault(ep, v.axilWriteSlave, v.axilReadSlave, axilResp);
    end procedure;
  begin  -- process
    v  := r;
    sReg(0) := irqReq;
    axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);
    axilSlaveRegisterW(X"010", 0, v.countReset);
    axilSlaveRegisterR(X"014", eventCount);

    if DMA_ENABLE_G then
      axilSlaveRegisterW(X"000", 0, v.irqEnable);
      axilSlaveRegisterR(X"004", sReg);
      axilSlaveRegisterR(X"008", partitionAddr);
      axilSlaveRegisterR(X"00C", gtxDebug);
      axilSlaveRegisterW(X"018", 0, v.dmaFullThr);
    end if;
    
    axilSlaveDefault(AXI_RESP_OK_C);
    rin <= v;
  end process;

end mapping;
