-------------------------------------------------------------------------------
-- File       : GthRxAlignCheck.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-08-29
-- Last update: 2017-04-11
-------------------------------------------------------------------------------
-- Description: GTH RX Byte Alignment Checker module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiLiteMasterPkg.all;

entity GthRxAlignCheck is
   generic (
      TPD_G            : time            := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C;
      DRP_ADDR_G       : slv(31 downto 0));
   port (
      -- GTH Status/Control Interface
      resetIn          : in  sl;
      resetOut         : out sl;
      resetDone        : in  sl;
      resetErr         : in  sl;
      locked           : out sl;
      -- Clock and Reset
      axilClk          : in  sl;
      axilRst          : in  sl;
      -- Master AXI-Lite Interface
      mAxilReadMaster  : out AxiLiteReadMasterType;
      mAxilReadSlave   : in  AxiLiteReadSlaveType;
      mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType;
      -- Slave AXI-Lite Interface
      sAxilReadMaster  : in  AxiLiteReadMasterType;
      sAxilReadSlave   : out AxiLiteReadSlaveType;
      sAxilWriteMaster : in  AxiLiteWriteMasterType;
      sAxilWriteSlave  : out AxiLiteWriteSlaveType);
end entity GthRxAlignCheck;

architecture rtl of GthRxAlignCheck is

   constant COMMA_ALIGN_LATENCY_ADDR_C : slv(31 downto 0) := (DRP_ADDR_G + x"0000_0540");  -- DRP_ADDR=0x150 (see UG576 (v1.4) on page 416)

   constant LOCK_VALUE : integer := 16;
   constant MASK_VALUE : integer := 126;

   type StateType is (
      RESET_S,
      READ_S,
      ACK_S,
      LOCKED_S);

   type RegType is record
      locked          : sl;
      rst             : sl;
      rstlen          : slv(3 downto 0);
      rstcnt          : slv(3 downto 0);
      tgt             : slv(6 downto 0);
      mask            : slv(6 downto 0);
      last            : slv(6 downto 0);
      sample          : Slv8Array(39 downto 0);
      sAxilWriteSlave : AxiLiteWriteSlaveType;
      sAxilReadSlave  : AxiLiteReadSlaveType;
      req             : AxiLiteMasterReqType;
      state           : StateType;
   end record;
   constant REG_INIT_C : RegType := (
      locked          => '0',
      rst             => '1',
      rstlen          => toSlv(3, 4),
      rstcnt          => toSlv(0, 4),
      tgt             => toSlv(LOCK_VALUE, 7),
      mask            => toSlv(MASK_VALUE, 7),
      last            => toSlv(0, 7),
      sample          => (others => (others => '0')),
      sAxilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      sAxilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      req             => AXI_LITE_MASTER_REQ_INIT_C,
      state           => READ_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal ack : AxiLiteMasterAckType;


--   attribute dont_touch        : string;
--   attribute dont_touch of r   : signal is "TRUE";
--   attribute dont_touch of ack : signal is "TRUE";


begin

   process(ack, axilRst, r, resetDone, resetErr, resetIn, sAxilReadMaster,
           sAxilWriteMaster) is
      variable v      : RegType;
      variable axilEp : AxiLiteStatusType;
      variable i      : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags      
      v.rst    := '0';
      v.locked := '0';

      -- Determine the transaction type
      axiSlaveWaitTxn(sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave, axilEp);

      for i in 0 to r.sample'length-1 loop
         axiSlaveRegister(sAxilReadMaster, v.sAxilReadSlave, axilEp, toSlv(4*(i/4), 9), 8*(i mod 4), v.sample(i));
      end loop;
      axiSlaveRegister(sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave, axilEp, toSlv(256, 9), 0, v.tgt);
      axiSlaveRegister(sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave, axilEp, toSlv(256, 9), 8, v.mask);
      axiSlaveRegister(sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave, axilEp, toSlv(256, 9), 16, v.rstlen);
      axiSlaveRegister(sAxilReadMaster, v.sAxilReadSlave, axilEp, toSlv(260, 9), 0, v.last);

      axiSlaveDefault(sAxilWriteMaster, sAxilReadMaster, v.sAxilWriteSlave, v.sAxilReadSlave, axilEp, AXI_RESP_OK_C);

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when RESET_S =>
            -- Set the flag
            v.rst := '1';
            -- Check the counter
            if (r.rstcnt = r.rstlen) then
               -- Wait for the reset transition
               if (resetDone = '0') then
                  -- Reset the counter
                  v.rstcnt := (others => '0');
                  -- Next state
                  v.state  := READ_S;
               end if;
            else
               -- Increment the counter
               v.rstcnt := r.rstcnt+1;
            end if;
         ----------------------------------------------------------------------
         when READ_S =>
            -- Wait for the reset transition and check state of master AXI-Lite
            if (resetDone = '1') and (ack.done = '0') then
               -- Start the master AXI-Lite transaction
               v.req.request := '1';
               v.req.rnw     := '1';    -- read operation
               v.req.address := COMMA_ALIGN_LATENCY_ADDR_C;
               -- Next state
               v.state       := ACK_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
            -- AXI-Lite transaction handshaking
            if (ack.done = '1') then
               -- Reset the flag
               v.req.request := '0';
               -- Get the index pointer
               i             := conv_integer(ack.rdData(6 downto 0));
               -- Increment the counter 
               v.sample(i)   := r.sample(i)+1;
               -- Save the last byte alignment check
               v.last        := ack.rdData(15 downto 0);
               -- Check the byte alignment
               if ((ack.rdData(6 downto 0) xor r.tgt) and r.mask) = toSlv(0, 7) then
                  -- Next state
                  v.state := LOCKED_S;
               else
                  -- Set the flag
                  v.rst   := '1';
                  -- Next state      
                  v.state := RESET_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LOCKED_S =>
            -- Set the flag
            v.locked := '1';
      ----------------------------------------------------------------------
      end case;

      -- Check for software controlled sampler reset
      if (axilEp.writeEnable = '1') and (sAxilWriteMaster.awaddr(8 downto 0) = toSlv(256, 9)) then
         v.sample := (others => (others => '0'));
      end if;

      -- Check for user reset
      if (resetIn = '1') or (resetErr = '1') then
         -- Setup flags for reset state
         v.rst         := '1';
         v.req.request := '0';
         -- Reset the counter
         v.rstcnt      := (others => '0');
         -- Next state
         v.state       := RESET_S;
      end if;

      -- Reset
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs 
      sAxilReadSlave  <= r.sAxilReadSlave;
      sAxilWriteSlave <= r.sAxilWriteSlave;
      locked          <= r.locked;
      resetOut        <= r.rst;

   end process comb;

   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_AxiLiteMaster : entity work.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         req             => r.req,
         ack             => ack,
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilWriteMaster => mAxilWriteMaster,
         axilWriteSlave  => mAxilWriteSlave,
         axilReadMaster  => mAxilReadMaster,
         axilReadSlave   => mAxilReadSlave);

end rtl;
