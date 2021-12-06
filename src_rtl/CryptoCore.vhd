--------------------------------------------------------------------------------
--! @file       CryptoCore.vhd
--! @brief      Top level TinyJAMBU implementation adhering to the LWC API.
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

library work;
use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity CryptoCore is
    generic (
        WIDTH               : integer := 128
    );
    
    port (
        clk                 : in   std_logic;
        rst                 : in   std_logic;
        --PreProcessor===============================================
        ----!key----------------------------------------------------
--        key_a                 : in   std_logic_vector (CCSW     -1 downto 0);
--        key_b                 : in   std_logic_vector (CCSW     -1 downto 0);
--        key_c                 : in   std_logic_vector (CCSW     -1 downto 0);
        key_arr             : in sdi_array;
        key_valid           : in   std_logic;
        key_update          : in   std_logic;
        key_ready           : out  std_logic;
        ----!Data----------------------------------------------------
--        bdi_a                 : in   std_logic_vector (CCW     -1 downto 0);
--        bdi_b                 : in   std_logic_vector (CCW     -1 downto 0);
--        bdi_c                 : in   std_logic_vector (CCW     -1 downto 0);
        bdi_arr             : in pdi_array;
        bdi_valid           : in   std_logic;
        bdi_ready           : out  std_logic;
        bdi_pad_loc         : in   std_logic_vector (CCWdiv8 -1 downto 0);
        bdi_valid_bytes     : in   std_logic_vector (CCWdiv8 -1 downto 0);
        bdi_size            : in   std_logic_vector (3       -1 downto 0);
        bdi_eot             : in   std_logic;
        bdi_eoi             : in   std_logic;
        bdi_type            : in   std_logic_vector (4       -1 downto 0);
        decrypt_in          : in   std_logic;
        hash_in             : in   std_logic;
        --!Post Processor=========================================
--        bdo_a                 : out  std_logic_vector (CCW      -1 downto 0);
--        bdo_b                 : out  std_logic_vector (CCW      -1 downto 0);
--        bdo_c                 : out  std_logic_vector (CCW      -1 downto 0);
        bdo_arr             : out do_array;
        bdo_valid           : out  std_logic;
        bdo_ready           : in   std_logic;
        bdo_type            : out  std_logic_vector (4       -1 downto 0);
        bdo_valid_bytes     : out  std_logic_vector (CCWdiv8 -1 downto 0);
        end_of_block        : out  std_logic;
        msg_auth_valid      : out  std_logic;
        msg_auth_ready      : in   std_logic;
        msg_auth            : out  std_logic;
        --rdi data to seed PRNG
        rdi_valid           : in   std_logic;
        rdi_ready           : out  std_logic;
        rdi_data            : in   std_logic_vector(RW -1 downto 0)
        

    );
end entity CryptoCore;

architecture structural of CryptoCore is


attribute keep_hierarchy : string;
attribute keep_hierarchy of structural : architecture is "true";
    
attribute keep : string;
attribute keep of bdi_arr : signal is "true";
attribute keep of key_arr : signal is "true";
attribute keep of bdo_arr : signal is "true";
    
    
signal bdo_sel, nlfsr_load, nlfsr_en, nlfsr_reset, ctrl_decrypt : std_logic;
signal key_load, partial : std_logic;
signal fbits_sel, s_sel, key_index, partial_bytes : std_logic_vector (1 downto 0);
signal bdo_sig          : std_logic_vector (31 downto 0);
--arrays

signal bdi, key, bdo : io_share_array;

--! PRNG signals
signal reseed, prng_rdi_valid : std_logic;
signal prng_rdi_data : std_logic_vector(NUM_TRIVIUM_UNITS * 64 - 1 downto 0);
signal seed : std_logic_vector(SEED_SIZE - 1 downto 0); 
signal en_seed_sipo : std_logic;
--
signal rnd : std_logic_vector(SHARE_WIDTH*SHARE_NUM*(SHARE_NUM-1)/2+(SHARE_WIDTH*SHARE_NUM)-1
                              downto 0);

begin


map_input: for i in 0 to SHARE_NUM-1 generate
    bdi(i) <= bdi_arr(i);
    key(i) <= key_arr(i);
    bdo_arr(i) <= bdo(i);
end generate;

datapath : entity work.tinyjambu_datapath
            port map (
                clk             => clk,
                reset           => rst,
                nlfsr_load      => nlfsr_load,
                partial         => partial,
                partial_bytes   => partial_bytes,
                key_load        => key_load,
                key_index       => key_index,
                nlfsr_en        => nlfsr_en,
                nlfsr_reset     => nlfsr_reset,
                decrypt         => ctrl_decrypt,
                bdi             => bdi,
                fbits_sel       => fbits_sel,
                partial_bdo_out => bdi_valid_bytes,
                s_sel           => s_sel,
                key             => key,
                bdo_sel         => bdo_sel,
                bdo             => bdo,
                rnd             => rnd
            );

control : entity work.tinyjambu_control
            port map (
                clk             => clk,
                reset           => rst,
                decrypt_in      => decrypt_in,
                decrypt_out     => ctrl_decrypt,
                nlfsr_reset     => nlfsr_reset,
                nlfsr_en        => nlfsr_en,
                nlfsr_load      => nlfsr_load,
                key_load        => key_load,
                key_index       => key_index,
                key_ready       => key_ready,
                key_valid       => key_valid,
                key_update      => key_update,
                bdo_valid       => bdo_valid,
                bdo_ready       => bdo_ready,
                bdo_type        => bdo_type,
                partial         => partial,
                partial_bytes   => partial_bytes,
                bdi_valid       => bdi_valid,
                bdi_ready       => bdi_ready,
                bdi_pad_loc     => bdi_pad_loc,
                bdi_size        => bdi_size,
                bdi_eoi         => bdi_eoi,
                bdi_eot         => bdi_eot,
                bdi_valid_bytes => bdi_valid_bytes,
                bdo_valid_bytes => bdo_valid_bytes,
                end_of_block    => end_of_block,
                bdi_type        => bdi_type,
                fbits_sel       => fbits_sel,
                bdo_sel         => bdo_sel,
                hash_in         => hash_in,
                s_sel           => s_sel,
                msg_auth_valid  => msg_auth_valid,
                msg_auth_ready  => msg_auth_ready,
                msg_auth        => msg_auth,
                --! rdi data form outside world to be used as PRNG seed
                rdi_valid => rdi_valid,
                rdi_ready => rdi_ready,
                --! PRNG
                prng_rdi_valid => prng_rdi_valid,
                prng_reseed => reseed,
                en_seed_sipo => en_seed_sipo
            );
            
            --Trivium PRNG
    trivium_inst : entity work.prng_trivium_enhanced(structural)
    generic map (N => NUM_TRIVIUM_UNITS)
    port map(
		clk         => clk,
        rst         => rst,
		en_prng     => '1',
        seed        => seed,
		reseed      => reseed,
		reseed_ack  => open,
		rdi_data    => prng_rdi_data,
		rdi_ready   => '1',
		rdi_valid   => prng_rdi_valid
	);
	
	--! seed SIPO
	seed_sipo : process(clk)
	begin
	   if rising_edge(clk) then
	       if en_seed_sipo = '1' then
	           seed <= seed(SEED_SIZE - RW - 1 downto 0) & rdi_data;
	       end if;
	   end if;
	end process;
	
	rnd <= prng_rdi_data(SHARE_WIDTH*SHARE_NUM*(SHARE_NUM-1)/2+(SHARE_WIDTH*SHARE_NUM)-1 downto 0);
	
end architecture structural;
