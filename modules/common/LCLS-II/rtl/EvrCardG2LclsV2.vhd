-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2LclsV2.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-09
-- Last update: 2015-07-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity EvrCardG2LclsV2 is
   generic (
      TPD_G : time := 1 ns); 
   port (
      -- AXI-Lite and IRQ Interface
      axiClk              : in  sl;
      axiRst              : in  sl;
      sAxiLiteWriteMaster : in  AxiLiteWriteMasterType;
      sAxiLiteWriteSlave  : out AxiLiteWriteSlaveType;
      sAxiLiteReadMaster  : in  AxiLiteReadMasterType;
      sAxiLiteReadSlave   : out AxiLiteReadSlaveType;
      irqActive           : in  sl;
      irqEnable           : out sl;
      irqReq              : out sl;
      -- EVR Ports
      evrRefClkP          : in  sl;
      evrRefClkN          : in  sl;
      evrRxP              : in  sl;
      evrRxN              : in  sl;
      evrTxP              : out sl;
      evrTxN              : out sl;
      evrDebugClk         : out slv(1 downto 0);
      -- Trigger and Sync Port
      syncL               : in  sl;
      trigOut             : out slv(11 downto 0);
      -- Misc.
      cardRst             : in  sl;
      ledRedL             : out sl;
      ledGreenL           : out sl;
      ledBlueL            : out sl);  
end EvrCardG2LclsV2;

architecture mapping of EvrCardG2LclsV2 is

   signal evrClk   : sl;
   signal evrRst   : sl;
   signal rxLinkUp : sl;
   signal rxError  : sl;
   signal rxData   : slv(15 downto 0);
   signal rxDataK  : slv(1 downto 0);

begin

   -- Undefined signals
   ledRedL   <= '1';
   ledGreenL <= '1';
   ledBlueL  <= '1';
   trigOut   <= x"000";
   irqEnable <= '0';
   irqReq    <= '0';

   AxiLiteEmpty_Inst : entity work.AxiLiteEmpty
      generic map (
         TPD_G => TPD_G) 
      port map (
         -- Local Bus
         axiClk         => axiClk,
         axiClkRst      => axiRst,
         axiWriteMaster => sAxiLiteWriteMaster,
         axiWriteSlave  => sAxiLiteWriteSlave,
         axiReadMaster  => sAxiLiteReadMaster,
         axiReadSlave   => sAxiLiteReadSlave);

   EvrCardG2Gtx_Inst : entity work.EvrCardG2Gtx
      generic map (
         TPD_G         => TPD_G,
         EVR_VERSION_G => true) 
      port map (
         -- EVR Ports
         evrRefClkP  => evrRefClkP,
         evrRefClkN  => evrRefClkN,
         evrRxP      => evrRxP,
         evrRxN      => evrRxN,
         evrTxP      => evrTxP,
         evrTxN      => evrTxN,
         evrDebugClk => evrDebugClk,
         -- EVR Interface
         evrClk      => evrClk,
         evrRst      => evrRst,
         rxLinkUp    => rxLinkUp,
         rxError     => rxError,
         rxData      => rxData,
         rxDataK     => rxDataK);       

end mapping;
