-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCardG2PciFrontEnd.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-24
-- Last update: 2017-03-04
-- Platform   : Vivado 2015.1
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.SsiPciePkg.all;

library unisim;
use unisim.vcomponents.all;

entity EvrCardG2PciFrontEnd is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- PCIe Interface      
      cfgFromPci  : out PcieCfgOutType;
      cfgToPci    : in  PcieCfgInType;
      pciIbMaster : in  AxiStreamMasterType;
      pciIbSlave  : out AxiStreamSlaveType;
      pciObMaster : out AxiStreamMasterType;
      pciObSlave  : in  AxiStreamSlaveType;
      -- Clock and Reset Signals
      pciClk      : out sl;
      pciRst      : out sl;
      pciLinkUp   : out sl;
      -- PCIe Ports 
      pciRstL     : in  sl;
      pciRefClkP  : in  sl;
      pciRefClkN  : in  sl;
      pciRxP      : in  slv(3 downto 0);
      pciRxN      : in  slv(3 downto 0);
      pciTxP      : out slv(3 downto 0);
      pciTxN      : out slv(3 downto 0));     
end EvrCardG2PciFrontEnd;

architecture mapping of EvrCardG2PciFrontEnd is

   signal pciRefClk : sl;
   signal sysRstL   : sl;
   signal locClk    : sl;
   signal userRst   : sl;
   signal locRst    : sl;
   signal userLink  : sl;

   signal rxBarHit     : slv(7 downto 0);
   signal pciRxOutUser : slv(21 downto 0);

   signal ibMaster : AxiStreamMasterType;
   signal ibSlave  : AxiStreamSlaveType;
   signal obMaster : AxiStreamMasterType;
   signal obSlave  : AxiStreamSlaveType;
   
