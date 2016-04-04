------------------------------------------------------------------------------
-- This file is part of 'SLAC EVR Gen2'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC EVR Gen2', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package Version is

   constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"CED20012";  -- MAKE_VERSION

   constant BUILD_STAMP_C : string := "LegacyEvrCardG2: Vivado v2015.4 (x86_64) Built Mon Apr  4 13:14:47 PDT 2016 by ruckman";

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
-- 10/26/2015 (CED2000B): 
--    Revision Control:    Branching from CED2000A
--    In EVR core,         If no heartbeat event is received the counter times out (approx. 1.6 s)
--                         and a heartbeat flag is set.
--
-- 10/27/2015 (CED2000C): 
--    Revision Control:    Branching from CED2000B
--    In EVR core,         Synchronizing all status bits used to generate an interrupt on the axiClk
--                         clock domain and no longer a mix of axiClk/evrClk domain.
--
-- 10/28/2015 (CED2000D): 
--    Revision Control:    Branching from CED2000C
--    In EVR core,         Changed the Output Trigger Crossbar from registered to combinatory 
--                         to phase match with the MRF (removes 8.4 ns delay)
--    In MGT core,         If linkDown then, forward rxData = 0x0 and rxDataK = 0x0 to EVR core
--    In EvrCardG2Trig,    Bypass the trig MUX
--
-- 03/15/2016 (CED2000E): 
--    Revision Control:    Branching from CED2000D
--    In Top Level ,       Rebuilding the baseline 
--
-- 03/15/2016 (CED2000F): 
--    Revision Control:    Branching from CED2000E
--    In Top Level ,       Changed BPI from ASYNC to SYNC mode (TYPE2) and config clock from 9 MHz to 50 MHz 
--
-- 03/25/2016 (CED20010): 
--    Revision Control:    Branching from CED2000F
--    In Top Level ,       Disabled the ability for AxiVersion to cause a reboot of FPGA via PCIe register transaction
--
-- 04/04/2016 (CED20011): 
--    Revision Control:    Branching from CED20010
--    In PCI core,         Upgrade the Xilinx PCIe IP core from version 3.1 to version 3.2
--
-- 04/04/2016 (CED20012): 
--    Revision Control:    Branching from CED20011
--    In PCI core,         Debouncing the PCIe's reset for 1.5 us
--
-------------------------------------------------------------------------------
