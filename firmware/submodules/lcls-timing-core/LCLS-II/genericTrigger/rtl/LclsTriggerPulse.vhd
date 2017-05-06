-------------------------------------------------------------------------------
-- File       : LclsTriggerPulse.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-08
-- Last update: 2017-02-09
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

entity LclsTriggerPulse is
   generic (
      TPD_G            : time                  := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_DECERR_C;
      DELAY_WIDTH_G    : integer range 1 to 32 := 32;
      PULSE_WIDTH_G    : integer range 1 to 32 := 32);
   port (
      -- Timing clock
      clk : in sl;
      rst : in sl;
      -- AXI-Lite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Opcodes (events)
      opcodes_i : in slv(255 downto 0);
      strobe_i  : in sl;
      -- Trigger pulse output 
      pulse_o : out sl);
end LclsTriggerPulse;

architecture rtl of LclsTriggerPulse is

   type StateType is (
      WAIT_TRIG_S,
      WAIT_DELAY_S,
      WAIT_WIDTH_S);

   type RegType is record
      cnt      : slv(31 downto 0);
      pulse    : sl;
      delayReg : slv(DELAY_WIDTH_G-1 downto 0);
      widthReg : slv(PULSE_WIDTH_G-1 downto 0);
      state : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt      => (others => '0'),
      pulse    => '0',
      delayReg => (others => '0'),
      widthReg => (others => '0'),
      state    => WAIT_TRIG_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal s_opcodesReg : slv(255 downto 0);
   signal s_delayReg   : slv(DELAY_WIDTH_G-1 downto 0);
   signal s_widthReg   : slv(PULSE_WIDTH_G-1 downto 0);
   signal s_polarity   : sl;

begin

   U_Reg : entity work.LclsTriggerPulseReg
      generic map (
         TPD_G            => TPD_G,
         AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
         DELAY_WIDTH_G    => DELAY_WIDTH_G,
         PULSE_WIDTH_G    => PULSE_WIDTH_G)
      port map (
         axiclk_i        => axilClk,
         axirst_i        => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         devclk_i        => clk,
         devrst_i        => rst,
         opcodesReg_o    => s_opcodesReg,
         delayReg_o      => s_delayReg,
         widthReg_o      => s_widthReg,
         polarity_o      => s_polarity);

   comb : process (r, rst, s_polarity, opcodes_i, strobe_i, s_opcodesReg, s_delayReg, s_widthReg) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when WAIT_TRIG_S =>
            -- Save configurations
            v.pulse    := s_polarity;   -- Pulse NOT active
            v.delayReg := s_delayReg;
            v.widthReg := s_widthReg;
            -- Check for trigger
            if ((opcodes_i and s_opcodesReg) /= 0) and (strobe_i = '1') then
               -- Next state
               v.state := WAIT_DELAY_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_DELAY_S =>
            -- Increment the counter
            v.cnt   := r.cnt + 1;
            -- NOT asserted the pulse
            v.pulse := s_polarity;      -- Pulse NOT active
            -- Check the counter
            if r.cnt = r.delayReg then
               v.cnt   := (others => '0');
               -- Next state
               v.state := WAIT_WIDTH_S;
            end if;
         ----------------------------------------------------------------------
         when WAIT_WIDTH_S =>
            -- Increment the counter
            v.cnt   := r.cnt + 1;
            -- Asserted the pulse
            v.pulse := not(s_polarity);  -- Pulse active
            -- Check the counter
            if r.cnt = r.widthReg then
               -- Reset the counter
               v.cnt      := (others => '0');
               -- Next state
               v.state := WAIT_TRIG_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      
      -- Outputs
      pulse_o <= r.pulse;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end  rtl;
