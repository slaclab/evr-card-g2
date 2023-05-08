-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvgAsyncControl.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2023-05-05
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
use surf.AxiStreamPkg.all;
use work.SsiPciePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.EvrV2Pkg.all;
use surf.SsiPkg.all;

library l2si_core;
--use l2si_core.L2SiPkg.all;
--use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

entity EvgAsyncControl is
  generic (
    TPD_G          : time             := 1 ns;
    GEN_L2SI_G     : boolean          := true;
    AXIL_BASEADDR0 : slv(31 downto 0) := x"00060000";
    AXIL_BASEADDR1 : slv(31 downto 0) := x"00080000" );
  port (
    -- AXI-Lite and IRQ Interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axilWriteMaster     : in  AxiLiteWriteMasterType;
    axilWriteSlave      : out AxiLiteWriteSlaveType;
    axilReadMaster      : in  AxiLiteReadMasterType;
    axilReadSlave       : out AxiLiteReadSlaveType;
    -- Registers
    pllReset            : out sl;
    phyReset            : out sl;
    trigger             : out sl;
    triggerCnt          : in  slv(15 downto 0);
    timeStampWr         : out slv(63 downto 0);
    timeStampWrEn       : out sl;
    timeStampRd         : in  slv(63 downto 0);
    eventCodes          : out slv(255 downto 0) );
end EvgAsyncControl;

architecture mapping of EvgAsyncControl is

  type RegType is record
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
    pllReset       : sl;
    phyReset       : sl;
    timeStampRd    : slv(63 downto 0);
    timeStampWr    : slv(63 downto 0);
    timeStampWrEn  : slv( 3 downto 0);
    trigger        : slv( 3 downto 0);
    eventCodes     : slv(255 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    pllReset       => '0',
    phyReset       => '0',
    timeStampRd    => (others=>'0'),
    timeStampWr    => (others=>'0'),
    timeStampWrEn  => (others=>'0'),
    trigger        => (others=>'0'),
    eventCodes     => toSlv(2,256) );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiRst, axilReadMaster, axilWriteMaster, timeStampRd, triggerCnt, r)
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
      variable wrEn   : sl;
      variable rdEn   : sl;
      variable trig   : sl;
   begin
      -- Latch the current value
      v := r;
      v.timeStampWrEn := r.timeStampWrEn(2 downto 0) & '0';
      v.trigger       := r.trigger      (2 downto 0) & '0';
      
      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      wrEn := '0';
      rdEn := '0';
      trig := '0';
      axiWrDetect(axilEp, x"00C", wrEn);
      axiRdDetect(axilEp, x"010", rdEn);
      axiWrDetect(axilEp, x"018", trig );

      v.timeStampWrEn(0) := wrEn;

      if trig = '1' then
        v.trigger     := (others=>'1');
      end if;
      
      if rdEn = '1' then
        v.timeStampRd := timeStampRd;
      end if;

      axiSlaveRegister (axilEp, x"000", 0, v.pllReset );
      axiSlaveRegister (axilEp, x"004", 0, v.phyReset );
      axiSlaveRegister (axilEp, x"008", 0, v.timeStampWr );
      axiSlaveRegisterR(axilEp, x"010", 0, v.timeStampRd );
      axiSlaveRegisterR(axilEp, x"018", 0, triggerCnt );
      axiSlaveRegister (axilEp, x"020", 0, v.eventCodes );

      -- Close the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_OK_C);

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;
      pllReset       <= r.pllReset;
      phyReset       <= r.phyReset;
      timeStampWr    <= r.timeStampWr;
      timeStampWrEn  <= r.timeStampWrEn(3);
      trigger        <= r.trigger(3);
      eventCodes     <= r.eventCodes;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture mapping;
