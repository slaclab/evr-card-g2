-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2LclsV1LedRgb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2017-03-03
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
use work.AxiLitePkg.all;

entity EvrCardG2LedRgb is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C);
   port (
      -- EVR Interface
      evrClk          : in  sl;
      evrRst          : in  sl;
      rxLinkUp        : in  sl;
      rxError         : in  sl;
      strobe          : in  sl;
      -- AXI-Lite Interface
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      -- LEDs
      ledRedL         : out sl;
      ledGreenL       : out sl;
      ledBlueL        : out sl);  
end EvrCardG2LedRgb;

architecture rtl of EvrCardG2LedRgb is

   constant FLASH_100_MS_C   : slv(31 downto 0) := toSlv((getTimeRatio(0.1, 8.0E-9) -1), 32);
   constant MODE_PASS_THUR_C : slv(1 downto 0)  := "00";
   constant MODE_FLASH_C     : slv(1 downto 0)  := "01";
   constant MODE_TOGGLE_C    : slv(1 downto 0)  := "10";

   type RegType is record
      enable         : slv(2 downto 0);
      force          : slv(2 downto 0);
      mode           : Slv2Array(2 downto 0);
      flashSize      : Slv32Array(2 downto 0);
      flashCnt       : Slv32Array(2 downto 0);
      led            : slv(2 downto 0);
      state          : slv(2 downto 0);
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      enable         => "111",
      force          => "000",
      mode           => (
         0           => MODE_PASS_THUR_C,  -- RED
         1           => MODE_PASS_THUR_C,  -- GREEN
         2           => MODE_FLASH_C),     -- BLUE
      flashSize      => (others => FLASH_100_MS_C),
      flashCnt       => (others => FLASH_100_MS_C),
      led            => "000",
      state          => "000",
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal state       : slv(2 downto 0);
   signal linkError   : sl;

   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "TRUE";

begin

   linkError <= rxError or not (rxLinkUp);

   Sync_1 : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 2)          
      port map (
         clk        => axilClk,
         dataIn(0)  => linkError,
         dataIn(1)  => rxLinkUp,
         dataOut(0) => state(0),
         dataOut(1) => state(1)); 

   Sync_3 : entity work.SynchronizerOneShot
      generic map (
         TPD_G => TPD_G)          
      port map (
         clk     => evrClk,
         dataIn  => strobe,
         dataOut => state(2));       

   comb : process (axilReadMaster, axilRst, axilWriteMaster, r, state) is
      variable v        : RegType;
      variable regCon   : AxiLiteEndPointType;
      variable i        : natural;
      variable transDet : slv(2 downto 0);
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      transDet := "000";

      -- Determine the transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      if (axilReadMaster.rready = '1') then
         v.axilReadSlave.rdata := (others => '0');
      end if;

      -- Map the registers
      axiSlaveRegister(regCon, x"00", 0, v.enable(0));     -- RED
      axiSlaveRegister(regCon, x"04", 0, v.enable(1));     -- GREEN
      axiSlaveRegister(regCon, x"08", 0, v.enable(2));     -- BLUE
      axiSlaveRegister(regCon, x"0C", 0, v.force(0));      -- RED
      axiSlaveRegister(regCon, x"10", 0, v.force(1));      -- GREEN
      axiSlaveRegister(regCon, x"14", 0, v.force(2));      -- BLUE   
      axiSlaveRegister(regCon, x"18", 0, v.mode(0));       -- RED
      axiSlaveRegister(regCon, x"1C", 0, v.mode(1));       -- GREEN
      axiSlaveRegister(regCon, x"20", 0, v.mode(2));       -- BLUE       
      axiSlaveRegister(regCon, x"24", 0, v.flashSize(0));  -- RED
      axiSlaveRegister(regCon, x"28", 0, v.flashSize(1));  -- GREEN
      axiSlaveRegister(regCon, x"2C", 0, v.flashSize(2));  -- BLUE  
      axiSlaveRegisterR(regCon, x"34", 0, r.led(0));       -- RED
      axiSlaveRegisterR(regCon, x"38", 0, r.led(1));       -- GREEN
      axiSlaveRegisterR(regCon, x"3C", 0, r.led(2));       -- BLUE      

      -- Closeout the transaction
      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      -- Loop through the LED channels
      for i in 2 downto 0 loop
         -- Keep a delayed copy
         v.state(i) := state(i);
         -- Check for rising edge condition
         if (state(i) = '1') and (r.state(i) = '0') then
            -- Edge detected
            transDet(i) := '1';
         end if;
         -- Check if enabled
         if r.enable(i) = '1' then
            -- Check for flash mode
            if r.mode(i) = MODE_FLASH_C then
               -- Check the counter
               if r.flashCnt(i) /= r.flashSize(i) then
                  -- Increment the counter
                  v.flashCnt(i) := r.flashCnt(i) + 1;
                  -- Turn on the LED
                  v.led(i)      := '1';
               else
                  -- Turn off the LED
                  v.led(i) := '0';
               end if;
               -- Check for edge detection
               if transDet(i) = '1' then
                  -- Arm the counter
                  v.flashCnt(i) := (others => '0');
               end if;
            -- Check for toggle mode
            elsif r.mode(i) = MODE_TOGGLE_C then
               -- Check for edge detection
               if transDet(i) = '1' then
                  -- Toggle the LED
                  v.led(i) := not(r.led(i));
               end if;
            -- Pass through mode
            else
               v.led(i) := r.state(i);
            end if;
            -- Check if forcing the LED on
            if r.force(i) = '1' then
               -- Forcing LED
               v.led(i) := '1';
            end if;
         else
            -- Reset all signals
            v.led(i)      := '0';
            v.flashCnt(i) := r.flashSize(i);
         end if;
         -- Check for change in flash size
         if r.flashSize(i) /= v.flashSize(i) then
            -- Reset the counter
            v.flashCnt(i) := r.flashSize(i);
         end if;
      end loop;

      -- Synchronous Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;
      ledRedL        <= not(r.led(0));                                       -- 1st priority
      ledGreenL      <= not(r.led(1) and not(r.led(2)) and not (r.led(0)));  -- 3rd priority
      ledBlueL       <= not(r.led(2) and not (r.led(0)));                    -- 2nd priority
      
   end process comb;

   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
