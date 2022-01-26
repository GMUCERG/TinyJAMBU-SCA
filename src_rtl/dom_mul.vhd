-------------------------------------------------------------------------------
--! @file       dom_mul.vhd (CAESAR API for Lightweight)
--! @brief      Domain-Oriented AND gate for arbitrary order
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

entity dom_mul is
    port ( 
        clk : in std_logic;
        x   : in share_array;
        y   : in share_array;
        z   : in std_logic_vector(SHARE_WIDTH*NUM_SHARES*(NUM_SHARES-1)/2 -1 downto 0);
        q   : out share_array 
    );
        
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of dom_mul : entity is "true";
end dom_mul;

architecture behav of dom_mul is
    attribute keep_hierarchy : string;
	attribute keep_hierarchy of behav : architecture is "true";
	
    signal calc_res        : term_array;
    signal t_reshared      : term_array;
    signal t_reshared_regd : term_array;
    signal integ_res       : term_array;
    signal z_arr           : rnd_array;
    
    attribute keep : string;
	attribute keep of calc_res : signal is "true";  
	attribute keep of t_reshared : signal is "true";  
	attribute keep of t_reshared_regd : signal is "true";  
	attribute keep of integ_res : signal is "true";  
	attribute keep of z_arr : signal is "true";  
    
begin
    --Map z to rnd_array
    map_z:
    for i in 0 to (NUM_SHARES*(NUM_SHARES-1)/2-1) generate
        z_arr(i) <= z((i+1) * SHARE_WIDTH -1 downto  i*SHARE_WIDTH);
    end generate map_z;
    -- Calculation =======================
    gen_terms_0: 
    for i in 0 to NUM_SHARES-1 generate
        gen_terms_1:
        for j in 0 to NUM_SHARES-1 generate
            calc_res(i, j) <= x(i) and y(j);
        end generate gen_terms_1;    
    end generate gen_terms_0;
    
    -- Resharing===========================
    -- add randomenss
    gen_add_rnd_0: --j>i
    for i in 0 to NUM_SHARES-1 generate
        gen_add_rnd_1:
        for j in i+1 to NUM_SHARES-1 generate
            t_reshared(i,j) <= calc_res(i,j) xor z_arr(i+j*(j-1)/2);
        end generate gen_add_rnd_1;
    end generate gen_add_rnd_0;
    
    gen_add_rnd_2: --i>j
    for i in 0 to NUM_SHARES-1 generate
        gen_add_rnd_3:
        for j in 0 to i-1 generate
            t_reshared(i,j) <= calc_res(i,j) xor z_arr(j+i*(i-1)/2);
        end generate gen_add_rnd_3;
    end generate gen_add_rnd_2;
    
    gen_pass_4: --i=j
    for i in 0 to NUM_SHARES-1 generate
        t_reshared(i,i) <= calc_res(i,i);
    end generate gen_pass_4;
    
    -- sync registers -- full pipelining for now
    reg: entity work.dom_mul_reg(behav)
    port map(clk => clk,  
        d=> t_reshared, q => t_reshared_regd);

    -- Integration ========================
    gen_integ_0:
    for i in 0 to NUM_SHARES-1 generate
        integ_res(i, 0) <= t_reshared_regd(i,0);
        gen_integ_1:
        for j in 1 to NUM_SHARES-1 generate
            integ_res(i,j) <= t_reshared_regd(i,j) xor integ_res(i,j-1);
        end generate gen_integ_1;
    end generate gen_integ_0;
    
    gen_q:
    for i in 0 to NUM_SHARES-1 generate
        q(i) <= integ_res(i, NUM_SHARES-1);
    end generate gen_q;

end behav;