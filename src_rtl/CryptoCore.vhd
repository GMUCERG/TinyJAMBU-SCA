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
        key             : in  STD_LOGIC_VECTOR(SDI_SHARES * CCSW - 1 downto 0);
        key_valid       : in  std_logic;
        key_update      : in  std_logic;
        key_ready       : out std_logic;
        ----!Data----------------------------------------------------
        bdi             : in  STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
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
        bdo             : out STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
        bdo_valid       : out std_logic;
        bdo_ready       : in  std_logic;
        bdo_type        : out std_logic_vector(4 - 1 downto 0);
        bdo_valid_bytes : out std_logic_vector(CCWdiv8 - 1 downto 0);
        end_of_block    : out std_logic;
        msg_auth_valid  : out std_logic;
        msg_auth_ready  : in  std_logic;
        msg_auth        : out std_logic;
        --! Random Input
        rdi_data        : in  std_logic_vector(RW - 1 downto 0);
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic
    );
end entity;

architecture structural of CryptoCore_SCA is

    attribute keep_hierarchy : string;
    attribute keep_hierarchy of structural : architecture is "true";

    signal bdi_array, bdo_array : bdio_array;
    signal key_array            : sdi_array;
    

    signal bdo_sel, nlfsr_load, nlfsr_en, nlfsr_reset, ctrl_decrypt : std_logic;
    signal key_load, partial                                        : std_logic;
    signal fbits_sel, s_sel, key_index, partial_bytes               : std_logic_vector(1 downto 0);

begin
    bdi_array <= chop_be(bdi, PDI_SHARES);
    key_array <= chop_be(key, SDI_SHARES);
    bdo      <= concat_be(bdo_array);

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
            rnd             => rdi_data
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
            partial         => partial,
            partial_bytes   => partial_bytes,
            bdi_valid       => bdi_valid,
            bdi_ready       => bdi_ready,
            bdi_pad_loc     => bdi_pad_loc,
            bdi_size        => bdi_size,
            bdi_eoi         => bdi_eoi,
            bdi_eot         => bdi_eot,
            bdi_valid_bytes => bdi_valid_bytes,
            bdo_valid_bytes => bdo_valid_bytes,
            end_of_block    => end_of_block,
            bdi_type        => bdi_type,
            fbits_sel       => fbits_sel,
            bdo_sel         => bdo_sel,
            hash_in         => hash_in,
            s_sel           => s_sel,
            msg_auth_valid  => msg_auth_valid,
            msg_auth_ready  => msg_auth_ready,
            msg_auth        => msg_auth,
            rdi_valid       => rdi_valid,
            rdi_ready       => rdi_ready
        );

end architecture;
