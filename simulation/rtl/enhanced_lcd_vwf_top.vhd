library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Simulation-only wrapper around the real enhanced LCD controller.  The
-- monitor decodes its external bus; it is not part of the programmed design.
entity enhanced_lcd_vwf_top is
    port (
        clk                : in  std_logic;
        rst                : in  std_logic;
        tick_1ms           : in  std_logic;
        run_en             : in  std_logic;
        result_done        : in  std_logic;
        lcd_db             : out std_logic_vector(7 downto 0);
        lcd_a0             : out std_logic;
        lcd_wr_n           : out std_logic;
        lcd_cs_n           : out std_logic;
        lcd_rst_n          : out std_logic;
        write_event        : out std_logic;
        data_write         : out std_logic;
        decoded_page_u3    : out std_logic_vector(2 downto 0);
        decoded_col_u7     : out std_logic_vector(6 downto 0);
        decoded_data       : out std_logic_vector(7 downto 0);
        data_count_u11     : out std_logic_vector(10 downto 0);
        init_af_seen       : out std_logic;
        point_match        : out std_logic
    );
end entity enhanced_lcd_vwf_top;

architecture structural of enhanced_lcd_vwf_top is
    signal db_s      : std_logic_vector(7 downto 0);
    signal a0_s      : std_logic;
    signal wr_n_s    : std_logic;
    signal rd_n_s    : std_logic;
    signal cs_n_s    : std_logic;
    signal rst_n_s   : std_logic;

    signal page_s      : integer range 0 to 7 := 0;
    signal col_high_s  : integer range 0 to 7 := 0;
    signal col_low_s   : integer range 0 to 15 := 0;
    signal col_s       : integer range 0 to 127 := 0;
    signal data_count_s : integer range 0 to 2047 := 0;
    signal decoded_data_s : std_logic_vector(7 downto 0) := (others => '0');
    signal write_event_s : std_logic := '0';
    signal data_write_s  : std_logic := '0';
    signal init_seen_s   : std_logic := '0';
    signal point_match_s : std_logic := '0';
begin
    u_dut : entity work.enhanced_lcd_radar_ctrl
        port map (
            clk            => clk,
            rst            => rst,
            tick_1ms       => tick_1ms,
            self_test_en   => '0',
            standby_en     => '0',
            run_en         => run_en,
            blink_2hz      => '0',
            scan_index     => 18,
            result_done    => result_done,
            distance_mm    => 400,
            distance_valid => '1',
            lcd_db         => db_s,
            lcd_a0         => a0_s,
            lcd_wr_n       => wr_n_s,
            lcd_rd_n       => rd_n_s,
            lcd_cs_n       => cs_n_s,
            lcd_rst_n      => rst_n_s
        );

    process(clk)
        variable next_col : integer range 0 to 127;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                page_s          <= 0;
                col_high_s      <= 0;
                col_low_s       <= 0;
                col_s           <= 0;
                data_count_s    <= 0;
                decoded_data_s  <= (others => '0');
                write_event_s   <= '0';
                data_write_s    <= '0';
                init_seen_s     <= '0';
                point_match_s   <= '0';
            else
                write_event_s <= '0';
                data_write_s  <= '0';
                point_match_s <= '0';

                -- WR is low for one complete clock in the real bus writer.
                if cs_n_s = '0' and wr_n_s = '0' then
                    write_event_s <= '1';

                    if a0_s = '0' then
                        if db_s(7 downto 4) = "1011" then
                            page_s <= to_integer(unsigned(db_s(2 downto 0)));
                        elsif db_s(7 downto 4) = "0001" then
                            col_high_s <= to_integer(unsigned(db_s(2 downto 0)));
                            col_s <= to_integer(unsigned(db_s(2 downto 0))) * 16 + col_low_s;
                        elsif db_s(7 downto 4) = "0000" then
                            col_low_s <= to_integer(unsigned(db_s(3 downto 0)));
                            col_s <= col_high_s * 16 + to_integer(unsigned(db_s(3 downto 0)));
                        end if;

                        if db_s = x"AF" then
                            init_seen_s <= '1';
                        end if;
                    else
                        data_write_s   <= '1';
                        decoded_data_s <= db_s;
                        if data_count_s < 2047 then
                            data_count_s <= data_count_s + 1;
                        end if;

                        -- For index 18 and 400 mm the enhanced renderer should
                        -- write a 3-column dot at page 4, columns 63..65, data 03h.
                        if page_s = 4 and col_s >= 63 and col_s <= 65 and
                           db_s = x"03" then
                            point_match_s <= '1';
                        end if;

                        if col_s < 127 then
                            next_col := col_s + 1;
                            col_s    <= next_col;
                            col_high_s <= next_col / 16;
                            col_low_s  <= next_col mod 16;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    lcd_db          <= db_s;
    lcd_a0          <= a0_s;
    lcd_wr_n        <= wr_n_s;
    lcd_cs_n        <= cs_n_s;
    lcd_rst_n       <= rst_n_s;
    write_event     <= write_event_s;
    data_write      <= data_write_s;
    decoded_page_u3 <= std_logic_vector(to_unsigned(page_s, 3));
    decoded_col_u7  <= std_logic_vector(to_unsigned(col_s, 7));
    decoded_data    <= decoded_data_s;
    data_count_u11  <= std_logic_vector(to_unsigned(data_count_s, 11));
    init_af_seen    <= init_seen_s;
    point_match     <= point_match_s;
end architecture structural;
