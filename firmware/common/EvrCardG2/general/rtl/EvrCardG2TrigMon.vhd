-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2TrigMon.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2024-05-02
-- Last update: 2024-05-02
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

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity EvrCardG2TrigMon is
   generic (
      TPD_G           : time    := 1 ns;
      AXIL_BASEADDR_G : slv(31 downto 0) := x"00000000");
   port (
     -- AXI-Lite Interface
     axilClk             : in  sl;
     axilRst             : in  sl;
     axilWriteMaster     : in  AxiLiteWriteMasterType;
     axilWriteSlave      : out AxiLiteWriteSlaveType;
     axilReadMaster      : in  AxiLiteReadMasterType;
     axilReadSlave       : out AxiLiteReadSlaveType;
      -- Clock
      evrRecClk          : in  sl;
      evrRecRst          : in  sl;
      -- Trigger Inputs
      trig               : in  slv(11 downto 0) );
end EvrCardG2TrigMon;

architecture mapping of EvrCardG2TrigMon is

  type AxilRegType is record
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
    countReset     : sl;
  end record;
  constant AXIL_REG_INIT_C : AxilRegType := (
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    countReset     => '0' );
  
  signal a   : AxilRegType := AXIL_REG_INIT_C;
  signal ain : AxilRegType;

  signal trigCouple : slv(trig'range);
  signal periodMin  : Slv32Array(trig'range);
  signal periodMax  : Slv32Array(trig'range);

begin

  GEN_TRIG : for i in trig'range generate

    trigCouple(i) <= trig(trig'left) or trig(i);
    
    U_TRIG : entity surf.SyncTrigPeriod
      generic map (
        TPD_G         => TPD_G )
      port map (
        -- Trigger Input (trigClk domain)
        trigClk   => evrRecClk,
        trigRst   => evrRecRst,
        trigIn    => trigCouple(i),
        -- Trigger Period Output (locClk domain)
        locClk    => axilClk,
        locRst    => axilRst,
        resetStat => a.countReset,
        period    => open,
        periodMax => periodMax(i),
        periodMin => periodMin(i) );
  end generate GEN_TRIG;

  comb : process ( axilRst, a, axilWriteMaster, axilReadMaster,
                   periodMin, periodMax ) is
    variable v  : AxilRegType;
    variable ep : AxiLiteEndPoint;
  begin
    v := a;

    axiSlaveWaitTxn(ep, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);
    axiSlaveRegister (ep, X"000", 0, v.countReset);
    for i in trig'range loop
      axiSlaveRegister (ep, toSlv(8*i+ 8,12), 0, periodMin(i));
      axiSlaveRegister (ep, toSlv(8*i+12,12), 0, periodMax(i));
    end loop;
    axiSlaveDefault(ep, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_OK_C);

    if axilRst = '1' then
      v := AXIL_REG_INIT_C;
    end if;
    
    ain <= v;

    axilWriteSlave  <= a.axilWriteSlave;
    axilReadSlave   <= a.axilReadSlave;
  end process comb;
  
  seq : process (axilClk)
  begin  -- process
    if rising_edge(axilClk) then
      a <= ain;
    end if;
  end process seq;
 
end mapping;
