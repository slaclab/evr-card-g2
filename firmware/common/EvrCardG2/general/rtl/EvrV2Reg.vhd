-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2Reg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2023-07-11
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use lcls_timing_core.EvrV2Pkg.all;

entity EvrV2Reg is
  generic (
    TPD_G            : time    := 1 ns;
    DMA_ENABLE_G     : boolean := false;
    DMA_FULL_WIDTH_G : integer := 24);
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
    refEnable           : out sl;
    dmaFullThr          : out slv(DMA_FULL_WIDTH_G-1 downto 0);
    -- status
    irqReq              : in  sl := '0';
    rstCount            : out sl;
    eventCount          : in  slv(31 downto 0);
    partitionAddr       : in  slv(31 downto 0) := (others=>'0');
    dmaCount            : in  slv(23 downto 0) := (others=>'0');
    dmaDrops            : in  slv(23 downto 0) := (others=>'0') );
end EvrV2Reg;

architecture mapping of EvrV2Reg is

  type RegType is record
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
    irqEnable      : sl;
    countReset     : sl;
    refEnable      : sl;
    dmaFullThr     : slv(dmaFullThr'range);
  end record;
  constant REG_INIT_C : RegType := (
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    irqEnable      => '0',
    countReset     => '0',
    refEnable      => '0',
    dmaFullThr     => toSlv(2**dmaFullThr'length-256,dmaFullThr'length) );
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin  -- mapping

  axilReadSlave  <= r.axilReadSlave;
  axilWriteSlave <= r.axilWriteSlave;
  irqEnable      <= r.irqEnable;
  refEnable      <= r.refEnable;
  rstCount       <= r.countReset;
  dmaFullThr     <= r.dmaFullThr;

  process (axiClk)
  begin  -- process
    if rising_edge(axiClk) then
      r <= rin;
    end if;
  end process;

  process (r,axilReadMaster,axilWriteMaster,axiRst,eventCount,irqReq,partitionAddr,dmaCount,dmaDrops)
    variable v  : RegType;
    variable ep : AxiLiteEndPointType;
    variable sReg : slv(0 downto 0);
  begin  -- process
    v  := r;
    sReg(0) := irqReq;
    axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);
    axiSlaveRegister (ep, X"010", 0, v.countReset);
    axiSlaveRegister (ep, X"010", 1, v.refEnable);
    axiSlaveRegisterR(ep, X"014", 0, eventCount);

    if DMA_ENABLE_G then
      axiSlaveRegister (ep, X"000", 0, v.irqEnable);
      axiSlaveRegisterR(ep, X"004", 0, sReg);
      axiSlaveRegisterR(ep, X"008", 0, partitionAddr);
      axiSlaveRegisterR(ep, X"00C", 0, dmaCount);
      axiSlaveRegister (ep, X"018", 0, v.dmaFullThr);
      axiSlaveRegisterR(ep, X"01C", 0, dmaDrops);
    end if;
    
    axilSlaveDefault(AXI_RESP_OK_C);
    rin <= v;
  end process;

end mapping;
