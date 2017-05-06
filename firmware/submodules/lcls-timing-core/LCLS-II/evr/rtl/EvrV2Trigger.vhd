-------------------------------------------------------------------------------
-- Title         : EvrV2Trigger
-- Project       : LCLS-II Timing Pattern Generator
-------------------------------------------------------------------------------
-- File          : EvrV2Trigger.vhd
-- Author        : Matt Weaver, weaver@slac.stanford.edu
-- Created       : 01/23/2016
-------------------------------------------------------------------------------
-- Description:
-- Pipeline of trigger output state.  The trigger output activates config.delay
-- plus 5 clk ticks after fire is asserted and deasserts after config.width clk
-- ticks.  The FIFO allows up to 127 triggers to be pipelined.  Individual
-- trigger delays and widths have 20 bits range, provided the 127 trigger
-- pipelining is not exceeded.
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 Timing Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 01/23/2016: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.all;
use work.TPGPkg.all;
use work.StdRtlPkg.all;
use work.TimingPkg.all;
use work.EvrV2Pkg.all;

entity EvrV2Trigger is
  generic ( TPD_G        : time := 1 ns;
            CHANNELS_C   : integer := 1;
            TRIG_DEPTH_C : integer := 16;
            DEBUG_C      : boolean := false);
  port (
      clk        : in  sl;
      rst        : in  sl;
      config     : in  EvrV2TriggerConfigType;
      arm        : in  slv(CHANNELS_C-1 downto 0);
      fire       : in  sl;
      trigstate  : out sl );
end EvrV2Trigger;

architecture EvrV2Trigger of EvrV2Trigger is

   type RegType is record
     fifo_delay     : slv(EVRV2_TRIG_WIDTH-1 downto 0);      -- clks until trigger fifo is empty
     armed          : sl;
     delay          : slv(EVRV2_TRIG_WIDTH-1 downto 0);
     width          : slv(EVRV2_TRIG_WIDTH-1 downto 0);
     fired          : sl;
     state          : sl;
     fifoReset      : sl;
     fifoWr         : sl;
     fifoRd         : sl;
     fifoDin        : slv(EVRV2_TRIG_WIDTH-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
     fifo_delay => (others=>'0'),
     armed      => '0',
     delay      => (others=>'0'),
     width      => (others=>'0'),
     fired      => '0',
     state      => '0',
     fifoReset  => '1',
     fifoWr     => '0',
     fifoRd     => '0',
     fifoDin    => (others=>'0'));
   
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fifoValid : sl;
   signal fifoDout  : slv(EVRV2_TRIG_WIDTH-1 downto 0);
   signal fifoCount : slv(8 downto 0);
   signal fifoEmpty : sl;
   signal fifoFull  : sl;
   
   component ila_0
    PORT ( clk         : IN STD_LOGIC;
           probe0      : IN STD_LOGIC_VECTOR(255 DOWNTO 0) );
   end component;

begin

   G_ila: if DEBUG_C=true generate
     U_ila : ila_0
       port map ( clk       => clk,
                  probe0(0) => rst,
                  probe0(1) => fifoValid,
                  probe0(2) => fire,
                  probe0(3) => r.state,
                  probe0(4) => r.armed,
                  probe0(5) => r.fired,
                  probe0(6) => r.fifoReset,
                  probe0(7) => r.fifoWr,
                  probe0(8) => r.fifoRd,
                  probe0( 48 downto   9) => r.fifoDin,
                  probe0( 88 downto  49) => fifoDout,
                  probe0(108 downto  89) => r.delay,
                  probe0(128 downto 109) => r.width,
                  probe0(156 downto 129) => r.fifo_delay,
                  probe0(176 downto 157) => config.delay,
                  probe0(196 downto 177) => config.width,
                  probe0(200 downto 197) => config.channel,
                  probe0(201)            => config.enabled,
                  probe0(208 downto 202) => fifoCount,
                  probe0(209)            => fifoEmpty,
                  probe0(210)            => fifoFull,
                  probe0(210+CHANNELS_C downto 211) => arm,
                  probe0(255 downto 211+CHANNELS_C) => (others=>'0') );
   end generate G_ila;
   
   trigstate <= r.state;

   U_Fifo : entity work.FifoSync
     generic map ( TPD_G        => TPD_G,
                   DATA_WIDTH_G => EVRV2_TRIG_WIDTH,
                   ADDR_WIDTH_G => bitSize(TRIG_DEPTH_C),
                   FWFT_EN_G    => false )
     port map (    rst   => r.fifoReset,
                   clk   => clk,
                   wr_en => rin.fifoWr,
                   rd_en => rin.fifoRd,
                   din   => rin.fifoDin,
                   dout  => fifoDout,
                   valid => fifoValid,
                   empty => fifoEmpty,
                   full  => fifoFull,
                   data_count => fifoCount );

   process (r, arm, fire, rst, config, fifoValid, fifoDout, fifoEmpty)
      variable v : RegType;
   begin 
      v := r;

      v.state     := not config.polarity;
      v.fifoReset := '0';
      v.fifoRd    := '0';

      if allBits(r.delay,'0') then
        if allBits(r.width,'0') then
          if r.fifoRd='1' then
            v.width  := config.width;
            v.delay  := fifoDout;
          elsif fifoEmpty='0' then
            v.fifoRd := '1';
          end if;
        else
          v.width  := r.width-1;
          v.state  := config.polarity;
        end if;
      else
        v.delay  := r.delay-1;
      end if;
      
      if fire = '1' and r.armed = '1' then
         v.armed      := '0';
         v.fifoWr     := '1';
         v.fifoDin    := config.delay - r.fifo_delay;
         v.fifo_delay := config.delay + config.width + 1;
      else
         v.fifoWr     := '0';
         if not allBits(r.fifo_delay,'0') then
           v.fifo_delay := r.fifo_delay - 1;
         end if;
      end if;

      if arm(conv_integer(config.channel)) = '1' then
         v.armed := '1';
      end if;

      if rst='1' or config.enabled='0' then
         v := REG_INIT_C;
      end if;
      
      rin <= v;
   end process;

   process (clk)
   begin
     if rising_edge(clk) then
       r <= rin;
     end if;
   end process;

end EvrV2Trigger;

