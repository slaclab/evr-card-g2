-------------------------------------------------------------------------------
-- File       : LclsTriggerPulseReg.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-15
-- Last update: 2017-02-09
-------------------------------------------------------------------------------
-- Description:  
-------------------------------------------------------------------------------
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

entity LclsTriggerPulseReg is
   generic (
      -- General Configurations
      TPD_G            : time                  := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      AXI_ADDR_WIDTH_G : positive              := 8;
      DELAY_WIDTH_G    : integer range 1 to 32 := 16;
      PULSE_WIDTH_G    : integer range 1 to 32 := 16);
   port (
      -- AXI Clk
      axiClk_i        : in  sl;
      axiRst_i        : in  sl;
      -- Axi-Lite Register Interface (axiClk domain)
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      -- Dev Clk
      devClk_i        : in  sl;
      devRst_i        : in  sl;
      -- Registers
      opcodesReg_o    : out slv(255 downto 0);
      delayReg_o      : out slv(DELAY_WIDTH_G-1 downto 0);
      widthReg_o      : out slv(PULSE_WIDTH_G-1 downto 0);
      polarity_o      : out sl);
end LclsTriggerPulseReg;

architecture rtl of LclsTriggerPulseReg is

   type RegType is record
      opcodes        : slv(255 downto 0);
      delay          : slv(DELAY_WIDTH_G-1 downto 0);
      pulseWidth     : slv(PULSE_WIDTH_G-1 downto 0);
      polarity       : sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      opcodes        => (others => '0'),
      delay          => (others => '0'),
      pulseWidth     => (others => '0'),
      polarity       => '0',
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axiRst_i, axilReadMaster, axilWriteMaster, r) is
      variable v      : RegType;
      variable regCon : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      -- Determine the AXI-Lite transaction type
      axiSlaveWaitTxn(regCon, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the registers
      axiSlaveRegister(regCon, x"00", 0, v.opcodes);
      axiSlaveRegister(regCon, x"20", 0, v.delay);
      axiSlaveRegister(regCon, x"24", 0, v.pulseWidth);
      axiSlaveRegister(regCon, x"28", 0, v.polarity);

      -- Closeout the AXI-Lite transaction
      axiSlaveDefault(regCon, v.axilWriteSlave, v.axilReadSlave, AXI_ERROR_RESP_G);

      -- Reset
      if (axiRst_i = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

   end process comb;

   seq : process (axiClk_i) is
   begin
      if rising_edge(axiClk_i) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SyncFifo_OUT0 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => 256)
      port map (
         wr_clk => axiClk_i,
         din    => r.opcodes,
         rd_clk => devClk_i,
         dout   => opcodesReg_o);

   SyncFifo_OUT1 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => DELAY_WIDTH_G)
      port map (
         wr_clk => axiClk_i,
         din    => r.delay,
         rd_clk => devClk_i,
         dout   => delayReg_o);

   SyncFifo_OUT2 : entity work.SynchronizerFifo
      generic map (
         TPD_G        => TPD_G,
         DATA_WIDTH_G => PULSE_WIDTH_G)
      port map (
         wr_clk => axiClk_i,
         din    => r.pulseWidth,
         rd_clk => devClk_i,
         dout   => widthReg_o);

   Sync_OUT3 : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         dataIn  => r.polarity,
         clk     => devClk_i,
         dataOut => polarity_o);

end rtl;
