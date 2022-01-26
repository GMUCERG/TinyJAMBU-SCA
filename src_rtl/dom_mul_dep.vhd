-------------------------------------------------------------------------------
--! @file       dom_mul.vhd (CAESAR API for Lightweight)
--! @brief      Domain-Oriented AND-dep gate for arbitrary order
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
use ieee.numeric_std.ALL;

entity dom_mul_dep is
    port ( 
        clk : in std_logic;
        x   : in share_array;
        y   : in share_array;
        rnd : in std_logic_vector(SHARE_WIDTH*NUM_SHARES*(NUM_SHARES-1)/2 + (SHARE_WIDTH*NUM_SHARES) -1
              downto 0);
        q   : out share_array 
    );
        
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of dom_mul_dep : entity is "true";
end dom_mul_dep;

architecture behav of dom_mul_dep is
    attribute keep_hierarchy : string;
	attribute keep_hierarchy of behav : architecture is "true";
    
    signal z : share_array;
    signal z_vect : std_logic_vector(NUM_SHARES*SHARE_WIDTH-1 downto 0);
    
    signal z_indep : std_logic_vector(SHARE_WIDTH*NUM_SHARES*(NUM_SHARES-1)/2-1 downto 0);
    
    signal y_xor_z : share_array;
    signal y_xor_z_regd : share_array;
    
    signal sum : share_array;
    signal b : std_logic_vector(SHARE_WIDTH-1 downto 0);
    
    signal x_mul_b : share_array;
    signal dom_mul_q : share_array;
    --
    attribute keep : string;
    attribute keep of z : signal is "true";  
	attribute keep of z_vect : signal is "true";  
	attribute keep of z_indep : signal is "true"; 
	attribute keep of y_xor_z : signal is "true"; 
	attribute keep of y_xor_z_regd : signal is "true"; 
	attribute keep of sum : signal is "true"; 
	attribute keep of b : signal is "true"; 
	attribute keep of x_mul_b : signal is "true"; 
	attribute keep of dom_mul_q : signal is "true"; 
    
begin
    --rand mapping
    z_vect <= rnd(NUM_SHARES*SHARE_WIDTH-1 downto 0);
    z_indep <= rnd(SHARE_WIDTH*NUM_SHARES*(NUM_SHARES-1)/2+(SHARE_WIDTH*NUM_SHARES)-1
                   downto NUM_SHARES*SHARE_WIDTH);
    gen_map_z:
    for i in 0 to NUM_SHARES-1 generate
        z(i) <= z_vect((i+1) * SHARE_WIDTH - 1 downto i*SHARE_WIDTH);
    end generate;

    --z + y
    gen_xors:
    for i in 0 to NUM_SHARES-1 generate
        y_xor_z(i) <= y(i) xor z(i); 
    end generate;
    
    --sync registers
    sync_regs:
    for i in 0 to NUM_SHARES-1 generate
        reg: entity work.reg_n(behav)
            generic map(N => SHARE_WIDTH)
            port map(clk=> clk, d=>y_xor_z(i), q=>y_xor_z_regd(i));
    end generate;
    
    -- sum up all y+z shares
    sum(0) <= y_xor_z_regd(0);
    gen_sum:
    for i in 0 to NUM_SHARES-2 generate
        sum(i+1) <= sum(i) xor y_xor_z_regd(i+1);
    end generate;
    
    b <= sum(NUM_SHARES-1);
    
    -- regular multipliers
    gen_muls:
    for i in 0 to NUM_SHARES-1 generate
        x_mul_b(i) <= x(i) and b;
    end generate;
    
    --- DOM multiplier
    dom_mul : entity work.dom_mul(behav)
    port map(clk=>clk, x =>x, y=>z, z=>z_indep, q=> dom_mul_q);
    
    gen_out:
    for i in 0 to NUM_SHARES-1 generate
        q(i) <= dom_mul_q(i) xor x_mul_b(i);
    end generate;
    
end behav;