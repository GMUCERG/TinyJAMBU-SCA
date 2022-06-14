-------------------------------------------------------------------------------
--! @file       dom_mul.vhd (CAESAR API for Lightweight)
--! @brief      Register for Domain-Oriented AND gate for arbitrary order
--! @author     Abuabkr Abdulgadir
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
use work.design_pkg.all;

entity dom_mul_reg is
    port(
        clk  : in std_logic;
        en   : in std_logic;
        d    : in term_array;
        q    : out term_array
    );

        
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of dom_mul_reg : entity is "true";
end dom_mul_reg;

architecture behav of dom_mul_reg is

    attribute keep_hierarchy : string;
    attribute keep_hierarchy of behav: architecture is "true";

begin
    reg: process(clk)
    begin
        if rising_edge(clk) then
            if en = '1' then
                q <=d;
            end if;
        end if;
    end process;

end behav;