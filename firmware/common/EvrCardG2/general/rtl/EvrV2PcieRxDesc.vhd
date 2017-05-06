------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieRxDesc.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2017-05-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe Receive Descriptor Controller
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.SsiPciePkg.all;

entity EvrV2PcieRxDesc is
   generic (
      TPD_G            : time                   := 1 ns;
      DMA_SIZE_G       : positive range 1 to 16 := 1;
      AXI_ERROR_RESP_G : slv(1 downto 0)        := AXI_RESP_SLVERR_C);      
   port (
      -- Parallel Interface 
      dmaDescToPci   : in  DescToPcieArray  (0 to (DMA_SIZE_G-1));
      dmaDescFromPci : out DescFromPcieArray(0 to (DMA_SIZE_G-1));
      -- AXI-Lite Register Interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;
      -- IRQ Request
      irqReq         : out sl;
      -- Counter reset
      cntRst         : in  sl;
      -- Global Signals
      pciClk         : in  sl;
      pciRst         : in  sl); 
end EvrV2PcieRxDesc;

architecture rtl of EvrV2PcieRxDesc is

   type AddrVector is array (integer range<>) of slv(31 downto 2);
   type CntVector  is array (integer range<>) of slv(9 downto 0);

   type RegType is record
      fifoRst       : sl;
      wrDone        : sl;
      rdDone        : sl;
      reqIrq        : sl;
      rxSize        : slv( 9 downto 0);
      rxCount       : slv(31 downto 0);
      -- Free descriptor write
      rxFreeEn      : sl;
      maxFrame      : slv(23 downto 0);
      lastDesc      : slv(31 downto 2);
      lastDescErr   : sl;
      -- Receive descriptor free
      dFifoWr       : slv(DMA_SIZE_G-1 downto 0);
      dFifoRd       : slv(DMA_SIZE_G-1 downto 0);
      dFifoDin      : slv(31 downto 0);
      -- Receive descriptor done
      doneAck       : slv(DMA_SIZE_G-1 downto 0);
      -- AXI-Lite
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      fifoRst       => '1',
      wrDone        => '0',
      rdDone        => '0',
      reqIrq        => '0',
      rxSize        => (others => '0'),
      rxCount       => (others => '0'),
      -- Free descriptor write
      rxFreeEn      => '0',
      maxFrame      => (others => '0'),
      lastDesc      => (others => '0'),
      lastDescErr   => '0',
      -- Receive descriptor free
      dFifoWr       => (others => '0'),
      dFifoRd       => (others => '0'),
      dFifoDin      => (others => '0'),
      -- Receive descriptor done
      doneAck       => (others => '0'),
      -- AXI-Lite
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- Receive descriptor free
   signal dFifoValid : slv(DMA_SIZE_G-1 downto 0);
   signal dFifoDout  : AddrVector(DMA_SIZE_G-1 downto 0);
   signal dFifoAFull : slv(DMA_SIZE_G-1 downto 0);
   signal dFifoFull  : slv(DMA_SIZE_G-1 downto 0);
   signal dFifoCnt   : CntVector(DMA_SIZE_G-1 downto 0);

   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";

