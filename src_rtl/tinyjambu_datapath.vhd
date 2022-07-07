--------------------------------------------------------------------------------
--! @file       tinyjambu_datapath.vhd
--! @brief      Datapath for TinyJAMBU
--! @author     Sammy Lin
--! modified by Abubakr Abdulgadir
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
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity tinyjambu_datapath is
    port(
        clk             : in  std_logic;
        reset           : in  std_logic;
        nlfsr_load      : in  std_logic;
        partial         : in  std_logic;
        partial_bytes   : in  std_logic_vector(1 downto 0);
        partial_bdo_out : in  std_logic_vector(CCW / 8 - 1 downto 0);
        nlfsr_en        : in  std_logic;
        nlfsr_reset     : in  std_logic;
        decrypt         : in  std_logic;
        bdi             : in  T_BDIO_ARRAY;
        key             : in  T_KEY_ARRAY;
        key_load        : in  std_logic;
        key_index       : in  std_logic_vector(1 downto 0);
        fbits_sel       : in  std_logic_vector(1 downto 0);
        s_sel           : in  std_logic_vector(1 downto 0);
        bdo_sel         : in  std_logic;
        bdo             : out T_BDIO_ARRAY;
        rnd             : in  std_logic_vector(CCRW - 1 downto 0)
    );
end entity tinyjambu_datapath;

architecture behav of tinyjambu_datapath is

    attribute keep_hierarchy : string;
    attribute keep_hierarchy of behav : architecture is "true";

    signal nlfsr_key, nlfsr_din, nlfsr_dout : data_array;

    attribute keep : string;
    attribute keep of nlfsr_key : signal is "true";
    attribute keep of nlfsr_din : signal is "true";
    attribute keep of nlfsr_dout : signal is "true";

begin

    gen_ops : for i in 0 to NUM_SHARES - 1 generate
        dp_ops : entity work.tinyjambu_dp_ops(behav)
            generic map(
                CONST_ADD => i = 0
            )
            port map(
                clk             => clk,
                partial         => partial,
                partial_bytes   => partial_bytes,
                partial_bdo_out => partial_bdo_out,
                decrypt         => decrypt,
                bdi             => bdi(i),
                key             => key(i),
                key_load        => key_load,
                key_index       => key_index,
                fbits_sel       => fbits_sel,
                s_sel           => s_sel,
                bdo_sel         => bdo_sel,
                bdo             => bdo(i),
                from_nlfsr      => nlfsr_dout(i),
                to_nlfsr        => nlfsr_din(i),
                nlfsr_key       => nlfsr_key(i)
            );
    end generate;

    state : entity work.dom_nlfsr
        port map(
            clk    => clk,
            reset  => nlfsr_reset,
            enable => nlfsr_en,
            key    => nlfsr_key,
            load   => nlfsr_load,
            din    => nlfsr_din,
            dout   => nlfsr_dout,
            rnd    => rnd
        );

end architecture behav;
