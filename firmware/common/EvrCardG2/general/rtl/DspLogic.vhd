-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : DspLogic.vhd
-- Author     : Matt Weaver <weaver@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-01-04
-- Last update: 2017-05-11
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


library surf;
use surf.StdRtlPkg.all;
use work.DspLogicPkg.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity DspLogic is
  generic ( AREG : natural := 0;
            BREG : natural := 0 );
  port ( clk   : in  sl;
         op    : in  DspLogicOpType;
         A     : in  slv(47 downto 0) := (others=>'0');
         B     : in  slv(47 downto 0) := (others=>'0');
         PCin  : in  slv(47 downto 0) := (others=>'0');
         PCout : out slv(47 downto 0);
         P     : out slv(47 downto 0);
         Pzero : out sl);
end DspLogic;

architecture rtl of DspLogic is

  signal alumode : slv(3 downto 0);
  signal opmode  : slv(6 downto 0);
  constant CEA1  : sl := ite(AREG>1,'1','0');
  constant CEA2  : sl := ite(AREG>0,'1','0');
  constant CEB   : sl := ite(BREG>0,'1','0');

begin

  assert (AREG < 3) report "AREG parameter limited to 0..2" severity error;
  assert (BREG < 2) report "BREG parameter limited to 0..1" severity error;

  U_DSP : DSP48E1
     generic map ( ACASCREG   => AREG,  -- unused
                   ADREG      => 0,
                   ALUMODEREG => 0,
                   AREG       => AREG,  -- no regs before ADD
                   BCASCREG   => AREG,
                   BREG       => AREG,
                   CARRYINREG => 0,
                   CARRYINSELREG => 0,
                   CREG       => BREG,
                   DREG       => 0,
                   INMODEREG  => 0,
                   MREG       => 0,
                   OPMODEREG  => 0,
                   PREG       => 1,
                   USE_MULT   => "NONE",
                   MASK       => X"000000000000",  -- compare all bits of P to 0
                   PATTERN    => X"000000000000",  -- compare all bits of P to 0
                   USE_PATTERN_DETECT => "PATDET" )
     port map (
       P                            => P,
       A                            => A(47 downto 18),
       ACIN                         => (others=>'0'),
       ALUMODE                      => alumode,
       B                            => A(17 downto 0),
       BCIN                         => (others=>'0'),
       C                            => B,
       CARRYCASCIN                  => '0',
       CARRYIN                      => '0',
       CARRYINSEL                   => "000",
       CEA1                         => CEA1,
       CEA2                         => CEA2,
       CEAD                         => '0',
       CEALUMODE                    => '1',
       CEB1                         => CEA1,
       CEB2                         => CEA2,
       CEC                          => CEB,
       CECARRYIN                    => '0',
       CECTRL                       => '1',
       CED                          => '0',
       CEINMODE                     => '1',
       CEM                          => '0',
       CEP                          => '1',
       CLK                          => clk,
       D                            => (others=>'0'),
       INMODE                       => "00000",
       MULTSIGNIN                   => '0',
       OPMODE                       => opmode,
       PCIN                         => PCin,
       PCOUT                        => PCout,
       RSTA                         => '0',
       RSTALLCARRYIN                => '0',
       RSTALUMODE                   => '0',
       RSTB                         => '0',
       RSTC                         => '0',
       RSTCTRL                      => '0',
       RSTD                         => '0',
       RSTINMODE                    => '0',
       RSTM                         => '0',
       RSTP                         => '0',
       PATTERNDETECT                => Pzero
       );

  comb : process ( op ) is
  begin
    case op is
      --  opmode(1:0) : X mux out
      --    "00"          0
      --    "10"          P
      --    "11"         A:B
      --  opmode(6:4) : Z mux out
      --   "000"          0
      --   "001"         PCin
      --   "010"          P
      --   "011"          C
      --  opmode(3:2) : alumode : op
      --    "00"        "1100"     X and Z
      --    "00"        "1101"     X and not Z
      --    "10"        "1100"     X or Z
      --    "10"        "1111"     not X and Z
      when OP_Hold =>  -- P = P and P
        opmode  <= "0100010";
        alumode <= "1100";
      when OP_Clear => -- P = 0 and 0
        opmode  <= "0000000";
        alumode <= "1100";
      when OP_A =>     -- P = A or 0
        opmode  <= "0001011";
        alumode <= "1100";
      when OP_B =>     -- P = 0 or C
        opmode  <= "0111000";
        alumode <= "1100";
      when OP_AandB => -- P = A and C
        opmode  <= "0110011";
        alumode <= "1100";
      when OP_AandNotB => -- P = A and not C
        opmode  <= "0110011";
        alumode <= "1101";
      when OP_OrA =>   -- P = A or P
        opmode  <= "0101011";
        alumode <= "1100";
      when OP_AndNotB => -- P = P and not C
        opmode  <= "0110010";
        alumode <= "1101";
      when others =>
        null;
    end case;
  end process;

end rtl;
