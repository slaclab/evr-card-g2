-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : XPMPkg.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-03-25
-- Last update: 2017-04-09
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

use work.StdRtlPkg.all;
use work.TimingPkg.all;

package XpmPkg is

   -----------------------------------------------------------
   -- Application: Configurations, Constants and Records Types
   -----------------------------------------------------------
   constant NAmcs       : integer := 2;
   constant NDSLinks    : integer := 14;
   constant NBPLinks    : integer := 14;
   constant NPartitions : integer := 8;
   constant NTagBytes   : integer := 4;
   constant NL1Triggers : integer := 1;
   
   --type XpmRxSerialType is record
   --   stream    : TimingSerialType;
   --   advance   : sl;
   --   fiducial  : sl;
   --end record;
   --constant XPM_RX_SERIAL_INIT_C : XpmRxSerialType := (
   --   stream    => TIMING_SERIAL_INIT_C,
   --   advance   => '0',
   --   fiducial  => '0' );

   type XpmTxSerialType is record
      data      : slv(15 downto 0);
      dataK     : slv( 1 downto 0);
      sof       : sl;
      eof       : sl;
      addr      : sl;
      valid     : sl;
   end record;
   constant XPM_TX_SERIAL_INIT_C : XpmTxSerialType := (
      data      => (others=>'0'),
      dataK     => (others=>'0'),
      sof       => '0',
      eof       => '0',
      addr      => '0',
      valid     => '0' );

   --  Status of AMC Card jitter cleaner PLL
   type XpmPllStatusType is record
     lol        : sl;
     los        : sl;
   end record;
   constant XPM_PLL_STATUS_INIT_C : XpmPllStatusType := ( lol => '1', los => '1' );
   type XpmPllStatusArray is array(natural range<>) of XpmPllStatusType;

   --  Status of downstream links
   type XpmLinkStatusType is record
      txResetDone : sl;  -- Downstream link transmit initialization status
      txReady     : sl;
      rxResetDone : sl;  -- Downstream link receive initialization status
      rxReady     : sl;
      rxErr       : sl;
      rxErrCnts   : slv(15 downto 0);
      rxIsXpm     : sl;
   end record;
   type XpmLinkStatusArray is array (natural range<>) of XpmLinkStatusType;
   constant XPM_LINK_STATUS_INIT_C : XpmLinkStatusType := (
      txResetDone => '0',
      txReady     => '0',
      rxResetDone => '0',
      rxReady     => '0',
      rxErr       => '0',
      rxErrCnts   => (others=>'0'),
      rxIsXpm     => '0' );

   --
   --  Partition status
   --
   --    L0 Inhibit
   type XpmInhibitStatusType is record
      counts  : Slv32Array(31 downto 0);
   end record;
   constant XPM_INHIBIT_STATUS_INIT_C : XpmInhibitStatusType := (
      counts  => (others=>(others=>'0')) );
   
   --    L0 Selection
   type XpmL0SelectStatusType is record
      enabled     : slv(63 downto 0);
      inhibited   : slv(63 downto 0);
      num         : slv(63 downto 0);
      numInh      : slv(63 downto 0);
      numAcc      : slv(63 downto 0);
   end record;
   type XpmL0SelectStatusArray is array(natural range<>) of XpmL0SelectStatusType;
   constant XPM_L0_SELECT_STATUS_INIT_C : XpmL0SelectStatusType := (
      enabled     => (others=>'0'),
      inhibited   => (others=>'0'),
      num         => (others=>'0'),
      numInh      => (others=>'0'),
      numAcc      => (others=>'0'));

   type XpmL1SelectStatusType is record
      numAcc      : slv(63 downto 0);
   end record;
   constant XPM_L1_SELECT_STATUS_INIT_C : XpmL1SelectStatusType := (
      numAcc      => (others=>'0'));
   
   type XpmPartitionStatusType is record
      inhibit    : XpmInhibitStatusType;
      l0Select   : XpmL0SelectStatusType;
      l1Select   : XpmL1SelectStatusType;
      anaRd      : slv(NTagBytes-1 downto 0);
   end record;
   constant XPM_PARTITION_STATUS_INIT_C : XpmPartitionStatusType := (
      inhibit    => XPM_INHIBIT_STATUS_INIT_C,
      l0Select   => XPM_L0_SELECT_STATUS_INIT_C,
      l1Select   => XPM_L1_SELECT_STATUS_INIT_C,
      anaRd      => (others=>'0') );
   type XpmPartitionStatusArray is array(natural range<>) of XpmPartitionStatusType;
   
   type XpmStatusType is record
      dsLink    : XpmLinkStatusArray(NDSLinks-1 downto 0);
      bpLinkUp  : slv               (NBPLinks downto 0);
      partition : XpmPartitionStatusArray(NPartitions-1 downto 0);
      paddr     : slv(PADDR_LEN-1 downto 0);
   end record;

   constant XPM_STATUS_INIT_C : XpmStatusType := (
      dsLink    => (others => XPM_LINK_STATUS_INIT_C),
      bpLinkUp  => (others => '0'),
      partition => (others => XPM_PARTITION_STATUS_INIT_C),
      paddr     => (others => '1'));

   type XpmPllConfigType is record
     bwSel      : slv(3 downto 0);
     frqTbl     : slv(1 downto 0);
     frqSel     : slv(7 downto 0);
     rate       : slv(3 downto 0);
     sfOut      : slv(3 downto 0);
     inc        : sl;
     dec        : sl;
     bypass     : sl;
     rstn       : sl;
   end record;
   constant XPM_PLL_CONFIG_INIT_C : XpmPllConfigType := (
     bwSel      => "0111",
     frqTbl     => "10",
     frqSel     => "01101001",
     rate       => "1010",
     sfOut      => "0110",
     inc        => '0',
     dec        => '0',
     bypass     => '0',
     rstn       => '1' );
   type XpmPllConfigArray is array(natural range<>) of XpmPllConfigType;
   
   type XpmLinkConfigType is record
     enable     : sl;
     loopback   : sl;
     txReset    : sl;
     rxReset    : sl;
     txDelayRst : sl;
     txDelay    : slv(19 downto 0);
     partition  : slv( 3 downto 0);
     trigsrc    : slv( 3 downto 0);
   end record;
   type XpmLinkConfigArray is array (natural range<>) of XpmLinkConfigType;
   constant XPM_LINK_CONFIG_INIT_C : XpmLinkConfigType := (
     enable     => '0',
     loopback   => '1',
     txReset    => '0',
     rxReset    => '0',
     txDelayRst => '0',
     txDelay    => (others=>'0'),
     partition  => (others=>'0'),
     trigsrc    => (others=>'0') );
   type XpmL0SelectConfigType is record
      reset            : sl;
      enabled          : sl;
      -- EventSelection
      rateSel          : slv(15 downto 0);
      -- Bits(15:14)=(fixed,AC,seq,reserved)
      -- fixed:  marker = 3:0
      -- AC   :  marker = 2:0;  TS = 8:3 (mask)
      -- seq  :  bit    = 4:0;  seq = 12:8
      destSel          : slv(15 downto 0);
      -- 15:15 = DONT_CARE
      --  3:0  = Destination
   end record;
   constant XPM_L0_SELECT_CONFIG_INIT_C : XpmL0SelectConfigType := (
      reset   => '0',
      enabled => '0',
      rateSel => (others=>'0'),
      destSel => x"8000");
   
   type XpmL1SelectConfigType is record
      clear      : slv(NL1Triggers-1 downto 0);
      enable     : slv(NL1Triggers-1 downto 0);
      trigsrc    : slv(3 downto 0);
      trigword   : slv(8 downto 0);
      trigwr     : slv(NL1Triggers-1 downto 0);
   end record;
   constant XPM_L1_SELECT_CONFIG_INIT_C : XpmL1SelectConfigType := (
      clear    => (others=>'0'),
      enable   => (others=>'0'),
      trigsrc  => (others=>'0'),
      trigword => (others=>'0'),
      trigwr   => (others=>'0') );
   
   type XpmL0TagConfigType is record
      enable     : sl;
   end record;
   constant XPM_L0_TAG_CONFIG_INIT_C : XpmL0TagConfigType := (
      enable => '0' );

   type XpmInhibitConfigType is record
     enable   : sl;
     interval : slv(11 downto 0);
     limit    : slv( 3 downto 0); -- max L0s within l0interval
   end record;
   constant XPM_INHIBIT_CONFIG_INIT_C : XpmInhibitConfigType := (
     enable   => '0',
     limit    => (others=>'1'),
     interval => (others=>'0'));
   type XpmInhibitConfigArray is array (natural range<>) of XpmInhibitConfigType;

   type XpmPartInhConfigType is record
     setup : XpmInhibitConfigArray(3 downto 0);
   end record;
   constant XPM_PART_INH_CONFIG_INIT_C : XpmPartInhConfigType := (
     setup => (others=>XPM_INHIBIT_CONFIG_INIT_C) );

   type XpmPartMsgConfigType is record
     insert  : sl;
     hdr     : slv(14 downto 0);
     payload : slv(31 downto 0);
   end record;
   constant XPM_PART_MSG_CONFIG_INIT_C : XpmPartMsgConfigType := (
     insert  => '0',
     hdr     => (others=>'0'),
     payload => (others=>'0') );
   
   type XpmAnalysisConfigType is record
      rst        : slv(  NTagBytes-1 downto 0);
      tag        : slv(8*NTagBytes-1 downto 0);
      push       : slv(  NTagBytes-1 downto 0);
   end record;
   constant XPM_ANALYSIS_CONFIG_INIT_C : XpmAnalysisConfigType := (
      rst        => (others=>'0'),
      tag        => (others=>'0'),
      push       => (others=>'0') );
   
   type XpmPipelineConfigType is record
      depth      : slv(19 downto 0);
   end record;
   constant XPM_PIPELINE_CONFIG_INIT_C : XpmPipelineConfigType := (
      depth => toSlv(100*200,20) );

   type XpmBsaConfigType is record
      enabled    : sl;
      activeSetup   : slv( 6 downto 0);
      activeDelay   : slv(19 downto 0);
      activeWidth   : slv(19 downto 0);
   end record;
   constant XPM_BSA_CONFIG_INIT_C : XpmBsaConfigType := (
      enabled       => '0',
      activeSetup   => (others=>'0'),
      activeDelay   => (others=>'0'),
      activeWidth   => (others=>'0') );
  
   type XpmPartitionConfigType is record
      l0Select   : XpmL0SelectConfigType;
      l1Select   : XpmL1SelectConfigType;
      analysis   : XpmAnalysisConfigType;
      l0Tag      : XpmL0TagConfigType;
      pipeline   : XpmPipelineConfigType;
      inhibit    : XpmPartInhConfigType;
      message    : XpmPartMsgConfigType;
   end record;
   constant XPM_PARTITION_CONFIG_INIT_C : XpmPartitionConfigType := (
      l0Select   => XPM_L0_SELECT_CONFIG_INIT_C,
      l1Select   => XPM_L1_SELECT_CONFIG_INIT_C,
      analysis   => XPM_ANALYSIS_CONFIG_INIT_C,
      l0Tag      => XPM_L0_TAG_CONFIG_INIT_C,
      pipeline   => XPM_PIPELINE_CONFIG_INIT_C,
      inhibit    => XPM_PART_INH_CONFIG_INIT_C,
      message    => XPM_PART_MSG_CONFIG_INIT_C );
   type XpmPartitionConfigArray is array (natural range<>) of XpmPartitionConfigType;
   
   type XpmConfigType is record
      dsLink     : XpmLinkConfigArray(NDSLinks-1 downto 0);
      bpLink     : XpmLinkConfigArray(NBPLinks-1 downto 0);
      pll        : XpmPllConfigArray(NAmcs-1 downto 0);
      partition  : XpmPartitionConfigArray(NPartitions-1 downto 0);
      tagstream  : sl;
   end record;
   constant XPM_CONFIG_INIT_C : XpmConfigType := (
      dsLink    => (others => XPM_LINK_CONFIG_INIT_C),
      bpLink    => (others => XPM_LINK_CONFIG_INIT_C),
      pll       => (others => XPM_PLL_CONFIG_INIT_C),
      partition => (others => XPM_PARTITION_CONFIG_INIT_C),
      tagstream => '0' );

   type XpmAcceptFrameType is record
      strobe     : sl;
   end record;
   constant XPM_ACCEPT_FRAME_INIT_C : XpmAcceptFrameType := (
      strobe    => '0' );
   
   type XpmL1InputType is record
      valid      : sl;
      trigsrc    : slv( 3 downto 0);
      tag        : slv( 4 downto 0);
      trigword   : slv( 8 downto 0);
   end record;
   type XpmL1InputArray is array (natural range<>) of XpmL1InputType;
   constant XPM_L1_INPUT_INIT_C : XpmL1InputType := (
      valid     => '0',
      trigsrc   => (others=>'0'),
      tag       => (others=>'0'),
      trigword  => (others=>'0'));

   type XpmPartitionDataType is record
      l0a     : sl;
      l0tag   : slv(4 downto 0);
      l1e     : sl;
      l1a     : sl;
      l1tag   : slv(4 downto 0);
      anatag  : slv(31 downto 0);
   end record;

   constant XPM_PARTITION_DATA_INIT_C : XpmPartitionDataType := (
     l0a      => '0',
     l0tag    => (others=>'0'),
     l1e      => '0',
     l1a      => '0',
     l1tag    => (others=>'0'),
     anatag   => (others=>'0') );

   type XpmPartitionDataArray is array(natural range<>) of XpmPartitionDataType;
   
   function toSlvT(l0a : sl; l0tag : slv; l1e : sl; l1a : sl; l1tag : slv) return slv;
   function toL0Tag(pword : slv) return slv;

   function toSlv(s : XpmLinkStatusType) return slv;
   function toLinkStatus(vector : slv) return XpmLinkStatusType;

   function toSlv  (pword : XpmPartitionDataType) return slv;
   function toPartitionWord(vector : slv) return XpmPartitionDataType;
   
