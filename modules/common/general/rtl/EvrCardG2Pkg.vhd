-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2Pkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-10
-- Last update: 2015-06-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

package EvrCardG2Pkg is

   constant AXI_CLK_FREQ_C : real := 125.0E+6;
   constant EVR_CLK_FREQ_C : RealArray(1 downto 0) := (
      0 => 119.0E+6,
      1 => 185.0E+6);

end package EvrCardG2Pkg;
