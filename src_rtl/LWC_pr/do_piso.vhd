----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/28/2020
-- Design Name: 
-- Module Name: do_piso - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

-- Entity
----------------------------------------------------------------------------------
entity do_piso is
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
             
        do_data         : out std_logic_vector(W-1 downto 0); -- from PISO to DO_FIFO
        do_valid        : out std_logic; -- from PISO to DO_FIFO
        do_ready        : in  std_logic; -- from FIFO to DO_PISO
        
--        do_data_a       : in  std_logic_vector(W-1 downto 0); -- from PostProcessor to PISO
--        do_data_b       : in  std_logic_vector(W-1 downto 0); -- from PostProcessor to PISO
--        do_data_c       : in  std_logic_vector(W-1 downto 0); -- from PostProcessor to PISO
        do_data_arr     : in do_array;
        do_piso_valid   : in  std_logic; -- from PostProcessor to PISO
        do_piso_ready   : out std_logic -- from PISO to PostProcessor 
    );
end do_piso;

-- Architecture
----------------------------------------------------------------------------------
architecture Behavioral of do_piso is

    -- Signals -------------------------------------------------------------------
    type state_type is (s_unload, s_ready); 
    signal state, nx_state  : state_type;

--    signal reg_a_en, reg_b_en, reg_c_en : std_logic;
--    signal reg_a_Q, reg_b_Q, reg_c_Q    : std_logic_vector(W-1 downto 0);
    signal  we : std_logic;
    signal cnt, nx_cnt : unsigned(4-1 downto 0);
    signal mem : do_array;

----------------------------------------------------------------------------------
begin
      
    process (clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1')  then
                state <= s_ready;
                cnt <= (others=>'0');
            else
                state <= nx_state;
                cnt   <= nx_cnt;
            end if;
        end if;
    end process;
    
    process (all)
    begin
        do_piso_ready   <= '0';
        we              <= '0';
        do_valid        <= '0';
        nx_cnt          <= cnt;
        
        case state is
            when s_ready =>  
                do_piso_ready   <= '1';                     
                if (do_piso_valid = '1') then                        
                    we <= '1';                                
                    nx_state    <= s_unload;
                else
                    nx_state    <= s_ready;
                end if;
             
             when s_unload =>
                do_valid        <= '1';
                if (do_ready = '1') then
--                    nx_cnt          <= cnt +1;
                    if cnt = API_SHARE_NUM-1 then                             
                        nx_state    <= s_ready;
                        nx_cnt <= (others=>'0');
                    else
                        nx_state    <= s_unload;
                        nx_cnt          <= cnt +1;
                    end if;
                else
                    nx_state    <= s_unload;
                end if;
                
            when others => null;

        end case;        
    end process;
    
    --read logic
    do_data <= mem(to_integer(cnt));
    --write logic
    load: process(clk)
    begin
        if rising_edge(clk) then
            if we='1' then
                mem <= do_data_arr;
            end if;
        end if;
    end process;
end Behavioral;
