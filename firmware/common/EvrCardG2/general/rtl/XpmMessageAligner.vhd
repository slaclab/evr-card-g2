-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: This module produces a realigned timing bus and XPM partition words
-------------------------------------------------------------------------------
-- This file is part of 'L2SI Core'. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'L2SI Core', including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.EvrV2Pkg.all;

library l2si_core;
use l2si_core.XpmPkg.all;
use l2si_core.XpmExtensionPkg.all;

library unisim;
use unisim.vcomponents.all;

entity XpmMessageAligner is
   generic (
      TPD_G      : time    := 1 ns;
      TF_DELAY_G : integer := 100;
      CHANNELS_G : integer );
   port (
      clk : in sl;
      rst : in sl;

      -- Prompt timing data
      xpm_msg             : in XpmMessageType;     -- prompt
      config              : in EvrV2ChannelConfigArray(CHANNELS_G-1 downto 0);
      strobe_in           : in sl;
      timing_in           : in TimingMessageType;  -- prompt
      sel_in              : in slv(CHANNELS_G-1 downto 0);
      
      -- Aligned timing data
      strobe_out         : out sl;
      timing_out         : out TimingMessageType;  -- delayed
      sel_out            : out slv(CHANNELS_G-1 downto 0) );
end XpmMessageAligner;

architecture rtl of XpmMessageAligner is

   constant TF_DELAY_SLV_C : slv(6 downto 0) := toSlv(TF_DELAY_G, 7);

   type RegType is record
     partitionDelays : Slv7Array(XPM_PARTITIONS_C-1 downto 0);
     strobe          : sl;
     sel             : slv(CHANNELS_G-1 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
     partitionDelays => (others => (others => '0')),
     strobe          => '0',
     sel             => (others=>'0') );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal promptTimingMessage        : TimingMessageType;
   signal alignedTimingMessage       : TimingMessageType;
   
   signal promptTimingMessageSlv  : slv(TIMING_MESSAGE_BITS_C-1 downto 0);
   signal alignedTimingMessageSlv : slv(TIMING_MESSAGE_BITS_C-1 downto 0);

   -- partition delay with TF_DELAY_G offset applied
   signal partitionDelays : Slv7Array (XPM_PARTITIONS_C-1 downto 0);
   signal sel_i           : Slv16Array(XPM_PARTITIONS_C   downto 0);
   signal sel_o           : Slv16Array(XPM_PARTITIONS_C   downto 0);

begin

   strobe_out <= r.strobe;
   sel_out    <= r.sel;
   timing_out <= alignedTimingMessage;
   
   -----------------------------------------------
   -- Timing message delay
   -- Delay timing message by 100 (us) (nominal)
   -----------------------------------------------
   promptTimingMessage    <= timing_in;
   promptTimingMessageSlv <= toSlv(promptTimingMessage);
   
   U_SlvDelay_0 : entity surf.SlvDelay
      generic map (
         TPD_G        => TPD_G,
         SRL_EN_G     => true,
         DELAY_G      => TF_DELAY_G+1,
         REG_OUTPUT_G => false,
         WIDTH_G      => TIMING_MESSAGE_BITS_C)
      port map (
         clk  => clk,                       -- [in]
         en   => strobe_in,                 -- [in]
         din  => promptTimingMessageSlv,    -- [in]
         dout => alignedTimingMessageSlv);  -- [out]

   U_SlvDelay_1 : entity surf.SlvDelay
      generic map (
         TPD_G        => TPD_G,
         SRL_EN_G     => true,
         DELAY_G      => TF_DELAY_G+1,
         REG_OUTPUT_G => false,
         WIDTH_G      => 16)
      port map (
         clk  => clk,                       -- [in]
         en   => strobe_in,                 -- [in]
         din  => sel_i(XPM_PARTITIONS_C),   -- [in]
         dout => sel_o(XPM_PARTITIONS_C));  -- [out]

   alignedTimingMessage <= toTimingMessageType(alignedTimingMessageSlv);

   -----------------------------------------------
   -- Partition word delay
   -- Each of the 8 partition words is delayed by
   -- 100 - (r.partitionDelay(i))
   -- Partition words may arrive later than their
   -- corresponding timing message so this gets
   -- them back into alignment
   -----------------------------------------------

   sel_i(XPM_PARTITIONS_C) <= resize(sel_in,16);
   
   GEN_PART : for i in 0 to XPM_PARTITIONS_C-1 generate

      partitionDelays(i) <= TF_DELAY_SLV_C - r.partitionDelays(i);
      sel_i          (i) <= resize(sel_in,16);
      
      U_SlvDelay_2 : entity surf.SlvDelay
         generic map (
            TPD_G        => TPD_G,
            SRL_EN_G     => true,
            DELAY_G      => 128, --TF_DELAY_G+1,
            REG_OUTPUT_G => false,
            WIDTH_G      => 16 )
         port map (
            clk               => clk,                                 -- [in]
            en                => strobe_in,                           -- [in]
            delay             => partitionDelays(i),                  -- [in]
            din               => sel_i(i),                            -- [in]
            dout              => sel_o(i));                           -- [out]
   end generate;

   comb : process(xpm_msg, strobe_in, config, sel_o, r, rst) is
      variable v                : RegType;
      variable broadcastMessage : XpmBroadcastType;
   begin
      v := r;
      v.strobe := strobe_in;
      
      if strobe_in = '1' then
         -- Update partitionDelays values when partitionAddr indicates new PDELAYs
         broadcastMessage := toXpmBroadcastType(xpm_msg.partitionAddr);
         if (broadcastMessage.btype = XPM_BROADCAST_PDELAY_C) then
            v.partitionDelays(broadcastMessage.index) := broadcastMessage.value;
         end if;
      end if;

      if True then
        for i in 0 to CHANNELS_G-1 loop
          if config(i).rateSel(12 downto 11)="11" then
            v.sel(i) := sel_o(conv_integer(config(i).rateSel(2 downto 0)))(i);
          else
            v.sel(i) := sel_o(XPM_PARTITIONS_C)(i);
          end if;
        end loop;
      end if;
      
      if rst = '1' then
         v      := REG_INIT_C;
      end if;

      rin <= v;
   end process;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process;

end rtl;
