----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/27/2020
-- Design Name: 
-- Module Name: pdi_sipo - Behavioral
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
entity sdi_sipo is
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
             
        sdi_data        : in  std_logic_vector(W-1 downto 0); -- from TB FIFO to SIPO
        sdi_valid       : in  std_logic; -- from TB FIFO to SIPO
        sdi_ready       : out std_logic; -- from SIPO to TB FIFO 
        
        -- pdi_data_a      : out  std_logic_vector(W-1 downto 0); -- from SIPO to PreProcessor
        -- pdi_data_b      : out  std_logic_vector(W-1 downto 0); -- from SIPO to PreProcessor
        -- pdi_data_c      : out  std_logic_vector(W-1 downto 0); -- from SIPO to PreProcessor
        sdi_data_arr        : out sdi_array;
        sdi_sipo_valid  : out  std_logic; -- from SIPO to PreProcessor
        sdi_sipo_ready  : in   std_logic -- from PreProcessor to SIPO
    );
end sdi_sipo;

-- Architecture
----------------------------------------------------------------------------------
architecture Behavioral of sdi_sipo is

    -- Signals -------------------------------------------------------------------
    type state_type is (s_load, s_valid); 
    signal state, nx_state  : state_type;
    -- signal reg_a_en, reg_b_en, reg_c_en : std_logic;
    signal cnt, nx_cnt : unsigned(4-1 downto 0);
    signal mem : sdi_array;
    signal we : std_logic;
----------------------------------------------------------------------------------
begin
      
    process (clk)
    begin
        if (rising_edge(clk)) then
            if (rst = '1')  then
                state <= s_load;
                cnt <= (others=>'0');
            else
                state <= nx_state;
                cnt <= nx_cnt;
            end if;
        end if;
    end process;
    
    process(all)
    begin
        
        sdi_sipo_valid  <= '0';
        sdi_ready       <= '0';
        we              <= '0';
        nx_cnt          <= cnt;
        
        case state is
            when s_load =>
                sdi_ready       <= '1';                             
                if (sdi_valid = '1') then 
                    we    <= '1';  
--                    nx_cnt <= cnt + 1;
                    if cnt = API_SHARE_NUM-1 then                             
                        nx_state    <= s_valid;
                    else
                        nx_state    <= s_load;
                        nx_cnt <= cnt + 1;
                    end if;
                else
                    nx_state    <= s_load;
                end if;

            when s_valid =>
                sdi_sipo_valid  <= '1';
                if (sdi_sipo_ready = '1') then
                    nx_state    <= s_load;
                    nx_cnt <= (others=>'0');
                else 
                    nx_state    <= s_valid;
                end if;
                
            when others => null;

        end case;        
    end process;
    
    --write logic
    mem_proc: process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                mem(to_integer(cnt)) <= sdi_data;
            end if;
        end if;
    end process;
    
    --read logic
    sdi_data_arr <= mem;
end Behavioral;
