--------------------------------------------------------------------------------
--! @file       KEY_PISO.vhd
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
--! This is a simplified version of the data_piso
--! 
--! TODO: Optimize t_state => t_state_16 and t_state_8
--! TODO: Change mux type => std_logic_vector => integer range 0 to 3, range 0 to 1
--! 
--! 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity KEY_PISO is 
    port(

            clk               : in std_logic;
            rst               : in std_logic;

            data_s             : out sdi_array;
            data_valid_s       : out STD_LOGIC;
            data_ready_s       : in  STD_LOGIC;

            data_p             : in sdi_array;
            data_valid_p       : in  STD_LOGIC;
            data_ready_p       : out STD_LOGIC

      );

end entity KEY_PISO;

architecture behavioral of KEY_PISO is


begin

    assert (CCSW=32) report "This module only supports CCSW=32 only!" severity failure;

CCSW32: if CCSW = 32 generate

    data_s <= data_p;
    data_valid_s <= data_valid_p;
    data_ready_p <= data_ready_s;

end generate CCSW32;

end behavioral;
