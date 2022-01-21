--------------------------------------------------------------------------------
--! @file       design_pkg.vhd
--! @brief      Package for CryptoCore
--! @author     Sammy Lin
--!@modified by Abubakr Abdulgadir
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

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

use work.NIST_LWAPI_pkg.all;

package design_pkg is

    --!
    constant CONCURRENT  : positive := 32; --! Valid settings:  2, 4, 8, 16, 32
    constant SHARE_WIDTH : positive := CONCURRENT;
    constant WIDTH       : positive := 128; --state size
    constant SHARE_NUM   : positive := PDI_SHARES;

    --! design parameters needed by the PreProcessor, PostProcessor, and LWC; assigned in the package body below!
    --! Internal key width. If SW = 8 or 16, CCSW = SW. If SW=32, CCSW = 8, 16, or 32.
    --! Internal data width. If W = 8 or 16, CCW = W. If W=32, CCW = 8, 16, or 32.
    --! derived from the parameters above, assigned in the package body below.

    constant CCW     : integer := 32;
    constant CCSW    : integer := CCW;
    constant CCRW    : integer := SHARE_WIDTH * SHARE_NUM * (SHARE_NUM + 1) / 2;
    constant CCWdiv8 : integer := CCW / 8;

    constant TAG_SIZE        : integer; --! Tag size
    constant HASH_VALUE_SIZE : integer; --! Hash value size

    type share_array is array (0 to SHARE_NUM - 1) of std_logic_vector(SHARE_WIDTH - 1 downto 0);
    type rnd_array is array (0 to SHARE_NUM * (SHARE_NUM - 1) / 2 - 1) of std_logic_vector(SHARE_WIDTH - 1 downto 0);
    type term_array is array (0 to SHARE_NUM - 1, 0 to SHARE_NUM - 1) of std_logic_vector(SHARE_WIDTH - 1 downto 0);
    type data_array is array (0 to SHARE_NUM - 1) of std_logic_vector(WIDTH - 1 downto 0);

    type bit_array_t is array (natural range <>) of std_logic;
    type slv_array_t is array (natural range <>) of std_logic_vector;

    subtype pdio_array is slv_array_t(0 to PDI_SHARES - 1)(W - 1 downto 0);
    subtype sdi_array is slv_array_t(0 to SDI_SHARES - 1)(SW - 1 downto 0);
    subtype bdio_array is slv_array_t(0 to PDI_SHARES - 1)(CCW - 1 downto 0);
    subtype key_array is slv_array_t(0 to SDI_SHARES - 1)(CCSW - 1 downto 0);

    --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    --! requires length of a to be a multiple of n
    --! Big Endian: Most significant (MSB) portion of the input `a` is assigned to index 0 of the output
    function chop_be(a : std_logic_vector; n : positive) return slv_array_t;

    --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    --! requires length of a to be a multiple of n
    --! Little Endian: least significant (LSB) portion of the input `a` is assigned to index 0 of the output
    function chop_le(a : std_logic_vector; n : positive) return slv_array_t;

    --! concatenate slv_array_t elements into a single std_logic_vector
    -- Big Endian
    function concat_be(a : slv_array_t) return std_logic_vector;

    -- Little Endian
    function concat_le(a : slv_array_t) return std_logic_vector;
    --! first TO_01 and then TO_INTEGER
    function TO_INT01(S : UNSIGNED) return INTEGER;
    function TO_INT01(S : STD_LOGIC_VECTOR) return INTEGER;

    function xor_slv_array(a : slv_array_t) return std_logic_vector;
   
end design_pkg;

package body design_pkg is

    --! assign values to all constants and aliases here
    constant TAG_SIZE        : integer := 64;
    constant HASH_VALUE_SIZE : integer := 256; -- WE DO NOT SUPPORT HASHING

    --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    --! requires length of a to be a multiple of n
    --! Little Endian: least significant (LSB) portion of the input `a` is assigned to index 0 of the output
    function chop_le(a : std_logic_vector; n : positive) return slv_array_t is
        constant el_w : positive := a'length / n;
        variable ret  : slv_array_t(0 to n - 1)(el_w - 1 downto 0);
    begin
        for i in ret'range loop
            ret(i) := a((i + 1) * el_w - 1 downto i * el_w);
        end loop;
        return ret;
    end function;

    --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    --! requires length of a to be a multiple of n
    --! Big Endian: Most significant (MSB) portion of the input `a` is assigned to index 0 of the output
    function chop_be(a : std_logic_vector; n : positive) return slv_array_t is
        constant el_w : positive := a'length / n;
        variable ret  : slv_array_t(0 to n - 1)(el_w - 1 downto 0);
    begin
        for i in ret'range loop
            ret(n - 1 - i) := a((i + 1) * el_w - 1 downto i * el_w);
        end loop;
        return ret;
    end function;

    --! concatenates slv_array_t elements into a single std_logic_vector
    -- Big Endian
    function concat_be(a : slv_array_t) return std_logic_vector is
        constant n    : positive := a'length;
        constant el : std_logic_vector := a(0);
        constant el_w : positive := el'length;
        variable ret  : std_logic_vector(el_w * n - 1 downto 0);
    begin
        for i in a'range loop
            ret((i + 1) * el_w - 1 downto i * el_w) := a(n - 1 - i);
        end loop;
        return ret;
    end function;

    function concat_le(a : slv_array_t) return std_logic_vector is
        constant n    : positive := a'length;
        constant el : std_logic_vector := a(0);
        constant el_w : positive := el'length;
        variable ret  : std_logic_vector(el_w * n - 1 downto 0);
    begin
        for i in a'range loop
            ret((i + 1) * el_w - 1 downto i * el_w) := a(i);
        end loop;
        return ret;
    end function;

    function xor_slv_array(a : slv_array_t) return std_logic_vector is
        constant el   : std_logic_vector := a(a'left);
        constant el_w : POSITIVE         := el'length;
        variable ret  : std_logic_vector(el_w - 1 downto 0);
    begin
        ret := a(0);
        for i in 1 to a'length - 1 loop
            ret := ret xor a(i);
        end loop;
        return ret;
    end function;

    function TO_INT01(S : UNSIGNED) return INTEGER is
    begin
        return to_integer(to_01(S));

    end function TO_INT01;

    function TO_INT01(S : STD_LOGIC_VECTOR) return INTEGER is
    begin
        return TO_INT01(unsigned(S));

    end function TO_INT01;

end package body design_pkg;
