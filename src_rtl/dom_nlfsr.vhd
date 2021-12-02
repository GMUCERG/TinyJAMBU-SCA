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

entity dom_nlfsr is
    port (
        clk         : in std_logic;
        reset       : in std_logic;
        enable      : in std_logic;
        key         : in data_array;
        load        : in std_logic;
        din         : in data_array;
        dout        : out data_array;
        rnd         : in std_logic_vector(SHARE_WIDTH*SHARE_NUM*(SHARE_NUM-1)/2+(SHARE_WIDTH*SHARE_NUM)-1 
                                          downto 0)
    );
end entity dom_nlfsr;

architecture behav of dom_nlfsr is
    attribute keep_hierarchy : string;
	attribute keep_hierarchy of behav : architecture is "true";    
    --============================================
    signal and_x : share_array;
    signal and_y : share_array;
    signal and_out : share_array;
    --============================================
    attribute keep : string;   
	attribute keep of and_x : signal is "true";    
	attribute keep of and_y : signal is "true";    
	attribute keep of and_out : signal is "true";    
	attribute keep of key : signal is "true";    
	attribute keep of din : signal is "true";    
	attribute keep of dout : signal is "true";    
	   
begin
 
    dom_and : entity work.dom_mul_dep(behav)
    port map(
        clk => clk,
        x => and_x,
        y => and_y,
        rnd => rnd,
        q => and_out
    );
    
    reg_feed0 : entity work.dom_nlfsr_reg_feed 
    generic map(
        CONST_ADD => true
    )
    port map (
        clk     => clk,
        reset   => reset,
        enable  => enable,
        key     => key(0),
        load    => load,
        din   => din(0),
        dout  => dout(0),
        and_x => and_x(0),
        and_y => and_y(0),
        and_out => and_out(0)
    );
    
    reg_feed_gen : 
    for i in 1 to SHARE_NUM-1 generate
    reg_feed_i: entity work.dom_nlfsr_reg_feed 
    generic map(
        CONST_ADD => false
    )
    port map (
        clk     => clk,
        reset   => reset,
        enable  => enable,
        key     => key(i),
        load    => load,
        din   => din(i),
        dout  => dout(i),
        and_x => and_x(i),
        and_y => and_y(i),
        and_out => and_out(i)
    );
    end generate;

end architecture behav;
