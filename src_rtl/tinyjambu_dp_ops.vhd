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

use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity tinyjambu_dp_ops is
    generic(
        CONST_ADD : boolean := true
    );
    port(
        clk             : in  std_logic;
        partial         : in  std_logic;
        partial_bytes   : in  std_logic_vector(1 downto 0);
        partial_bdo_out : in  std_logic_vector(CCW / 8 - 1 downto 0);
        decrypt         : in  std_logic;
        bdi             : in  std_logic_vector(CCW - 1 downto 0);
        key             : in  std_logic_vector(CCSW - 1 downto 0);
        key_load        : in  std_logic;
        key_index       : in  std_logic_vector(1 downto 0);
        fbits_sel       : in  std_logic_vector(1 downto 0);
        s_sel           : in  std_logic_vector(1 downto 0);
        bdo_sel         : in  std_logic;
        bdo             : out std_logic_vector(CCW - 1 downto 0);
        from_nlfsr      : in  std_logic_vector(WIDTH - 1 downto 0); --state
        to_nlfsr        : out std_logic_vector(WIDTH - 1 downto 0);
        nlfsr_key       : out std_logic_vector(WIDTH - 1 downto 0)
    );
end entity tinyjambu_dp_ops;

architecture behav of tinyjambu_dp_ops is

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of behav : architecture is "true";

    constant REG_SIZE           : integer := 128;
    signal fbits_mux_out        : std_logic_vector(2 downto 0);
    signal s_fbits_xor_out      : std_logic_vector(2 downto 0);
    signal s_left_concat_out    : std_logic_vector(REG_SIZE - 1 downto 0);
    signal s_right_concat_out   : std_logic_vector(REG_SIZE - 1 downto 0);
    signal s_mux_out            : std_logic_vector(REG_SIZE - 1 downto 0);
    signal partial_full_mux_out : std_logic_vector(95 downto 0);
    signal partial_out          : std_logic_vector(95 downto 0);
    signal bdo_masked           : std_logic_vector (CCW-1 downto 0);
    signal in_xor_out           : std_logic_vector(CCW - 1 downto 0);
    signal m_mux_out            : std_logic_vector(CCW - 1 downto 0);
    signal bdo_out              : std_logic_vector(CCW - 1 downto 0);
    signal tag_out              : std_logic_vector(CCW - 1 downto 0);
    signal bdi_swapped          : std_logic_vector(CCW - 1 downto 0);
    signal bdo_swapped          : std_logic_vector(CCW - 1 downto 0);
    signal tag_swapped          : std_logic_vector(CCSW - 1 downto 0);
    signal key_swapped          : std_logic_vector(CCSW - 1 downto 0);
    signal bdo_mux_out          : std_logic_vector(CCW - 1 downto 0); -- Select between c/m and tag
    signal full_key             : std_logic_vector(REG_SIZE - 1 downto 0);

    --signal for the NLFSR
    signal s         : std_logic_vector(REG_SIZE - 1 downto 0);
    signal key_array : slv_array_t(0 to 3)(31 downto 0);

    --ADDED
begin
    ---======================================
    s         <= from_nlfsr;
    nlfsr_key <= full_key;
    --======================================

    full_key    <= concat_le(key_array);
    bdi_swapped <= bdi(7 downto 0) & bdi(15 downto 8) & bdi(23 downto 16) & bdi(31 downto 24);
    key_swapped <= key(7 downto 0) & key(15 downto 8) & key(23 downto 16) & key(31 downto 24);
    bdo_out     <= s(95 downto 64) xor bdi_swapped;
    bdo_swapped <= bdo_out(7 downto 0) & bdo_out(15 downto 8) & bdo_out(23 downto 16) & bdo_out(31 downto 24);

    with partial_bdo_out select
    bdo_masked      <= x"000000" & bdo_out(7  downto 0) when "1000",
                       x"0000"   & bdo_out(15 downto 0) when "1100",
                       x"00"     & bdo_out(23 downto 0)  when "1110",
                       bdo_out(31 downto 0)  when others;

    bdo <= bdo_mux_out;

    tag_out <= s(95 downto 64);

    tag_swapped <= tag_out(7 downto 0) & tag_out(15 downto 8) & tag_out(23 downto 16) & tag_out(31 downto 24);

    s_fbits_xor_out   <= fbits_mux_out xor s(38 downto 36);
    s_left_concat_out <= s(127 downto 39) & s_fbits_xor_out & s(35 downto 0);

    in_xor_out         <= m_mux_out xor s(127 downto 96);
    s_right_concat_out <= in_xor_out & partial_full_mux_out;

    -- Multiplexer to select which input we want to XOR with the state
    with decrypt select m_mux_out <=
        bdo_masked when '1',
        bdi_swapped when others;

    with bdo_sel select bdo_mux_out <=
        tag_swapped when '1',
        bdo_swapped when others;
    --++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++modification
    -- Multiplexer to select which constant for FrameBits
    gen_const_add : if CONST_ADD generate
        with fbits_sel select fbits_mux_out <=
            b"001" when "00",
            b"011" when "01",
            b"101" when "10",
            b"111" when others;

        partial_out <= s(95 downto 34) & (s(33 downto 32) xor partial_bytes) & s(31 downto 0);
    else generate
        fbits_mux_out <= (others => '0');
        partial_out   <= s(95 downto 34) & s(33 downto 32) & s(31 downto 0); --don't add partial_bytes
    end generate;
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++=end modification
    -- Multiplexer to select the input of the NLFSR
    with s_sel select s_mux_out <=
        s_left_concat_out when b"00",
        s_right_concat_out when others;

    -- Handle partial blocks
    with partial select partial_full_mux_out <=
        partial_out when '1',
        s(95 downto 0) when others;

    -- Load the key into a local array
    key_load_proc : process(clk)
    begin
        if rising_edge(clk) then
            if (key_load = '1') then
                case key_index is
                    when "00" =>
                        key_array(0) <= key_swapped;
                    when "01" =>
                        key_array(1) <= key_swapped;
                    when "10" =>
                        key_array(2) <= key_swapped;
                    when others =>
                        key_array(3) <= key_swapped;
                end case;
            end if;
        end if;
    end process key_load_proc;

    to_nlfsr <= s_mux_out;

end architecture behav;
