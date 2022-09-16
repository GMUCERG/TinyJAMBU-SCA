library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.NIST_LWAPI_pkg.all;

entity asym_ram is
    generic(
        G_WR_W      : positive := 4;
        G_RD_W      : positive := 2 * 32;
        G_CAPACITY  : positive := (256 * 64) * 2 * 32;
        G_BIGENDIAN : boolean  := true
    );

    port(
        -- Write
        clk      : in  std_logic;
        wr_valid : in  std_logic;
        wr_data  : in  std_logic_vector(G_WR_W - 1 downto 0);
        wr_addr  : in  std_logic_vector(log2ceil(G_CAPACITY / G_WR_W) - 1 downto 0);
        -- Read
        rd_ready : in  std_logic;
        rd_addr  : in  std_logic_vector(log2ceil(G_CAPACITY / G_RD_W) - 1 downto 0);
        rd_data  : out std_logic_vector(G_RD_W - 1 downto 0)
    );

end asym_ram;

architecture RTL of asym_ram is

    constant MIN_WIDTH : positive := minimum(G_WR_W, G_RD_W);

    constant WR_RD_LOG2 : natural := log2ceil(G_WR_W / G_RD_W);
    constant RD_WR_LOG2 : natural := log2ceil(G_RD_W / G_WR_W);

    type T_RAM is array (0 to G_CAPACITY / MIN_WIDTH - 1) of std_logic_vector(MIN_WIDTH - 1 downto 0);

    --- Memory
    signal ram : T_RAM;

    -- Registers
    signal out_reg : std_logic_vector(G_RD_W - 1 downto 0);

    -- Wires
    signal read_data : std_logic_vector(G_RD_W - 1 downto 0);
    signal rd_ptr    : unsigned(rd_addr'range);
    signal wr_ptr    : unsigned(wr_addr'range);

begin
    rd_ptr <= unsigned(rd_addr);
    wr_ptr <= unsigned(wr_addr);

    GEN_READ_WIDER : if G_RD_W >= G_WR_W generate
        signal read_tmp          : std_logic_vector(G_RD_W - 1 downto 0);
        constant NUM_READ_CHUNKS : positive := G_RD_W / G_WR_W;
    begin
        GEN_READ_BIG_ENDIAN : if G_BIGENDIAN generate
            GEN_READ_SWAP : for i in 0 to NUM_READ_CHUNKS - 1 generate
                read_data((NUM_READ_CHUNKS - i) * G_WR_W - 1 downto (NUM_READ_CHUNKS + i - 1) * G_WR_W) <= read_tmp((i + 1) * G_WR_W - 1 downto i * G_WR_W);
            end generate;
        end generate;

        GEN_READ_LITTLE_ENDIAN : if not G_BIGENDIAN generate
            read_data <= read_tmp;
        end generate;

        process(clk) is
        begin
            if rising_edge(clk) then
                if wr_valid = '1' then
                    ram(to_int01(wr_ptr)) <= wr_data;
                end if;
                if rd_ready = '1' then
                    for i in 0 to NUM_READ_CHUNKS - 1 loop
                        read_tmp((i + 1) * G_WR_W - 1 downto i * G_WR_W) <= ram(to_int01(rd_ptr & to_unsigned(i, RD_WR_LOG2)));
                    end loop;
                end if;
                out_reg <= read_data;
            end if;
        end process;
    end generate;

    GEN_WRITE_WIDER : if G_RD_W < G_WR_W generate
        process(clk) is
        begin
            if rising_edge(clk) then
                if wr_valid = '1' then
                    for i in 0 to 2 ** WR_RD_LOG2 - 1 loop
                        ram(to_int01(wr_ptr & to_unsigned(i, WR_RD_LOG2))) <= wr_data((i + 1) * MIN_WIDTH - 1 downto i * MIN_WIDTH);
                    end loop;
                end if;
                if rd_ready = '1' then
                    read_data <= ram(to_int01(rd_ptr));
                end if;
                out_reg <= read_data;
            end if;
        end process;
    end generate;

    rd_data <= out_reg;
end architecture;
