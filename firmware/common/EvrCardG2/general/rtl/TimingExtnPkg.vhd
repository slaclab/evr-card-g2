-------------------------------------------------------------------------------
-- Title      : TimingPkg
-------------------------------------------------------------------------------
-- File       : TimingExtnPkg.vhd
-- Author     : Matt Weaver  <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2018-07-20
-- Last update: 2020-01-31
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


library surf;
use surf.StdRtlPkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;

package TimingExtnPkg is

   constant EXPT_STREAM_ID    : slv(3 downto 0) := x"1";

   --
   --  Experiment timing information (appended by downstream masters)
   --
   constant EXPT_MESSAGE_BITS_C : integer := PADDR_LEN+8*PWORD_LEN;
   constant EXPT_PARTITIONS_C : integer := NPartitions;
   
   type ExptMessageType is record
     partitionAddr   : slv(31 downto 0);
     partitionWord   : Slv48Array(0 to EXPT_PARTITIONS_C-1);
   end record;
   constant EXPT_MESSAGE_INIT_C : ExptMessageType := (
     partitionAddr  => (others=>'1'),
     partitionWord  => (others=>x"800080008000") );
   type ExptMessageArray is array (integer range<>) of ExptMessageType;

   type ExptBusType is record
     message : ExptMessageType;
     valid   : sl;
   end record ExptBusType;
   constant EXPT_BUS_INIT_C : ExptBusType := (
     message => EXPT_MESSAGE_INIT_C,
     valid   => '0' );
   type ExptBusArray is array (integer range<>) of ExptBusType;

   function toSlv(message : ExptMessageType) return slv;
   function toExptMessageType (vector : slv) return ExptMessageType;

   function toTrigVector(message : ExptMessageType) return slv;
   --
   -- The extended interface
   --

   constant TIMING_EXTN_STREAMS_C : integer := 1;
   constant TIMING_EXTN_WORDS_C : IntegerArray(0 downto 0) := (
     0 => EXPT_MESSAGE_BITS_C/16 );
   
   type TimingExtnType is record
     expt    : ExptMessageType;
   end record;

   constant TIMING_EXTN_INIT_C : TimingExtnType := (
     expt    => EXPT_MESSAGE_INIT_C );

   constant TIMING_EXTN_BITS_C : integer := EXPT_MESSAGE_BITS_C;
   
   function toSlv(message : TimingExtnType) return slv;
   function toTimingExtnType(vector : in slv) return TimingExtnType;
   
   function toSlv(stream  : integer;
                  message : TimingExtnType) return slv;
   procedure toTimingExtnType(stream : in    integer;
                              vector : in    slv;
                              validi : in    sl;
                              extn   : inout TimingExtnType;
                              valido : inout sl );
end package TimingExtnPkg;

package body TimingExtnPkg is

   function toSlv(message : ExptMessageType) return slv
   is
      variable vector  : slv(EXPT_MESSAGE_BITS_C-1 downto 0) := (others=>'0');
      variable i       : integer := 0;
   begin
      assignSlv(i, vector, message.partitionAddr);
      for j in message.partitionWord'range loop
         assignSlv(i, vector, message.partitionWord(j));
      end loop;
      return vector;
   end function;
      
   function toExptMessageType (vector : slv) return ExptMessageType
   is
      variable message : ExptMessageType;
      variable i       : integer := 0;
   begin
      assignRecord(i, vector, message.partitionAddr);
      for j in message.partitionWord'range loop
         assignRecord(i, vector, message.partitionWord(j));
      end loop;
      return message;
   end function;
   
   function toTrigVector(message : ExptMessageType) return slv is
     variable vector : slv(EXPT_PARTITIONS_C-1 downto 0);
     variable word   : XpmPartitionDataType;
   begin
     for i in 0 to EXPT_PARTITIONS_C-1 loop
       word      := toPartitionWord(message.partitionWord(i));
       vector(i) := word.l0a or not message.partitionWord(i)(15);
     end loop;
     return vector;
   end function;

   function toSlv(message : TimingExtnType) return slv is
     variable vector : slv(TIMING_EXTN_BITS_C-1 downto 0);
     variable i : integer := 0;
   begin
     assignSlv(i, vector, toSlv(message.expt));
     return vector;
   end function;

   function toTimingExtnType(vector : slv) return TimingExtnType is
     variable message : TimingExtnType := TIMING_EXTN_INIT_C;
   begin
     message.expt := toExptMessageType(vector(EXPT_MESSAGE_BITS_C-1 downto 0));
     return message;
   end function;
   
   function toSlv(stream  : integer;
                  message : TimingExtnType) return slv is
     variable vector : slv(16*TIMING_EXTN_WORDS_C(stream-1)-1 downto 0);
   begin
     case stream is
       when 1 => vector := toSlv(message.expt);
       when others => null;
     end case;
     return vector;
   end function;
   
   procedure toTimingExtnType(stream : in    integer;
                              vector : in    slv;
                              validi : in    sl;
                              extn   : inout TimingExtnType;
                              valido : inout sl ) is
   begin
     case stream is
       when 1 =>
         valido       := validi;
         extn.expt    := toExptMessageType(vector);
       when others => null;
     end case;
   end procedure;

end package body TimingExtnPkg;
