--===============================================================================================--
--! @file       NIST_LWAPI_pkg.vhd 
--! @brief      NIST lightweight API package
--! @author     Panasayya Yalla & Ekawat (ice) Homsirikamol
--! @copyright  Copyright (c) 2016 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
---------------------------------------------------------------------------------------------------
--! Description
--!
--!             User configuration of API-level parameters
--!               
--!
--!
--!
--!
--===============================================================================================--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package NIST_LWAPI_pkg is
    --===========================================================================================--
    --=                                   User Configuration                                    =--
    --===========================================================================================--

    --! External bus: supported values are 8, 16 and 32 bits
    constant W          : positive := 32;
    constant SW         : positive := W;
    --! Implementation of an "offline" algorithm
    constant G_OFFLINE  : boolean  := False;
    --! only used in protected implementations
    constant PDI_SHARES : positive := 2;
    constant SDI_SHARES : positive := PDI_SHARES;
    constant RW         : natural  := W * PDI_SHARES * (PDI_SHARES + 1) / 2;

    --! Asynchronous and active-low reset.
    --! Can be set to `True` when targeting ASICs given that your CryptoCore supports it.
    constant ASYNC_RSTN : boolean := False;

end NIST_LWAPI_pkg;
