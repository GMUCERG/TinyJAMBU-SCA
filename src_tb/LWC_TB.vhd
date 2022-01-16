--===============================================================================================--
--! @file       LWC_TB.vhd
--! @brief      NIST Lightweight Cryptography Testbench
--! @project    GMU LWC Package
--! @author     Ekawat (ice) Homsirikamol
--! @author     Kamyar Mohajerani
--! @copyright  Copyright (c) 2015, 2020, 2021, 2022 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @version    1.2.0
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
--===============================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.NIST_LWAPI_pkg.all;
use work.LWC_pkg.all;

entity LWC_TB IS
    generic(
        G_MAX_FAILURES     : integer := 0; --! Maximum number of failures before stopping the simulation
        G_TEST_MODE        : integer := 0; --! 0: normal, 1: stall both sdi/pdi_valid and do_ready, 2: stall sdi/pdi_valid, 3: stall do_ready, 4: Timing (cycle) measurement 
        G_TEST_IPSTALL     : integer := 3; --! Number of cycles to stall pdi_valid
        G_TEST_ISSTALL     : integer := 3; --! Number of cycles to stall sdi_valid
        G_TEST_OSTALL      : integer := 3; --! Number of cycles to stall do_ready
        G_PERIOD_PS        : integer := 10_000; --! Simulation clock period in picoseconds
        G_FNAME_PDI        : string  := "../KAT/v1/pdi.txt"; --! Path to the input file containing cryptotvgen PDI testvector data
        G_FNAME_SDI        : string  := "../KAT/v1/sdi.txt"; --! Path to the input file containing cryptotvgen SDI testvector data
        G_FNAME_DO         : string  := "../KAT/v1/do.txt"; --! Path to the input file containing cryptotvgen DO testvector data
        G_FNAME_LOG        : string  := "log.txt"; --! Path to the generated log file
        G_FNAME_TIMING     : string  := "timing.txt"; --! Path to the generated timing measurements (when G_TEST_MODE=4)
        G_FNAME_FAILED_TVS : string  := "failed_testvectors.txt"; --! Path to the generated log of failed testvector words
        G_FNAME_RESULT     : string  := "result.txt"; --! Path to the generated result file containing 0 or 1  -- REDUNDANT / NOT USED
        G_PRERESET_WAIT_NS : integer := 0; --! Time (in nanosecods) to wait before reseting UUT. Xilinx GSR takes 100ns, required for post-synth simulation
        G_INPUT_DELAY_NS   : integer := 0 --! Input delay
    );
end LWC_TB;

