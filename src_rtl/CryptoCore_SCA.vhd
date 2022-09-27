--------------------------------------------------------------------------------
--! @file       CryptoCore.vhd
--! @brief      Top level TinyJAMBU implementation adhering to the LWC API.
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

use std.textio.all;

use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity CryptoCore_SCA is

    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        ----!key----------------------------------------------------
        key             : in  std_logic_vector(SDI_SHARES * CCSW - 1 downto 0);
        key_valid       : in  std_logic;
        key_update      : in  std_logic;
        key_ready       : out std_logic;
        ----!Data----------------------------------------------------
        bdi             : in  std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
        bdi_valid       : in  std_logic;
        bdi_ready       : out std_logic;
        bdi_pad_loc     : in  std_logic_vector(CCWdiv8 - 1 downto 0);
        bdi_valid_bytes : in  std_logic_vector(CCWdiv8 - 1 downto 0);
        bdi_size        : in  std_logic_vector(3 - 1 downto 0);
        bdi_eot         : in  std_logic;
        bdi_eoi         : in  std_logic;
        bdi_type        : in  std_logic_vector(4 - 1 downto 0);
        decrypt_in      : in  std_logic;
        hash_in         : in  std_logic;
        --!Post Processor=========================================
        bdo             : out std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
        bdo_valid       : out std_logic;
        bdo_ready       : in  std_logic;
        bdo_type        : out std_logic_vector(4 - 1 downto 0);
        bdo_valid_bytes : out std_logic_vector(CCWdiv8 - 1 downto 0);
        end_of_block    : out std_logic;
        msg_auth_valid  : out std_logic;
        msg_auth_ready  : in  std_logic;
        msg_auth        : out std_logic;
        --! Random Input
        rdi             : in  std_logic_vector(CCRW - 1 downto 0);
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic
    );
end entity;

architecture structural of CryptoCore_SCA is

    attribute keep_hierarchy : string;
    attribute keep_hierarchy of structural : architecture is "true";

    signal bdi_array, bdo_array : T_BDIO_ARRAY;
    signal key_array            : T_KEY_ARRAY;

    signal bdo_sel, nlfsr_load, nlfsr_en, nlfsr_reset, ctrl_decrypt : std_logic;
    signal key_load, partial                                        : std_logic;
    signal fbits_sel, s_sel, key_index, partial_bytes               : std_logic_vector(1 downto 0);

    signal bdo_o : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    
    -- tag verification
    signal cc_tag_last, cc_tag_valid, cc_tag_ready, tv_done            : std_logic;
    signal tv_rdi_valid, tv_rdi_ready, msg_auth_valid_o , tv_bdi_valid : std_logic;
    signal cycle_odd : std_logic;

begin
    bdi_array      <= chop_be(bdi, PDI_SHARES);
    key_array      <= chop_be(key, SDI_SHARES);
    bdo_o          <= concat_be(bdo_array);
    bdo            <= bdo_o;
    msg_auth_valid <= msg_auth_valid_o;
    tv_done        <= msg_auth_valid_o and msg_auth_ready;
    tv_bdi_valid   <= cc_tag_valid and bdi_valid;

    datapath : entity work.tinyjambu_datapath
        port map(
            clk             => clk,
            reset           => rst,
            nlfsr_load      => nlfsr_load,
            partial         => partial,
            partial_bytes   => partial_bytes,
            key_load        => key_load,
            key_index       => key_index,
            nlfsr_en        => nlfsr_en,
            nlfsr_reset     => nlfsr_reset,
            decrypt         => ctrl_decrypt,
            bdi             => bdi_array,
            fbits_sel       => fbits_sel,
            partial_bdo_out => bdi_valid_bytes,
            s_sel           => s_sel,
            key             => key_array,
            bdo_sel         => bdo_sel,
            bdo             => bdo_array,
            rnd             => rdi,
            cycle_odd       => cycle_odd
        );

    control : entity work.tinyjambu_control
        port map(
            clk             => clk,
            reset           => rst,
            decrypt_in      => decrypt_in,
            decrypt_out     => ctrl_decrypt,
            nlfsr_reset     => nlfsr_reset,
            nlfsr_en        => nlfsr_en,
            nlfsr_load      => nlfsr_load,
            key_load        => key_load,
            key_index       => key_index,
            key_ready       => key_ready,
            key_valid       => key_valid,
            key_update      => key_update,
            bdo_valid       => bdo_valid,
            bdo_ready       => bdo_ready,
            bdo_type        => bdo_type,
            bdo             => bdo_array,
            bdi             => bdi_array,
            partial         => partial,
            partial_bytes   => partial_bytes,
            cycle_odd       => cycle_odd,
            bdi_valid       => bdi_valid,
            bdi_ready       => bdi_ready,
            bdi_size        => bdi_size,
            bdi_eoi         => bdi_eoi,
            bdi_eot         => bdi_eot,
            bdi_valid_bytes => bdi_valid_bytes,
            bdo_valid_bytes => bdo_valid_bytes,
            end_of_block    => end_of_block,
            bdi_type        => bdi_type,
            fbits_sel       => fbits_sel,
            bdo_sel         => bdo_sel,
            s_sel           => s_sel,
            rdi_valid       => rdi_valid,
            rdi_ready       => rdi_ready,
            -- Tag verification:
            cc_tag_last     => cc_tag_last,
            cc_tag_valid    => cc_tag_valid,
            cc_tag_ready    => cc_tag_ready,
            tv_rdi_valid    => tv_rdi_valid,
            tv_rdi_ready    => tv_rdi_ready,
            tv_done         => tv_done
        );

    INST_TAG_VERIF : entity work.tag_verif
        port map(
            clk            => clk,
            rst            => rst,
            -- Tag received
            bdi            => bdi,
            bdi_type       => bdi_type,
            bdi_last       => bdi_eot,
            bdi_valid      => tv_bdi_valid,
            bdi_ready      => open,     -- don't need it
            -- CryptoCore
            cc_tag         => bdo_o,
            cc_tag_last    => cc_tag_last,
            cc_tag_valid   => cc_tag_valid,
            cc_tag_ready   => cc_tag_ready,
            --
            --
            rdi            => rdi(PDI_SHARES * CCW - 1 downto 0), -- TODO
            rdi_valid      => tv_rdi_valid,
            rdi_ready      => tv_rdi_ready,
            --
            msg_auth_valid => msg_auth_valid_o,
            msg_auth_ready => msg_auth_ready,
            msg_auth       => msg_auth
        );

end architecture;
