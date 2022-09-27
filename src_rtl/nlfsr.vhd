--------------------------------------------------------------------------------
--! @file       nlfsr.vhd
--! @brief      Implementation of a non-linear shift register used for TinyJAMBU
--!             Protected using DOM
--! @author     Sammy Lin
--! @modified by Abubakr Abdulgadir
--! @copyright  Copyright (c) 2020 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
use work.design_pkg.all;

entity nlfsr is
    port(
        clk       : in  std_logic;
        reset     : in  std_logic;
        enable    : in  std_logic;
        key       : in  data_array;
        load      : in  std_logic;
        din       : in  data_array;
        dout      : out data_array;
        rnd       : in  std_logic_vector(CCRW - 1 downto 0);
        cycle_odd : in  std_logic
    );

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of nlfsr : entity is "true";
end entity nlfsr;

architecture behav of nlfsr is
    --============================================
    signal and_x   : share_array;
    signal and_y   : share_array;
    signal and_out : share_array;
    signal mul_en  : std_logic;
    --============================================

    attribute DONT_TOUCH of behav : architecture is "true";

    attribute DONT_TOUCH of and_x : signal is "true";
    attribute DONT_TOUCH of and_y : signal is "true";
    attribute DONT_TOUCH of and_out : signal is "true";

begin
    mul_en <= enable and not cycle_odd;

    GEN_DOM: if SCA_GADGET = DOM generate
        INST_DOM_MUL : entity work.dom_mul
        port map(
            clk => clk,
            en  => mul_en,
            x   => and_x,
            y   => and_y,
            z   => rnd,
            q   => and_out
        );
    end generate;
        
    GEN_HPC3: if SCA_GADGET = HPC3 or SCA_GADGET = HPC3_PLUS generate
        INST_HPC3_MUL : entity work.hpc3_mul
            generic map(
                G_ORDER        => NUM_SHARES - 1,
                G_W            => SHARE_WIDTH,
                G_PLUS         => SCA_GADGET = HPC3_PLUS,
                G_PLUS_OUT_REG => false
            )
            port map(
                clk => clk,
                en  => mul_en,
                x   => and_x,
                y   => and_y,
                r   => rnd,
                z   => and_out
            );
    end generate;

    reg_feed_gen : for i in 0 to NUM_SHARES - 1 generate
        reg_feed_i : entity work.nlfsr_reg_feed
            generic map(
                CONST_ADD => i = 0
            )
            port map(
                clk     => clk,
                reset   => reset,
                enable  => enable,
                key     => key(i),
                load    => load,
                din     => din(i),
                dout    => dout(i),
                and_x   => and_x(i),
                and_y   => and_y(i),
                and_out => and_out(i)
            );
    end generate;

end architecture behav;
