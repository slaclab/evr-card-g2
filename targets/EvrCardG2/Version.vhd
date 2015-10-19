library ieee;
use ieee.std_logic_1164.all;

package Version is

   constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"CED2000A";  -- MAKE_VERSION

   constant BUILD_STAMP_C : string := "EvrCardG2: Vivado v2015.3 (x86_64) Built Mon Oct 19 13:19:25 PDT 2015 by ruckman";

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
-- 09/23/2015 (CED20006): Removed 4 shift registers in EvrV1EventReceiver for rxData & rxDataK
--                        Registering the trigger outputs and set the SLEW = FAST
-- 09/24/2015 (CED20007): Added 2 cycles address setup delay for BRAM's AXI-Lite read transactions
-- 09/25/2015 (CED20008): Removed the dbRdAddr Synchronizer 
--                        Note: In EvrCardG2Trig.vhd: ODDR = "OPPOSITE_EDGE"
-- 10/19/2015 (CED20009): In EvrCardG2Trig.vhd: ODDR = "SAME_EDGE" and with clock MUX
-- 10/19/2015 (CED2000A): In EvrCardG2Trig.vhd: ODDR = "SAME_EDGE" and bypass clock MUX
--
-------------------------------------------------------------------------------

