-------------------------------------------------------------------------------
-- File       : LclsTriggerRegisterStrobe.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-08
-- Last update: 2017-02-09
-------------------------------------------------------------------------------
-- Description:  Registers timestamp_i and pulseID_i on strobe              
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

entity LclsTriggerRegisterStrobe is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk         : in  sl;
      rst         : in  sl;
      strobe_i    : in  sl;
      timestamp_i : in  slv(63 downto 0);
      pulseID_i   : in  slv(31 downto 0);
      bsa_i       : in  Slv32Array(3 downto 0);
      dmod_i      : in  slv(191 downto 0);
      timestamp_o : out slv(63 downto 0);
      pulseID_o   : out slv(31 downto 0);
      bsa_o       : out slv(127 downto 0);
      dmod_o      : out slv(191 downto 0));
end LclsTriggerRegisterStrobe;

architecture rtl of LclsTriggerRegisterStrobe is

   type RegType is record
      timestamp : slv(63 downto 0);
      dmod      : slv(191 downto 0);
      pulseID   : slv(31 downto 0);
      bsa       : slv(bsa_o'range);
   end record RegType;

   constant REG_INIT_C : RegType := (
      timestamp => (others => '0'),
      dmod      => (others => '0'),
      pulseID   => (others => '0'),
      bsa       => (others => '0'));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (rst, r, strobe_i, timestamp_i, pulseID_i, bsa_i, dmod_i) is
      variable v : RegType;
   begin
      -- Latch the current value   
      v := r;

      -- Check for strobe
      if (strobe_i = '1') then
         v.timestamp          := timestamp_i;
         v.pulseID            := pulseID_i;
         v.dmod               := dmod_i;
         v.bsa(127 downto 96) := bsa_i(0);
         v.bsa(95 downto 64)  := bsa_i(1);
         v.bsa(63 downto 32)  := bsa_i(2);
         v.bsa(31 downto 0)   := bsa_i(3);
      else
         v.timestamp := r.timestamp;
         v.pulseID   := r.pulseID;
         v.dmod      := r.dmod;
         v.bsa       := r.bsa;
      end if;

      -- Synchronous Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      timestamp_o <= r.timestamp;
      pulseID_o   <= r.pulseID;
      dmod_o      <= r.dmod;
      bsa_o       <= r.bsa;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