end package XpmPkg;

package body XpmPkg is

   function toSlvT(l0a : sl; l0tag : slv; l1e : sl; l1a : sl; l1tag : slv) return slv is
     variable vector : slv(15 downto 0);
   begin
     vector := '1' & l1tag(4 downto 0) & l1a & l1e &
               "00" & l0tag(4 downto 0) & l0a;
     return vector;
   end function;

   function toL0Tag(pword : slv) return slv is
     variable vector : slv(4 downto 0);
   begin
     vector := pword(5 downto 1);
     return vector;
   end function;

   function toSlv(s : XpmLinkStatusType) return slv is
     variable vector : slv(21 downto 0) := (others=>'0');
     variable i      : integer := 0;
   begin
     assignSlv(i, vector, s.txResetDone);
     assignSlv(i, vector, s.txReady);
     assignSlv(i, vector, s.rxResetDone);
     assignSlv(i, vector, s.rxReady);
     assignSlv(i, vector, s.rxErr);
     assignSlv(i, vector, s.rxErrCnts);
     assignSlv(i, vector, s.rxIsXpm);
     return vector;
   end function;

   function toLinkStatus(vector : slv) return XpmLinkStatusType is
     variable v : XpmLinkStatusType := XPM_LINK_STATUS_INIT_C;
     variable i : integer := 0;
   begin
     assignRecord(i, vector, v.txResetDone);
     assignRecord(i, vector, v.txReady);
     assignRecord(i, vector, v.rxResetDone);
     assignRecord(i, vector, v.rxReady);
     assignRecord(i, vector, v.rxErr);
     assignRecord(i, vector, v.rxErrCnts);
     assignRecord(i, vector, v.rxIsXpm);
     return v;
   end function;

   function toSlv  (pword : XpmPartitionDataType) return slv is
     variable vector : slv(47 downto 0) := (others=>'0');
     variable i      : integer          := 0;
   begin
     assignSlv(i, vector, pword.l0a);
     assignSlv(i, vector, pword.l0tag);
     assignSlv(i, vector, "00");
     assignSlv(i, vector, pword.l1e);
     assignSlv(i, vector, pword.l1a);
     assignSlv(i, vector, pword.l1tag);
     assignSlv(i, vector, "1");
     assignSlv(i, vector, pword.anatag);
     return vector;
   end function;
   
   function toPartitionWord(vector : slv) return XpmPartitionDataType is
     variable pword : XpmPartitionDataType := XPM_PARTITION_DATA_INIT_C;
     variable i     : integer              := 0;
   begin
     assignRecord(i, vector, pword.l0a);
     assignRecord(i, vector, pword.l0tag);
     i := i+2;
     assignRecord(i, vector, pword.l1e);
     assignRecord(i, vector, pword.l1a);
     assignRecord(i, vector, pword.l1tag);
     i := i+1;
     assignRecord(i, vector, pword.anatag);
     return pword;
   end function;
   
end package body XpmPkg;
