--------------------------------------------------------------------------------
--! @file       DATA_SIPO.vhd
--! @brief      Width converter for NIST LWC API
--!
--! @author     Michael Tempelmeier
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology     
--!             ECE Department, Technical University of Munich, GERMANY

--! @license    This project is released under the GNU Public License.          
--!             The license and distribution terms for this file may be         
--!             found in the file LICENSE in this distribution or at            
--!             http://www.gnu.org/licenses/gpl-3.0.txt                         
--! @note       This is publicly available encryption source code that falls    
--!             under the License Exception TSU (Technology and software-       
--!             unrestricted)                                                  
--------------------------------------------------------------------------------
--! Description
--! 
--! TODO: Optimize t_state => t_state_16 and t_state_8
--! 
--! 
--! 
--! 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity DATA_SIPO is 
    port(

            clk               : in std_logic;
            rst               : in std_logic;

            end_of_input      : in STD_LOGIC;

--            data_p_a           : out STD_LOGIC_VECTOR(31 downto 0);
--            data_p_b           : out STD_LOGIC_VECTOR(31 downto 0);
--            data_p_c           : out STD_LOGIC_VECTOR(31 downto 0);
            data_p             : out do_array;
            data_valid_p       : out STD_LOGIC;
            data_ready_p       : in  STD_LOGIC;

--            data_s_a           : in  STD_LOGIC_VECTOR(CCW-1 downto 0);
--            data_s_b           : in  STD_LOGIC_VECTOR(CCW-1 downto 0);
--            data_s_c           : in  STD_LOGIC_VECTOR(CCW-1 downto 0);
            data_s             : in do_array;
            data_valid_s       : in  STD_LOGIC;
            data_ready_s       : out STD_LOGIC

      );

end entity DATA_SIPO;

architecture behavioral of DATA_SIPO is

    type t_state is (LD_1, LD_2, LD_3, LD_4); 
    signal nx_state, state : t_state;
    signal mux : integer range 1 to 4;
    signal reg_a, reg_b, reg_c : std_logic_vector (31 downto 8);


begin

assert (CCW = 32) report "This module only supports CCW=32 !" severity failure;

CCW32: if CCW = 32 generate --No PISO needed

--    data_p_a     <= data_s_a;
--    data_p_b     <= data_s_b;
--    data_p_c     <= data_s_c;
    data_p       <= data_s;
    data_valid_p <= data_valid_s;
    data_ready_s <= data_ready_p;

end generate;

end behavioral;
