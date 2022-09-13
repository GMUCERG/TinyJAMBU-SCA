library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.NIST_LWAPI_pkg.all;

entity asym_ram is
    generic(
        G_IN_W     : positive := 4;
        G_OUT_W    : positive := 16;
        G_CAPACITY : positive := 4096
    );

    port(
        -- Write
        wr_clk   : in  std_logic;
        wr_valid : in  std_logic;
        wr_data  : in  std_logic_vector(G_IN_W - 1 downto 0);
        wr_addr  : in  std_logic_vector(log2ceil(G_CAPACITY / G_IN_W) - 1 downto 0);
        -- Read
        rd_clk   : in  std_logic;
        rd_ready : in  std_logic;
        rd_addr  : in  std_logic_vector(log2ceil(G_CAPACITY / G_OUT_W) - 1 downto 0);
        rd_data  : out std_logic_vector(G_OUT_W - 1 downto 0)
    );

end asym_ram;

architecture RTL of asym_ram is

    constant MIN_WIDTH : positive := minimum(G_IN_W, G_OUT_W);
    constant MAX_WIDTH : positive := maximum(G_IN_W, G_OUT_W);
    constant RATIO     : positive := MAX_WIDTH / MIN_WIDTH;

    type T_RAM is array (0 to G_CAPACITY / MIN_WIDTH - 1) of std_logic_vector(MIN_WIDTH - 1 downto 0);

    --- Memory
    signal ram : T_RAM;

    -- Registers
    signal out_reg : std_logic_vector(G_OUT_W - 1 downto 0);

    -- Wires
    signal read_data : std_logic_vector(G_OUT_W - 1 downto 0);

begin

    GEN_READ_WIDER : if G_OUT_W >= G_IN_W generate
        assert wr_data'length = MIN_WIDTH severity failure;
        -- Write
        process(wr_clk) is
        begin
            if rising_edge(wr_clk) then
                if wr_valid = '1' then
                    ram(TO_INT01(wr_addr)) <= wr_data;
                end if;
            end if;
        end process;
        -- Read
        process(rd_clk) is
        begin
            if rising_edge(rd_clk) then
                for i in 0 to RATIO - 1 loop
                    if rd_ready = '1' then
                        read_data((i + 1) * MIN_WIDTH - 1 downto i * MIN_WIDTH) <= ram(TO_INT01(rd_addr & to_std_logic_vector(i, log2ceil(RATIO))));
                    end if;
                end loop;
                out_reg <= read_data;
            end if;
        end process;
    end generate;

    GEN_WRITE_WIDER : if G_OUT_W < G_IN_W generate
        -- Write
        process(wr_clk) is
        begin
            if rising_edge(wr_clk) then
                for i in 0 to RATIO - 1 loop
                    if wr_valid = '1' then
                        ram(TO_INT01(wr_addr & to_std_logic_vector(i, log2ceil(RATIO)))) <= wr_data((i + 1) * MIN_WIDTH - 1 downto i * MIN_WIDTH);
                    end if;
                end loop;
            end if;
        end process;
        -- Read
        process(rd_clk) is
        begin
            if rising_edge(rd_clk) then
                for i in 0 to RATIO - 1 loop
                    if rd_ready = '1' then
                        read_data <= ram(TO_INT01(rd_addr));
                    end if;
                end loop;
                out_reg <= read_data;
            end if;
        end process;
    end generate;

    rd_data <= out_reg;

end architecture;
