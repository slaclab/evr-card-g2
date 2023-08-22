-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrSim.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2023-06-14
-- Last update: 2023-07-11
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
use ieee.numeric_std.all;
--use ieee.math_real.all;


library surf;
use surf.StdRtlPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.TPGPkg.all;
use lcls_timing_core.TPGMiniEDefPkg.all;

entity EvrSim is
end EvrSim;

architecture top_level of EvrSim is

  signal tpgConfig : TpgConfigType := TPG_CONFIG_INIT_C;
  signal evrTxClk, evrTxRst  : slv(1 downto 0);
  signal txData  : Slv16Array(1 downto 0);
  signal txDataK : Slv2Array (1 downto 0);
  signal fiducial0 : sl;

  signal dmaFullThr : slv(9 downto 0);
  
  type RegType is record
    irqEnable      : sl;
    countReset     : sl;
    refEnable      : sl;
    dmaFullThr     : slv(dmaFullThr'range);
  end record;
  constant REG_INIT_C : RegType := (
    irqEnable      => '0',
    countReset     => '0',
    refEnable      => '0',
    dmaFullThr     => toSlv(2**dmaFullThr'length-256,dmaFullThr'length));
  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
begin

   tpgConfig.FixedRateDivisors  <= (x"00000",
                                    x"00000",
                                    x"00000",
                                    x"00001",                                   -- 929 kHz
                                    x"0000D",                                    -- 71.4kHz
                                    x"0005B",                                    -- 10.2kHz
                                    x"0038E",                                    -- 1.02kHz 
                                    x"0238C",                                    -- 102 Hz
                                    x"16378",                                    -- 10.2Hz
                                    x"DE2B0");                                    -- 1.02H

   process is
   begin
     evrTxClk(0) <= '1';
     wait for 4.2 ns;
     evrTxClk(0) <= '0';
     wait for 4.2 ns;
   end process;

   process is
   begin
     evrTxClk(1) <= '1';
     wait for 2.7 ns;
     evrTxClk(1) <= '0';
     wait for 2.7 ns;
   end process;
   
   evrTxRst <= "00";

   U_EVG : entity lcls_timing_core.TPGMiniStream
     port map (
       config     => TPG_CONFIG_INIT_C,
       edefConfig => TPG_MINI_EDEF_CONFIG_INIT_C,
       txClk      => evrTxClk(0),
       txRst      => evrTxRst(0),
       txRdy      => '1',
       txData     => txData(0),
       txDataK    => txDataK(0),
       simStrobe  => fiducial0 );

   U_TPG : entity lcls_timing_core.TPGMini
     port map (
       statusO    => open,
       configI    => tpgConfig,
       txClk      => evrTxClk(1),
       txRst      => evrTxRst(1),
       txRdy      => '1',
       txData     => txData(1),
       txDataK    => txDataK(1) );
     
   
end top_level;