architecture TB of LWC_TB is
    --================================================== Constants ==================================================--
    constant W_S         : positive       := W * PDI_SHARES;
    constant SW_S        : positive       := SW * SDI_SHARES;
    constant input_delay : TIME           := G_INPUT_DELAY_NS * ns;
    constant clk_period  : TIME           := G_PERIOD_PS * ps;
    constant TB_HEAD     : string(1 to 6) := "# TB :";
    constant INS_HEAD    : string(1 to 6) := "INS = ";
    constant HDR_HEAD    : string(1 to 6) := "HDR = ";
    constant DAT_HEAD    : string(1 to 6) := "DAT = ";
    constant STT_HEAD    : string(1 to 6) := "STT = ";

    --=================================================== Signals ===================================================--
    --! stop clock generation
    signal stop_clock        : boolean                             := False;
    --! initial reset of UUT is complete
    signal reset_done        : boolean                             := False;
    --=================================================== Wirings ===================================================--
    signal clk               : std_logic                           := '0';
    signal rst               : std_logic                           := '0';
    --! PDI
    signal pdi_data          : std_logic_vector(W_S - 1 downto 0)  := (others => '0');
    signal pdi_data_delayed  : std_logic_vector(W_S - 1 downto 0)  := (others => '0');
    signal pdi_valid         : std_logic                           := '0';
    signal pdi_valid_delayed : std_logic                           := '0';
    signal pdi_ready         : std_logic;
    --! SDI
    signal sdi_data          : std_logic_vector(SW_S - 1 downto 0) := (others => '0');
    signal sdi_data_delayed  : std_logic_vector(SW_S - 1 downto 0) := (others => '0');
    signal sdi_valid         : std_logic                           := '0';
    signal sdi_valid_delayed : std_logic                           := '0';
    signal sdi_ready         : std_logic;
    --! DO
    signal do_data           : std_logic_vector(W_S - 1 downto 0);
    signal do_valid          : std_logic;
    signal do_last           : std_logic;
    signal do_ready          : std_logic                           := '0';
    signal do_ready_delayed  : std_logic                           := '0';
    -- Used only for protected implementations:
    --   RDI
    signal rdi_data          : std_logic_vector(RW - 1 downto 0);
    signal rdi_valid         : std_logic                           := '0';
    signal rdi_ready         : std_logic;
    --   unshared version of DO
    signal do_sum            : std_logic_vector(W - 1 downto 0);
    -- Counters
    signal tv_count          : integer                             := 0;
    signal cycle_counter     : natural                             := 0;
    --
    signal start_cycle          : natural;
    signal timing_started       : boolean := False;
    signal timing_stopped       : boolean := False;

    --================================================== I/O files ==================================================--
    file pdi_file      : TEXT open read_mode is G_FNAME_PDI;
    file sdi_file      : TEXT open read_mode is G_FNAME_SDI;
    file do_file       : TEXT open read_mode is G_FNAME_DO;
    file log_file      : TEXT open write_mode is G_FNAME_LOG;
    file timing_file   : TEXT open write_mode is G_FNAME_TIMING;
    file result_file   : TEXT open write_mode is G_FNAME_RESULT;
    file failures_file : TEXT open write_mode is G_FNAME_FAILED_TVS;

    --================================================== functions ==================================================--
    function word_pass(actual : std_logic_vector(W-1 downto 0); expected : std_logic_vector(W-1 downto 0)) return boolean is
    begin
        for i in W - 1 downto 0 loop
            if actual(i) /= expected(i) and expected(i) /= 'X' then
                return False;
            end if;
        end loop;
        return True;
    end function word_pass;

    function xor_shares(do_data : std_logic_vector; num_shares : positive) return std_logic_vector is
        constant share_width : natural                                    := do_data'length / num_shares;
        variable ret         : std_logic_vector(share_width - 1 downto 0) := do_data(share_width - 1 downto 0);
    begin
        for i in 1 to num_shares - 1 loop
            ret := ret xor do_data((i + 1) * share_width - 1 downto i * share_width);
        end loop;
        return ret;
    end function;

    -- TODO re-implement random stalls
    impure function get_stalls(max_stalls : integer) return integer is
    begin
        return max_stalls;
    end function get_stalls;

