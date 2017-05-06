-------------------------------------------------------------------------------
-- File       : LclsTriggerCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-08
-- Last update: 2016-11-07
-------------------------------------------------------------------------------
-- Description:  Triggered if opcode received.
--               Opcode = oth 0 (Disabled)
--               Minimum pulse latency = 2c-c 
--               Delay0: Minimum+0
--               Delay1: Minimum+1              
--               Delay2: Minimum+2               
--               ...
--               Width0: 1 c-c
--               Width1: 2 c-c             
--               Width2: 3 c-c                
--               ...         
--                    
------------------------------------------------------------------------------
-- This file is part of 'LCLS1 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS1 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.TimingPkg.all;

entity LclsTriggerCore is
   generic (
      TPD_G                : time                  := 1 ns;
      AXIL_BASE_ADDR_G     : slv(31 downto 0)      := (others => '0');
      AXI_ERROR_RESP_G     : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      NUM_OF_TRIG_PULSES_G : positive              := 3;
      DELAY_WIDTH_G        : integer range 1 to 32 := 32;
      PULSE_WIDTH_G        : integer range 1 to 32 := 32);
   port (
      -- AXI-Lite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Timing Interface
      recClk          : in  sl;
      recRst          : in  sl;
      timingBus_i     : in  TimingBusType;
      -- Trigger pulse outputs 
      trigPulse_o     : out slv(NUM_OF_TRIG_PULSES_G-1 downto 0);
      timeStamp_o     : out slv(63 downto 0);
      pulseId_o       : out slv(31 downto 0);
      bsa_o           : out slv(127 downto 0);
      dmod_o          : out slv(191 downto 0));   
end LclsTriggerCore;

architecture mapping of LclsTriggerCore is

   constant NUM_AXI_MASTERS_C : natural := NUM_OF_TRIG_PULSES_G;

   constant AXIL_CROSSBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) :=
      genAxiLiteConfig(NUM_AXI_MASTERS_C, AXIL_BASE_ADDR_G, 16, 12);
   -- Trig0 Addr AXIL_BASE_ADDR_G + 0x0000
   -- Trig1 Addr AXIL_BASE_ADDR_G + 0x1000
   -- Trig2 Addr AXIL_BASE_ADDR_G + 0x2000
   -- ...

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
   
begin

   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CROSSBAR_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);


   U_TimingRegStb : entity work.LclsTriggerRegisterStrobe
      generic map (
         TPD_G => TPD_G)
      port map (
         clk         => recClk,
         rst         => recRst,
         strobe_i    => timingBus_i.strobe,
         timestamp_i => timingBus_i.stream.dbuff.epicsTime,
         pulseID_i   => timingBus_i.stream.pulseId,
         bsa_i(0)    => timingBus_i.stream.dbuff.edefAvgDn,
         bsa_i(1)    => timingBus_i.stream.dbuff.edefMinor,
         bsa_i(2)    => timingBus_i.stream.dbuff.edefMajor,
         bsa_i(3)    => timingBus_i.stream.dbuff.edefInit,
         dmod_i      => timingBus_i.stream.dbuff.dmod,
         timestamp_o => timestamp_o,
         pulseID_o   => pulseID_o,
         bsa_o       => bsa_o,
         dmod_o      => dmod_o);

   -- Pulse trigger generated by timing event (opcode)
   GEN_TRIG_PULSE : for i in NUM_OF_TRIG_PULSES_G-1 downto 0 generate
      U_TimingTriggerPulse : entity work.LclsTriggerPulse
         generic map (
            TPD_G            => TPD_G,
            AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
            DELAY_WIDTH_G    => DELAY_WIDTH_G,
            PULSE_WIDTH_G    => PULSE_WIDTH_G)
         port map (
            clk             => recClk,
            rst             => recRst,
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMasters(i),
            axilReadSlave   => axilReadSlaves(i),
            axilWriteMaster => axilWriteMasters(i),
            axilWriteSlave  => axilWriteSlaves(i),
            opcodes_i       => timingBus_i.stream.eventCodes,
            strobe_i        => timingBus_i.strobe,
            pulse_o         => trigPulse_o(i));
   end generate GEN_TRIG_PULSE;
   
end architecture mapping;
