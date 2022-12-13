-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrV2RefClk.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2022-04-01
-- Last update: 2022-09-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use ieee.NUMERIC_STD.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

entity EvrV2RefClk is
  generic (
    TPD_G          : time             := 1 ns );
  port (
    -- EVR Ports
    evrClk              : in  sl;
    evrRst              : in  sl;
    evrClkSel           : in  sl;
    -- Axi Lite interface
    axiClk              : in  sl;
    axiRst              : in  sl;
    axiReadMaster       : in  AxiLiteReadMasterType;
    axiReadSlave        : out AxiLiteReadSlaveType;
    axiWriteMaster      : in  AxiLiteWriteMasterType;
    axiWriteSlave       : out AxiLiteWriteSlaveType;
    refClkOut           : out sl );
end EvrV2RefClk;

architecture mapping of EvrV2RefClk is

  type RegType is record
    clk : sl;
  end record;

  constant REG_INIT_C : RegType := (
    clk => '0' );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;
  
  signal clk70, clko : sl;

  constant USE_REG_C : boolean := false;
  
begin  -- rtl

  --     LCLS-1 mode
  --       CLKFBOUT_MULT_G    => 10    -- FVCO = 1190 MHz
  --       CLKOUT0_DIVIDE_F_G => ite(USE_REG_C, 59.5, 119.0) -- 20MHz, 10MHz
  --     LCLS-2 mode
  --       CLKFBOUT_MULT_G    => 5.25  -- FVCO = 975 MHz
  --       CLKOUT0_DIVIDE_F_G => ite(USE_REG_C, 48.75, 97.5) -- 20MHz, 10MHz
  --     CBXFEL Gotthard reference
  --       DIVCLK_DIVIDE_G    => 7,
  --       CLKFBOUT_MULT_G    => 64.  -- FVCO = 1088 MHz
  --       CLKOUT0_DIVIDE_F_G => ite(USE_REG_C, 29.75, 59.5) -- 36-4/7MHz, 18-2/7MHz
  --
  --   Choose a set of parameters that pass DRC for both 119 and 186 MHz clkIn
  --
  U_CLK186 : entity surf.ClockManager7
    generic map ( INPUT_BUFG_G       => false,
                  NUM_CLOCKS_G       => 1,
                  CLKIN_PERIOD_G     => 5.4,
                  DIVCLK_DIVIDE_G    => 1,
                  CLKFBOUT_MULT_F_G  => 5.25,
                  CLKOUT0_DIVIDE_F_G => ite(USE_REG_C, 48.75, 97.5) )
    port map ( clkIn           => evrClk,
               clkOut(0)       => clko,
               axilClk         => axiClk,
               axilRst         => axiRst,
               axilReadMaster  => axiReadMaster,
               axilReadSlave   => axiReadSlave,
               axilWriteMaster => axiWriteMaster,
               axilWriteSlave  => axiWriteSlave );

  GEN_20MH : if USE_REG_C generate
    refClkOut <= r.clk;

    comb : process(r, evrRst) is
      variable v : RegType;
    begin
      v := r;
      v.clk := not r.clk;

      if evrRst = '1' then
        v := REG_INIT_C;
      end if;
      
      rin <= v;
    end process comb;
    
    seq: process (clko) is
    begin
      if rising_edge(clko) then
        r <= rin;
      end if;
    end process seq;
    
  end generate;
  
  NOGEN_REG : if not USE_REG_C generate
    --  Generate 10MHz clocks.  Done.
    refClkOut <= clko;
  end generate;
  
end mapping;
