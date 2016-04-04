-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2PciRst.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-04-03
-- Last update: 2016-04-04
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

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EvrCardG2PciRst is
   generic (
      TPD_G     : time     := 1 ns;
      MAX_CNT_G : positive := 150);
   port (
      clk     : in  sl;
      rstInL  : in  sl;
      rstOutL : out sl);
end entity EvrCardG2PciRst;

architecture rtl of EvrCardG2PciRst is

   constant MAX_CNT_C : natural := MAX_CNT_G-1;

   type RegType is record
      cnt  : natural range 0 to MAX_CNT_C;
      rstL : sl;
   end record RegType;

   constant REG_RESET_C : RegType := (
      cnt  => 0,
      rstL => '0');

   signal r   : RegType := REG_RESET_C;
   signal rin : RegType;

   signal rstL : sl;

begin

   IBUF_Inst : IBUF
      port map(
         I => rstInL,
         O => rstL);  

   comb : process (r, rstL) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Compare the reset input to reset output
      if rstL /= r.rstL then
         -- Check the counter
         if r.cnt = MAX_CNT_C then
            -- Reset the counter
            v.cnt  := 0;
            -- Update the reset output
            v.rstL := rstL;
         else
            -- Increment the counter
            v.cnt := r.cnt + 1;
         end if;
      else
         -- Reset the counter
         v.cnt := 0;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      rstOutL <= r.rstL;

   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
