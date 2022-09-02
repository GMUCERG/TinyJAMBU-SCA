
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.NIST_LWAPI_pkg.all;

entity LWC_SCA_wrapper is
  generic(
    XRW : natural := 0
  );
  port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    --! Public data input
    pdi_data  : in  std_logic_vector(PDI_SHARES * W - 1 downto 0);
    pdi_valid : in  std_logic;
    pdi_ready : out std_logic;
    --! Secret data input
    sdi_data  : in  std_logic_vector(SDI_SHARES * SW - 1 downto 0);
    sdi_valid : in  std_logic;
    sdi_ready : out std_logic;
    --! Data out ports
    do_data   : out std_logic_vector(PDI_SHARES * W - 1 downto 0);
    do_last   : out std_logic;
    do_valid  : out std_logic;
    do_ready  : in  std_logic;
    --! Random Input
    rdi_data  : in  std_logic_vector(XRW - 1 downto 0); -- external RW
    rdi_valid : in  std_logic;
    rdi_ready : out std_logic
  );
end entity LWC_SCA_wrapper;

architecture RTL of LWC_SCA_wrapper is

  signal lwc_rdi_data                 : std_logic_vector(RW - 1 downto 0);
  signal lwc_rdi_valid, lwc_rdi_ready : std_logic;
  signal lwc_pdi_valid, lwc_pdi_ready : std_logic;
  signal lwc_sdi_valid, lwc_sdi_ready : std_logic;
begin

  process(all) is
  begin
    lwc_pdi_valid <= '0';
    lwc_sdi_valid <= '0';
    pdi_ready     <= '0';
    sdi_ready     <= '0';
    if lwc_rdi_valid = '1' then
      lwc_pdi_valid <= pdi_valid;
      lwc_sdi_valid <= sdi_valid;
      pdi_ready     <= lwc_pdi_ready;
      sdi_ready     <= lwc_sdi_ready;
    end if;
  end process;

  INST_LFSR : entity work.LFSR
    generic map(
      G_IN_BITS  => XRW,
      G_OUT_BITS => RW,
      G_LFSR_LEN => 0,
      G_INIT_VAL => x"4b7fdaeb869cf6592ab97a59"
    )
    port map(
      clk        => clk,
      rst        => rst,
      --
      reseed     => '0',
      --
      rin_data   => rdi_data,
      rin_valid  => rdi_valid,
      rin_ready  => rdi_ready,
      --
      rout_data  => lwc_rdi_data,
      rout_valid => lwc_rdi_valid,
      rout_ready => lwc_rdi_ready
    );

  uut : entity work.LWC_SCA
    generic map(
      G_DO_FIFO_DEPTH => 1
    )
    port map(
      clk       => clk,
      rst       => rst,
      --
      pdi_data  => pdi_data,
      pdi_valid => lwc_pdi_valid,
      pdi_ready => lwc_pdi_ready,
      --
      sdi_data  => sdi_data,
      sdi_valid => lwc_sdi_valid,
      sdi_ready => lwc_sdi_ready,
      --
      do_data   => do_data,
      do_last   => do_last,
      do_valid  => do_valid,
      do_ready  => do_ready,
      --
      rdi_data  => lwc_rdi_data,
      rdi_valid => lwc_rdi_valid,
      rdi_ready => lwc_rdi_ready
    );

end architecture;
