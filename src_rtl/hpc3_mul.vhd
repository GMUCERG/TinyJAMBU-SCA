library ieee;
use ieee.std_logic_1164.all;

use work.hpc3_utils_pkg.all;
use work.design_pkg.share_array;

entity hpc3_mul is
    generic(
        -- protection order (number of shares = G_ORDER + 1)
        G_ORDER        : natural;
        G_W            : positive;
        G_PLUS         : boolean;
        G_PLUS_OUT_REG : boolean
    );
    port(
        clk : in  std_logic;
        --! clock-enable, enables register updates
        en  : in  std_logic := '1';
        --! inputs 'x' and 'y', each split into `ORDER + 1` shares
        x   : in  share_array;
        y   : in  share_array;
        --! fresh random input
        r   : in  std_logic_vector(0 to G_W * G_ORDER * (G_ORDER + 1 + to_integer(G_PLUS)) - 1);
        --! output in `ORDER + 1` shares
        z   : out share_array
    );

end entity;

architecture RTL of hpc3_mul is
begin

    GEN_INST : for i in 0 to G_W - 1 generate
        signal xi, yi, zi : std_logic_vector(0 to G_ORDER);
    begin
        GEN_WIRING : for j in 0 to G_ORDER generate
            xi(j)   <= x(j)(i);
            yi(j)   <= y(j)(i);
            z(j)(i) <= zi(j);
        end generate;

        GEN_HPC3 : if G_PLUS generate
            INST_HPC3_PLUS : entity work.hpc3_plus_and
                generic map(G_ORDER => G_ORDER, G_OUT_REG => G_PLUS_OUT_REG)
                port map(
                    clk => clk,
                    en  => en,
                    x   => xi,
                    y   => yi,
                    r   => r(i * G_ORDER * (G_ORDER + 2) to (i + 1) * G_ORDER * (G_ORDER + 2) - 1),
                    z   => zi
                );

        end generate;
        GEN_NOT_HPC3 : if not G_PLUS generate
            INST_HPC3 : entity work.hpc3_and
                generic map(G_ORDER => G_ORDER)
                port map(
                    clk => clk,
                    en  => en,
                    x   => xi,
                    y   => yi,
                    r   => r(i * G_ORDER * (G_ORDER + 1) to (i + 1) * G_ORDER * (G_ORDER + 1) - 1),
                    z   => zi
                );

        end generate;
    end generate;

end architecture;