begin

    --===========================================================================================--
    -- generate UUT clock
    clockProc : process
    begin
        if not stop_clock then
            clk <= '1';
            wait for clk_period / 2;
            clk <= '0';
            wait for clk_period / 2;
        else
            wait;
        end if;
    end process;

    -- generate UUT reset
    resetProc : process
    begin
        report LF & " -- Testvectors:  " & G_FNAME_PDI & " " & G_FNAME_SDI & " " & G_FNAME_DO & LF &
        " -- Clock Period: " & integer'image(G_PERIOD_PS) & " ps" & LF &
        " -- Test Mode:    " & integer'image(G_TEST_MODE) & LF &
        " -- Max Failures: " & integer'image(G_MAX_FAILURES) & LF & CR severity note;

        wait for G_PRERESET_WAIT_NS * ns;
        if ASYNC_RSTN then
            rst <= '0';
            wait for 2 * clk_period;
            rst <= '1';
        else
            rst <= '1';
            wait for 2 * clk_period + input_delay;
            rst <= '0';
        end if;
        wait until rising_edge(clk);
        wait for clk_period;            -- optional
        reset_done <= True;
        wait;
    end process;

    cycleCountProc : process(clk)
    begin
        if reset_done and rising_edge(clk) then
            cycle_counter <= cycle_counter + 1;
        end if;
    end process;

    --===========================================================================================--
    -- LWC is instantiated as a component for mixed languages simulation
    uut : LWC_SCA
        port map(
            clk       => clk,
            rst       => rst,
            pdi_data  => pdi_data_delayed,
            pdi_valid => pdi_valid_delayed,
            pdi_ready => pdi_ready,
            sdi_data  => sdi_data_delayed,
            sdi_valid => sdi_valid_delayed,
            sdi_ready => sdi_ready,
            do_data   => do_data,
            do_last   => do_last,
            do_valid  => do_valid,
            do_ready  => do_ready_delayed,
            rdi_data  => rdi_data,
            rdi_valid => rdi_valid,
            rdi_ready => rdi_ready
        );

    --===========================================================================================--

    pdi_data_delayed  <= transport pdi_data after input_delay;
    pdi_valid_delayed <= transport pdi_valid after input_delay;
    sdi_data_delayed  <= transport sdi_data after input_delay;
    sdi_valid_delayed <= transport sdi_valid after input_delay;
    do_ready_delayed  <= transport do_ready after input_delay;

    do_sum <= xor_shares(do_data, PDI_SHARES);

    rdi_proc : process
    begin
        rdi_valid <= '0';
        wait for 100 * clk_period;
        rdi_valid <= '1';
        wait for 100 * clk_period;
        rdi_valid <= '0';
        wait for 100 * clk_period;
        rdi_valid <= '1';
        wait;
    end process;
    rdi_data <= (others => '1');

    --===========================================================================================--
    --====================================== PDI Stimulus =======================================--
    tb_read_pdi : process
        variable line_data    : LINE;
        variable word_block   : std_logic_vector(W_S - 1 downto 0) := (others => '0');
        variable read_ok      : boolean;
        variable line_head    : string(1 to 6);
        variable stall_cycles : integer;
        variable actkey_ins   : boolean;
        variable hash_ins     : boolean;
        -- instruction other than actkey or hash was already sent
        variable op_sent      : boolean                            := False;
    begin
        wait until reset_done;
        wait until rising_edge(clk);

        while not endfile(pdi_file) loop
            readline(pdi_file, line_data);
            read(line_data, line_head, read_ok); --! read line header
            if read_ok and (line_head = INS_HEAD) then
                tv_count <= tv_count + 1;
            end if;
            if read_ok and (line_head = INS_HEAD or line_head = HDR_HEAD or line_head = DAT_HEAD) then
                loop
                    lwc_hread(line_data, word_block, read_ok);
                    if not read_ok then
                        exit;
                    end if;

                    actkey_ins := (line_head = INS_HEAD) and (word_block(W - 1 downto W - 4) = INST_ACTKEY);
                    hash_ins   := (line_head = INS_HEAD) and (word_block(W - 1 downto W - 4) = INST_HASH);

                    -- stalls
                    if G_TEST_MODE = 1 or G_TEST_MODE = 2 then
                        stall_cycles := get_stalls(G_TEST_IPSTALL);
                        if stall_cycles > 0 then
                            pdi_valid <= '0';
                            wait for stall_cycles * clk_period;
                            wait until rising_edge(clk); -- TODO verify number of generated stall cycles
                        end if;
                    elsif G_TEST_MODE = 4 and line_head = INS_HEAD and (actkey_ins or hash_ins or op_sent) and timing_started then
                        if not timing_stopped then
                            pdi_valid <= '0';
                            wait until rising_edge(clk) and timing_stopped; -- wait for tb_verify_do process to complete timed operation
                        end if;
                        timing_started <= False; -- Ack receiving timing_stopped = '1' to tb_verify_do process
                    end if;

                    pdi_valid <= '1';
                    pdi_data  <= word_block;
                    wait until rising_edge(clk) and pdi_ready = '1';

                    -- NOTE: should never stall here
                    if G_TEST_MODE = 4 and line_head = INS_HEAD then
                        op_sent := not actkey_ins and not hash_ins;
                        if not timing_started then
                            start_cycle    <= cycle_counter;
                            timing_started <= True;
                            wait for 0 ns; -- yield to update timing_started signal as there could be no wait before next read
                        end if;
                    end if;

                end loop;
            end if;
        end loop;

        pdi_valid <= '0';

        if timing_started and not timing_stopped then
            wait until timing_stopped;
            timing_started <= False;
        end if;

        wait;                           -- forever
    end process;

    --===========================================================================================--
    --====================================== SDI Stimulus =======================================--
    tb_read_sdi : process
        variable line_data    : LINE;
        variable word_block   : std_logic_vector(SW_S - 1 downto 0);
        variable read_ok      : boolean;
        variable line_head    : string(1 to 6);
        variable stall_cycles : integer;
    begin
        wait until reset_done;
        wait until rising_edge(clk);

        while not endfile(sdi_file) loop
            readline(sdi_file, line_data);
            read(line_data, line_head, read_ok);
            if read_ok and (line_head = INS_HEAD or line_head = HDR_HEAD or line_head = DAT_HEAD) then
                loop
                    lwc_hread(line_data, word_block, read_ok);
                    if not read_ok then
                        exit;
                    end if;

                    if G_TEST_MODE = 1 or G_TEST_MODE = 2 then
                        stall_cycles := get_stalls(G_TEST_ISSTALL);
                        if stall_cycles > 0 then
                            sdi_valid <= '0';
                            wait for stall_cycles * clk_period;
                        end if;
                    elsif G_TEST_MODE = 4 and not timing_started then
                        sdi_valid <= '0';
                        wait until timing_started;
                    end if;

                    sdi_valid <= '1';
                    sdi_data  <= word_block;
                    wait until rising_edge(clk) and sdi_ready = '1';
                end loop;
            end if;
        end loop;
        sdi_valid <= '0';
        wait;                           -- forever
    end process;

    --===========================================================================================--
    --=================================== DO Verification =======================================--
    tb_verify_do : process
        variable line_no      : integer := 0;
        variable line_data    : LINE;
        variable logMsg       : LINE;
        variable failMsg      : LINE;
        variable tb_block     : std_logic_vector(20 - 1 downto 0);
        variable word_block   : std_logic_vector(W - 1 downto 0);
        variable read_ok      : boolean;
        variable temp_read    : string(1 to 6);
        variable word_count   : integer := 1;
        variable force_exit   : boolean := False;
        variable failed       : boolean := False;
        variable msgid        : integer;
        variable keyid        : integer;
        variable opcode       : std_logic_vector(3 downto 0);
        variable num_fails    : integer := 0;
        variable testcase     : integer := 0;
        variable stall_cycles : integer;
        variable cycles       : integer;
        variable end_cycle    : natural;
        variable end_time     : TIME;
        alias do_data         : std_logic_vector(W - 1 downto 0) is do_sum;
    begin
        wait until reset_done;
        wait until rising_edge(clk);
        while not endfile(do_file) and not force_exit loop
            readline(do_file, line_data);
            line_no := line_no + 1;
            read(line_data, temp_read, read_ok);
            if read_ok then
                if temp_read = STT_HEAD or temp_read = HDR_HEAD or temp_read = DAT_HEAD then
                    loop
                        lwc_hread(line_data, word_block, read_ok);
                        if not read_ok then
                            exit;
                        end if;

                        -- stalls
                        if G_TEST_MODE = 1 or G_TEST_MODE = 3 then
                            stall_cycles := get_stalls(G_TEST_OSTALL);
                            if stall_cycles > 0 then
                                do_ready <= '0';
                                wait for stall_cycles * clk_period;
                                -- wait until rising_edge(clk);
                            end if;
                        elsif G_TEST_MODE = 4 and not timing_started then
                            -- stall until timing has started from PDI
                            do_ready       <= '0';
                            timing_stopped <= False;
                            wait until timing_started;
                        end if;

                        do_ready <= '1';
                        wait until rising_edge(clk) and do_valid = '1';

                        if not word_pass(do_data, word_block) then
                            failed    := True;
                            write(logMsg, string'("[Log] Msg ID #") & integer'image(msgid) & string'(" fails at line #") & integer'image(line_no) & string'(" word #") & integer'image(word_count));
                            writeline(log_file, logMsg);
                            write(logMsg, string'("[Log]     Expected: ") & lwc_to_hstring(word_block) & string'(" Received: ") & lwc_to_hstring(do_data));
                            writeline(log_file, logMsg);
                            report " --- MsgID #" & integer'image(testcase)
                                & " Data line #" & integer'image(line_no)
                                & " Word #" & integer'image(word_count)
                                & " at " & TIME'image(now) & " FAILS ---"
                            severity error;
                            report "Expected: " & lwc_to_hstring(word_block)
                                & " Actual: " & lwc_to_hstring(do_data) severity error;
                            write(result_file, string'("fail"));
                            num_fails := num_fails + 1;
                            write(failMsg, string'("Failure #") & integer'image(num_fails) & " MsgID: " & integer'image(testcase)); -- & " Operation: ");

                            write(failMsg, string'(" Line: ") & integer'image(line_no) & " Word: " & integer'image(word_count) & " Expected: " & lwc_to_hstring(word_block) & " Received: " & lwc_to_hstring(do_data));
                            writeline(failures_file, failMsg);
                            if num_fails >= G_MAX_FAILURES then
                                force_exit := True;
                            end if;
                        else
                            write(logMsg, string'("[Log]     Expected: ") & lwc_to_hstring(word_block) & string'(" Received: ") & lwc_to_hstring(do_data) & string'(" Matched!"));
                            writeline(log_file, logMsg);
                        end if;
                        word_count := word_count + 1;

                        if G_TEST_MODE = 4 and temp_read = STT_HEAD then
                            assert timing_started;
                            cycles         := cycle_counter - start_cycle;
                            timing_stopped <= True;
                            do_ready       <= '0';
                            wait until not timing_started;
                            write(logMsg, integer'image(msgid) & ", " & integer'image(cycles));
                            writeline(timing_file, logMsg);
                            report "[Timing] MsgId: " & integer'image(msgid) & ", cycles: " & integer'image(cycles) severity note;
                        end if;
                    end loop;
                elsif temp_read = TB_HEAD then
                    testcase := testcase + 1;
                    lwc_hread(line_data, tb_block, read_ok);
                    if not read_ok then
                        exit;
                    end if;
                    opcode   := tb_block(19 downto 16);
                    keyid    := to_integer(to_01(unsigned(tb_block(15 downto 8))));
                    msgid    := to_integer(to_01(unsigned(tb_block(7 downto 0))));
                    if ((opcode = INST_DEC or opcode = INST_ENC or opcode = INST_HASH) or (opcode = INST_SUCCESS or opcode = INST_FAILURE)) then
                        write(logMsg, string'("[Log] == Verifying msg ID #") & integer'image(testcase));
                        if (opcode = INST_ENC) then
                            write(logMsg, string'(" for ENC"));
                        elsif (opcode = INST_HASH) then
                            write(logMsg, string'(" for HASH"));
                        else
                            write(logMsg, string'(" for DEC"));
                        end if;
                        writeline(log_file, logMsg);
                    end if;
                    report "--------- Verifying testcase " & integer'image(testcase) & " MsgID = " & integer'image(msgid) & " KeyID = " & integer'image(keyid) severity note;
                end if;
            end if;
        end loop;

        end_cycle := cycle_counter;
        end_time  := now;

        do_ready <= '0';
        wait until rising_edge(clk);

        if failed then
            report "FAIL (1): SIMULATION FINISHED after " & integer'image(end_cycle) & " cycles at " & TIME'image(end_time) severity failure; -- error
            write(logMsg, "FAIL (1): SIMULATION FINISHED after " & integer'image(end_cycle) & " cycles at " & TIME'image(end_time));
            write(result_file, "1");
        else
            report "PASS (0): SIMULATION FINISHED after " & integer'image(end_cycle) & " cycles at " & TIME'image(end_time) severity note;
            write(logMsg, "PASS (0): SIMULATION FINISHED after " & integer'image(end_cycle) & " cycles at " & TIME'image(end_time));
            write(result_file, "0");
        end if;

        writeline(log_file, logMsg);
        write(logMsg, string'("[Log] Done"));
        writeline(log_file, logMsg);

        file_close(do_file);
        file_close(result_file);
        file_close(log_file);
        file_close(timing_file);

        stop_clock <= True;
        wait;
    end process;

end architecture;