begin

   pciClk <= locClk;
   pciRst <= locRst;

   Synchronizer_userRst : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => userRst,
         dataOut => locRst);     

   Synchronizer_userLink : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => userLink,
         dataOut => pciLinkUp); 

   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map(
         I     => pciRefClkP,
         IB    => pciRefClkN,
         CEB   => '0',
         O     => pciRefClk,
         ODIV2 => open);        

   IBUF_Inst : IBUF
      port map(
         I => pciRstL,
         O => sysRstL);          

   PcieCore_Inst : entity work.EvrCardG2PciIpCore
      port map(
         -------------------------------------
         -- PCI Express (pci_exp) Interface --
         -------------------------------------
         -- TX
         pci_exp_txp      => pciTxP,
         pci_exp_txn      => pciTxN,
         -- RX
         pci_exp_rxp      => pciRxP,
         pci_exp_rxn      => pciRxN,

--         int_pclk_sel_slave => (others=>'0'),  -- Added for PCI core v3.3
--         fc_sel             => (others=>'0'),
         ---------------------
         -- AXI-S Interface --
         ---------------------
         -- Common
         user_clk_out     => locClk,
         user_reset_out   => userRst,
         user_lnk_up      => userLink,
         user_app_rdy     => open,
         -- TX
         s_axis_tx_tready => ibSlave.tReady,
         s_axis_tx_tdata  => ibMaster.tData(63 downto 0),
         s_axis_tx_tkeep  => ibMaster.tKeep(7 downto 0),
         s_axis_tx_tlast  => ibMaster.tLast,
         s_axis_tx_tvalid => ibMaster.tValid,
         s_axis_tx_tuser  => "0000",
         -- RX
         m_axis_rx_tdata  => obMaster.tData(63 downto 0),
         m_axis_rx_tkeep  => obMaster.tKeep(7 downto 0),
         m_axis_rx_tlast  => obMaster.tLast,
         m_axis_rx_tvalid => obMaster.tValid,
         m_axis_rx_tready => obSlave.tReady,
         m_axis_rx_tuser  => pciRxOutUser,

         tx_cfg_gnt             => '1',  -- Always allow transmission of Config traffic within block
         rx_np_ok               => '1',  -- Allow Reception of Non-posted Traffic
         rx_np_req              => '1',  -- Always request Non-posted Traffic if available
         cfg_trn_pending        => cfgToPci.trnPending,
         cfg_pm_halt_aspm_l0s   => '0',  -- Allow entry into L0s
         cfg_pm_halt_aspm_l1    => '0',  -- Allow entry into L1
         cfg_pm_force_state_en  => '0',  -- Do not qualify cfg_pm_force_state
         cfg_pm_force_state     => "00",  -- Do not move force core into specific PM state
         cfg_dsn                => cfgToPci.serialNumber,
         cfg_turnoff_ok         => cfgToPci.turnoffOk,
         cfg_pm_wake            => '0',  -- Never direct the core to send a PM_PME Message
         cfg_pm_send_pme_to     => '0',
         cfg_ds_bus_number      => x"00",
         cfg_ds_device_number   => "00000",
         cfg_ds_function_number => "000",

         cfg_device_number         => cfgFromPci.deviceNumber,
         cfg_dcommand2             => open,
         cfg_pmcsr_pme_status      => open,
         cfg_status                => cfgFromPci.status,
         cfg_to_turnoff            => cfgFromPci.toTurnOff,
         cfg_received_func_lvl_rst => open,
         cfg_dcommand              => cfgFromPci.dCommand,
         cfg_bus_number            => cfgFromPci.busNumber,
         cfg_function_number       => cfgFromPci.functionNumber,
         cfg_command               => cfgFromPci.command,
         cfg_dstatus               => cfgFromPci.dStatus,
         cfg_lstatus               => cfgFromPci.lStatus,
         cfg_pcie_link_state       => cfgFromPci.linkState,
         cfg_lcommand              => cfgFromPci.lCommand,
         cfg_pmcsr_pme_en          => open,
         cfg_pmcsr_powerstate      => open,
         tx_buf_av                 => open,
         tx_err_drop               => open,
         tx_cfg_req                => open,

         cfg_bridge_serr_en                         => open,
         cfg_slot_control_electromech_il_ctl_pulse  => open,
         cfg_root_control_syserr_corr_err_en        => open,
         cfg_root_control_syserr_non_fatal_err_en   => open,
         cfg_root_control_syserr_fatal_err_en       => open,
         cfg_root_control_pme_int_en                => open,
         cfg_aer_rooterr_corr_err_reporting_en      => open,
         cfg_aer_rooterr_non_fatal_err_reporting_en => open,
         cfg_aer_rooterr_fatal_err_reporting_en     => open,
         cfg_aer_rooterr_corr_err_received          => open,
         cfg_aer_rooterr_non_fatal_err_received     => open,
         cfg_aer_rooterr_fatal_err_received         => open,
         cfg_vc_tcvc_map                            => open,
         -- EP Only
         cfg_interrupt                              => cfgToPci.irqReq,
         cfg_interrupt_rdy                          => cfgFromPci.irqAck,
         cfg_interrupt_assert                       => cfgToPci.irqAssert,
         cfg_interrupt_di                           => (others => '0'),  -- Do not set interrupt fields
         cfg_interrupt_do                           => open,
         cfg_interrupt_mmenable                     => open,
         cfg_interrupt_msienable                    => open,
         cfg_interrupt_msixenable                   => open,
         cfg_interrupt_msixfm                       => open,
         cfg_interrupt_stat                         => '0',  -- Never set the Interrupt Status bit
         cfg_pciecap_interrupt_msgnum               => "00000",  -- Zero out Interrupt Message Number             
         ---------------------------
         -- System(SYS) Interface --
         ---------------------------
         sys_clk                                    => pciRefClk,
         sys_rst_n                                  => sysRstL);       

   -- Receive BAR Hit: Indicates BAR(s) targeted by the current 
   -- receive transaction. Asserted from the beginning of the 
   -- packet to m_axis_rx_tlast.
   rxBarHit(7 downto 0) <= pciRxOutUser(9 downto 2);
   process(rxBarHit)
   begin
      -- Encode bar hit value
      if rxBarHit(0) = '1' then
         obMaster.tDest <= x"00";
      elsif rxBarHit(1) = '1' then
         obMaster.tDest <= x"01";
      elsif rxBarHit(2) = '1' then
         obMaster.tDest <= x"02";
      elsif rxBarHit(3) = '1' then
         obMaster.tDest <= x"03";
      elsif rxBarHit(4) = '1' then
         obMaster.tDest <= x"04";
      elsif rxBarHit(5) = '1' then
         obMaster.tDest <= x"05";
      elsif rxBarHit(6) = '1' then
         obMaster.tDest <= x"06";
      else
         obMaster.tDest <= x"07";
      end if;
   end process;

   FIFO_TX : entity work.SsiInsertSof
      generic map (
         TPD_G               => TPD_G,
         COMMON_CLK_G        => true,
         INSERT_USER_HDR_G   => false,
         SLAVE_FIFO_G        => true,
         MASTER_FIFO_G       => false,
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(8),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(16))       
      port map (
         -- Slave Port
         sAxisClk    => locClk,
         sAxisRst    => locRst,
         sAxisMaster => obMaster,
         sAxisSlave  => obSlave,
         -- Master Port
         mAxisClk    => locClk,
         mAxisRst    => locRst,
         mAxisMaster => pciObMaster,
         mAxisSlave  => pciObSlave);

   FIFO_RX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(16),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(8))            
      port map (
         -- Slave Port
         sAxisClk    => locClk,
         sAxisRst    => locRst,
         sAxisMaster => pciIbMaster,
         sAxisSlave  => pciIbSlave,
         -- Master Port
         mAxisClk    => locClk,
         mAxisRst    => locRst,
         mAxisMaster => ibMaster,
         mAxisSlave  => ibSlave);   

end mapping;
