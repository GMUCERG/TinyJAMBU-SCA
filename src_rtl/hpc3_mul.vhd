library ieee;
use ieee.std_logic_1164.all;

use work.design_pkg.all;

entity hpc3_mul is
    generic(
        -- protection order (number of shares = G_ORDER + 1)
        G_ORDER : natural  := NUM_SHARES - 1;
        G_W     : positive := SHARE_WIDTH
    );
    port(
        clk : in  std_logic;
        --! clock-enable, enables register updates
        en  : in  std_logic := '1';
        --! inputs 'x' and 'y', each split into `ORDER + 1` shares
        x   : in  share_array;
        y   : in  share_array;
        --! fresh random input
        r   : in  std_logic_vector(0 to CCRW - 1);
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

end architecture;
