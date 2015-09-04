LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"CED20005"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "EvrCardG2: Vivado v2015.2 (x86_64) Built Tue Aug 18 10:55:32 PDT 2015 by ruckman";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 07/24/2015 (CED20000): Initial Build
-- 07/30/2015 (CED20001): Inverted the output to match Legacy EVR output
-- 08/06/2015 (CED20002): In getPcieHdr(), reordered FirstDwBe & LastDwBe
-- 08/17/2015 (CED20003): Fixed the 16-bit accesses in the EvrV1Reg.vhd
-- 08/17/2015 (CED20004): Fixed the intFlag(3) importing bug
-- 08/18/2015 (CED20005): In EvrV1TimeStampFIFO.vhd, change FWFT_EN_G from "false" to "true"
--
-------------------------------------------------------------------------------