begin

  -- Assert IRQ request when there is a entry in the receive queue
   irqReq <= r.reqIrq;

   -------------------------------
   -- Configuration Register
   -------------------------------  
   comb : process (axiReadMaster, axiWriteMaster, cntRst, dFifoCnt, dFifoDout, dFifoFull,
                   dFifoValid, dmaDescToPci, pciRst, r) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
      variable rdPntr       : natural;
      variable wrPntr       : natural;
      variable i            : natural;
   begin
      -- Latch the current value
      v := r;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      -- Calculate the address pointers
      wrPntr := conv_integer(axiWriteMaster.awaddr(5 downto 2));
      rdPntr := conv_integer(axiReadMaster.araddr(5 downto 2));

      -- Reset strobe signals
      v.dFifoWr := (others => '0');
      v.dFifoRd := (others => '0');
      v.doneAck := (others => '0');
      v.reqIrq  := '0';
      
      -----------------------------
      -- AXI-Lite Write Logic
      -----------------------------      
      if (axiStatus.writeEnable = '1') then
         v.wrDone := '1';
         -- Check for alignment
         if axiWriteMaster.awaddr(1 downto 0) = "00" then
            -- Address is aligned
            axiWriteResp := AXI_RESP_OK_C;
            -- Decode address and perform write
            if (axiWriteMaster.awaddr(9 downto 6) = x"0") and (wrPntr < DMA_SIZE_G) then
               if r.wrDone = '0' then
                  v.lastDesc              := axiWriteMaster.wdata(31 downto 2);
                  v.dFifoDin(31 downto 2) := axiWriteMaster.wdata(31 downto 2);
                  v.dFifoWr(wrPntr)       := '1';
                  if axiWriteMaster.wdata(31 downto 2) = r.lastDesc then
                     v.lastDescErr := '1';
                  end if;
               end if;
            elsif axiWriteMaster.awaddr(9 downto 2) = x"40" then
               v.rxFreeEn := axiWriteMaster.wdata(31);
               v.maxFrame := axiWriteMaster.wdata(23 downto 0);
            elsif axiWriteMaster.awaddr(9 downto 2) = x"41" then
               v.rxSize   := axiWriteMaster.wdata( 9 downto 0);
            else
               axiWriteResp := AXI_ERROR_RESP_G;
            end if;
         else
            axiWriteResp := AXI_ERROR_RESP_G;
         end if;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      else
         v.wrDone := '0';
      end if;

      -----------------------------
      -- AXI-Lite Read Logic
      -----------------------------      
      if (axiStatus.readEnable = '1') then
         v.rdDone             := '1';
         -- Reset the bus
         v.axiReadSlave.rdata := (others => '0');
         -- Check for alignment
         if axiReadMaster.araddr(1 downto 0) = "00" then
            -- Address is aligned
            axiReadResp := AXI_RESP_OK_C;
            -- Decode address and perform write
            if (axiReadMaster.araddr(9 downto 6) = x"1") and (rdPntr < DMA_SIZE_G) then
               v.axiReadSlave.rdata(31)         := dFifoFull (rdPntr);
               v.axiReadSlave.rdata(30)         := dFifoValid(rdPntr);
               v.axiReadSlave.rdata(9 downto 0) := dFifoCnt(rdPntr);
            else
               case (axiReadMaster.araddr(9 downto 2)) is
                  when x"40" =>
                     v.axiReadSlave.rdata(31)          := r.rxFreeEn;
                     v.axiReadSlave.rdata(23 downto 0) := r.maxFrame;
                  when x"41" =>
                     v.axiReadSlave.rdata( 9 downto  0) :=  r.rxSize;
                  when x"42" =>
                     v.axiReadSlave.rdata := r.rxCount;
                  when x"43" =>
                     v.axiReadSlave.rdata := r.lastDesc & '0' & r.lastDescErr;
                  when others =>
                     axiReadResp := AXI_ERROR_RESP_G;
               end case;
            end if;
         else
            -- Address is not aligned
            axiReadResp := AXI_ERROR_RESP_G;
         end if;
         -- Send AXI response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      else
         v.rdDone := '0';
      end if;

      -----------------------------
      -- New Descriptor allocation
      -----------------------------
      for i in 0 to (DMA_SIZE_G-1) loop
         -- Not reading FIFO
         if (r.dFifoRd(i) = '0') then
            -- Look for a new request and valid data to send
            if dmaDescToPci(i).doneReq = '1' then
               v.dFifoRd(i) := '1';
               v.doneAck(i) := '1';
               v.rxCount    := r.rxCount+1;
            end if;
         end if;
         -----------------------------
         -- Generate interrupt
         -----------------------------
         if (r.rxFreeEn = '1') and (dFifoCnt(i) < r.rxSize) then
            v.reqIrq := '1';
         end if;
      end loop;

      -----------------------------
      -- Reset RX counter
      -----------------------------
      if cntRst = '1' then
         v.rxCount := (others => '0');
      end if;

      -----------------------------
      -- FIFO reset
      -----------------------------
      v.fifoRst := not(r.rxFreeEn);

      -- Synchronous Reset
      if pciRst = '1' then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   GEN_FIFO :
   for i in 0 to (DMA_SIZE_G-1) generate
      -- FIFO for free descriptors
      -- 31:2  = Address
      U_DescFifo : entity work.FifoSync
         generic map(
            BRAM_EN_G    => true,
            FWFT_EN_G    => true,
            DATA_WIDTH_G => 30,
            ADDR_WIDTH_G => 10)
         port map (
            rst        => r.fifoRst,
            clk        => pciClk,
            din        => r.dFifoDin(31 downto 2),
            wr_en      => r.dFifoWr(i),
            rd_en      => r.dFifoRd(i),
            dout       => dFifoDout(i)(31 downto 2),
            full       => dFifoFull(i),
            valid      => dFifoValid(i),
            data_count => dFifoCnt(i));     

      -- New Ack
      dmaDescFromPci(i).newAck  <= dFifoValid(i);

      -- Address
      dmaDescFromPci(i).newAddr <= dFifoDout(i)(31 downto 2);

      -- Max Frame
      dmaDescFromPci(i).maxFrame <= r.maxFrame;

      -- Unused fields
      dmaDescFromPci(i).newLength <= (others => '0');
      dmaDescFromPci(i).newDmaCh  <= (others => '0');
      dmaDescFromPci(i).newSubCh  <= (others => '0');

      -- Done Ack
      dmaDescFromPci(i).doneAck <= r.doneAck(i);

   end generate GEN_FIFO;

end rtl;
