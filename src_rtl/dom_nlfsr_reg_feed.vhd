--------------------------------------------------------------------------------
--! @file       dom_nlfsr_reg_feed.vhd
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
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

entity dom_nlfsr_reg_feed is
    generic(
        CONST_ADD : boolean
    );
    port(
        clk     : in  std_logic;
        reset   : in  std_logic;
        enable  : in  std_logic;
        key     : in  std_logic_vector(WIDTH - 1 downto 0);
        load    : in  std_logic;
        din     : in  std_logic_vector(WIDTH - 1 downto 0);
        dout    : out std_logic_vector(WIDTH - 1 downto 0);
        and_x   : out std_logic_vector(SHARE_WIDTH - 1 downto 0);
        and_y   : out std_logic_vector(SHARE_WIDTH - 1 downto 0);
        and_out : in  std_logic_vector(SHARE_WIDTH - 1 downto 0)
    );

    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of dom_nlfsr_reg_feed : entity is "true";
end entity dom_nlfsr_reg_feed;

architecture behav of dom_nlfsr_reg_feed is
    attribute keep_hierarchy : string;
    attribute keep_hierarchy of behav : architecture is "true";

    signal reg      : std_logic_vector(WIDTH - 1 downto 0);
    signal feedback : std_logic_vector(SHARE_WIDTH - 1 downto 0);
    signal counter  : unsigned(6 downto 0);
    --
    signal cnt      : unsigned(0 downto 0);
    signal en_state : std_logic;

    attribute keep : string;
    attribute keep of reg : signal is "true";
    attribute keep of feedback : signal is "true";

begin

    and_x <= reg((70 + CONCURRENT) - 1 downto 70);
    and_y <= reg((85 + CONCURRENT) - 1 downto 85);

    ----feedback calculation===============================================================
    feedback_gen0 : if CONST_ADD generate
        feedback <= reg((91 + CONCURRENT) - 1 downto 91) xor (not and_out) xor reg((47 + CONCURRENT) - 1 downto 47) xor reg((0 + CONCURRENT) - 1 downto 0) xor key((to_int01(counter) + CONCURRENT) - 1 downto to_int01(counter));
    else generate
        feedback <= reg((91 + CONCURRENT) - 1 downto 91) xor (and_out) xor reg((47 + CONCURRENT) - 1 downto 47) xor reg((0 + CONCURRENT) - 1 downto 0) xor key((to_int01(counter) + CONCURRENT) - 1 downto to_int01(counter));
    end generate;

    --==========================================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                reg     <= (others => '0');
                counter <= (others => '0');
            elsif (load = '1') then
                reg     <= din;
                counter <= (others => '0');
            elsif (en_state = '1') then
                reg     <= feedback & reg((WIDTH - 1) downto CONCURRENT);
                counter <= counter + CONCURRENT;
            end if;
        end if;
    end process;

    dout <= reg;
    --counter=================================================================================
    --enable register only when and output is valid (2 cycle delay)
    en_cntr : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt <= to_unsigned(0, cnt'length);
            else
                if enable = '1' then
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;

    en_state <= '1' when cnt = 1 else '0';

end architecture behav;
