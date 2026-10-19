library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity compact_lcd_radar_ctrl is
port (
    clk, rst, tick_1ms : in std_logic;
    self_test_en, standby_en, run_en, tracking_mode, blink_2hz : in std_logic;
    scan_index : in integer range 0 to 36;
    result_done : in std_logic;
    distance_hundreds, distance_thousands : in integer range 0 to 9;
    distance_valid : in std_logic;
    lcd_db : out std_logic_vector(7 downto 0);
    lcd_a0, lcd_wr_n, lcd_rd_n, lcd_cs_n, lcd_rst_n : out std_logic
);
end entity;

architecture rtl of compact_lcd_radar_ctrl is
    type state_type is (RESET_LOW, RESET_WAIT, INIT, IDLE,
                        FRAME, SCALE_POINT, PREP_POINT, POINT);
    type command_array is array (0 to 11) of std_logic_vector(7 downto 0);
    constant INIT_COMMANDS : command_array :=
        (x"AE", x"A0", x"C8", x"A2", x"2F", x"24",
         x"81", x"18", x"40", x"A6", x"A4", x"AF");
    signal state : state_type := RESET_LOW;
    signal init_index : integer range 0 to 11 := 0;
    signal phase : integer range 0 to 3 := 0;
    signal waiting : std_logic := '0';
    signal writer_start : std_logic := '0';
    signal writer_data : std_logic_vector(7 downto 0);
    signal writer_is_data, writer_busy, writer_done : std_logic;
    signal frame_page : integer range 0 to 7 := 0;
    signal frame_col : integer range 0 to 127 := 0;
    signal frame_background : std_logic := '1';
    signal frame_fill : std_logic := '0';
    signal frame_byte : std_logic_vector(7 downto 0);
    signal desired_mode, drawn_mode : integer range 0 to 3 := 0;
    signal drawn_blink : std_logic := '0';
    signal point_after_frame : std_logic := '0';
    signal event_pending, event_valid : std_logic := '0';
    signal event_index : integer range 0 to 36 := 0;
    signal scale_left : integer range 0 to 7 := 0;
    signal sum_x, sum_y : integer range 0 to 480 := 0;
    signal point_page : integer range 0 to 7 := 0;
    signal point_base_col : integer range 0 to 125 := 0;
    signal point_col : integer range 0 to 2 := 0;
    signal point_data : std_logic_vector(7 downto 0) := (others => '0');

    function direction_x(i : integer) return integer is
    begin
        case i is
            when 0 | 1 | 2 | 3 | 33 | 34 | 35 | 36 => return 60;
            when 4 | 32 => return 60;
            when 5 | 31 => return 58;
            when 6 | 30 => return 55;
            when 7 | 29 => return 52;
            when 8 | 28 => return 49;
            when 9 | 27 => return 45;
            when 10 | 26 => return 41;
            when 11 | 25 => return 37;
            when 12 | 24 => return 32;
            when 13 | 23 => return 27;
            when 14 | 22 => return 22;
            when 15 | 21 => return 17;
            when 16 | 20 => return 11;
            when 17 | 19 => return 6;
            when others => return 0;
        end case;
    end function;

    function direction_y(i : integer) return integer is
    begin
        case i is
            when 0 | 36 => return 0;
            when 1 | 35 => return 6;
            when 2 | 34 => return 11;
            when 3 | 33 => return 17;
            when 4 | 32 => return 22;
            when 5 | 31 => return 27;
            when 6 | 30 => return 32;
            when 7 | 29 => return 37;
            when 8 | 28 => return 41;
            when 9 | 27 => return 45;
            when 10 | 26 => return 49;
            when 11 | 25 => return 52;
            when 12 | 24 => return 55;
            when 13 | 23 => return 58;
            when 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 => return 60;
            when others => return 0;
        end case;
    end function;

    function arc_y(i : integer) return integer is
    begin
        case i is
            when 0 | 1 | 2 | 3 => return 2;
            when 4 | 5 | 6 => return 3;
            when 7 | 8 => return 4;
            when 9 | 10 => return 5;
            when 11 => return 6;
            when 12 => return 7;
            when 13 => return 8;
            when 14 => return 9;
            when 15 => return 10;
            when 16 => return 11;
            when 17 => return 13;
            when 18 => return 14;
            when 19 => return 16;
            when 20 => return 17;
            when 21 => return 19;
            when 22 => return 21;
            when 23 => return 23;
            when 24 => return 26;
            when 25 => return 29;
            when 26 => return 32;
            when 27 => return 36;
            when 28 => return 40;
            when 29 => return 47;
            when 30 => return 62;
            when others => return 63;
        end case;
    end function;

    function dot_mask(i : integer) return std_logic_vector is
    begin
        case i is
            when 0 => return "00000011";
            when 1 => return "00000111";
            when 2 => return "00001110";
            when 3 => return "00011100";
            when 4 => return "00111000";
            when 5 => return "01110000";
            when 6 => return "11100000";
            when others => return "11000000";
        end case;
    end function;
begin
    lcd_rst_n <= '0' when state = RESET_LOW else '1';
    desired_mode <= 1 when self_test_en = '1' else
                    2 when standby_en = '1' else
                    3 when run_en = '1' else 0;
    u_writer : entity work.lcd_bus_writer port map (
        clk => clk, rst => rst, start => writer_start,
        is_data => writer_is_data, data_in => writer_data,
        busy => writer_busy, done => writer_done,
        lcd_db => lcd_db, lcd_a0 => lcd_a0, lcd_wr_n => lcd_wr_n,
        lcd_rd_n => lcd_rd_n, lcd_cs_n => lcd_cs_n);

    process(frame_page, frame_col, frame_background, frame_fill)
        variable dx, y : integer range 0 to 64;
        variable pattern : std_logic_vector(7 downto 0);
    begin
        pattern := (others => frame_fill);
        if frame_background = '1' then
            pattern := (others => '0');
            if frame_col >= 64 then dx := frame_col - 64;
            else dx := 64 - frame_col;
            end if;
            if dx <= 60 then
                y := arc_y(dx / 2);
                if frame_page = y / 8 then pattern(y mod 8) := '1'; end if;
            end if;
            if frame_page = 7 and frame_col >= 4 and frame_col <= 124 then
                pattern(6) := '1';
            end if;
        end if;
        frame_byte <= pattern;
    end process;

    process(state, phase, init_index, frame_page, frame_byte,
            point_page, point_base_col, point_data)
    begin
        writer_data <= (others => '0');
        writer_is_data <= '0';
        if state = INIT then
            writer_data <= INIT_COMMANDS(init_index);
        elsif state = FRAME or state = POINT then
            case phase is
                when 0 =>
                    if state = FRAME then
                        writer_data <= "10110" & std_logic_vector(to_unsigned(frame_page, 3));
                    else
                        writer_data <= "10110" & std_logic_vector(to_unsigned(point_page, 3));
                    end if;
                when 1 =>
                    if state = FRAME then writer_data <= x"10";
                    else writer_data <= std_logic_vector(to_unsigned(16 + point_base_col / 16, 8));
                    end if;
                when 2 =>
                    if state = FRAME then writer_data <= x"00";
                    else writer_data <= std_logic_vector(to_unsigned(point_base_col mod 16, 8));
                    end if;
                when others =>
                    writer_is_data <= '1';
                    if state = FRAME then writer_data <= frame_byte;
                    else writer_data <= point_data;
                    end if;
            end case;
        end if;
    end process;

    process(clk)
        variable target_x : integer range 4 to 124;
        variable target_y : integer range 2 to 62;
        variable dx, dy : integer range 0 to 60;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= RESET_LOW;
                init_index <= 0;
                phase <= 0;
                waiting <= '0';
                writer_start <= '0';
                frame_page <= 0;
                frame_col <= 0;
                frame_background <= '1';
                frame_fill <= '0';
                drawn_mode <= 0;
                drawn_blink <= '0';
                point_after_frame <= '0';
                event_pending <= '0';
                event_valid <= '0';
                event_index <= 0;
                scale_left <= 0;
                sum_x <= 0;
                sum_y <= 0;
                point_page <= 0;
                point_base_col <= 0;
                point_col <= 0;
                point_data <= (others => '0');
            else
                writer_start <= '0';
                if result_done = '1' and run_en = '1' then
                    event_pending <= '1';
                    event_index <= scan_index;
                    event_valid <= distance_valid;
                    if distance_thousands /= 0 or distance_hundreds >= 7 then
                        scale_left <= 7;
                    else
                        scale_left <= distance_hundreds;
                    end if;
                end if;

                case state is
                    when RESET_LOW =>
                        if tick_1ms = '1' then state <= RESET_WAIT; end if;
                    when RESET_WAIT =>
                        if tick_1ms = '1' then state <= INIT; end if;
                    when INIT | FRAME | POINT =>
                        if waiting = '0' then
                            if writer_busy = '0' then
                                writer_start <= '1';
                                waiting <= '1';
                            end if;
                        elsif writer_done = '1' then
                            waiting <= '0';
                            if state = INIT then
                                if init_index = 11 then state <= IDLE;
                                else init_index <= init_index + 1;
                                end if;
                            elsif state = FRAME then
                                if phase < 3 then phase <= phase + 1;
                                elsif frame_col < 127 then frame_col <= frame_col + 1;
                                elsif frame_page < 7 then
                                    frame_page <= frame_page + 1;
                                    frame_col <= 0;
                                    phase <= 0;
                                else
                                    drawn_mode <= desired_mode;
                                    drawn_blink <= frame_fill;
                                    if point_after_frame = '1' then
                                        point_after_frame <= '0';
                                        if event_valid = '1' then
                                            sum_x <= 0;
                                            sum_y <= 0;
                                            state <= SCALE_POINT;
                                        else state <= IDLE;
                                        end if;
                                    else state <= IDLE;
                                    end if;
                                end if;
                            else
                                if phase < 3 then phase <= phase + 1;
                                elsif point_col < 2 then point_col <= point_col + 1;
                                else state <= IDLE;
                                end if;
                            end if;
                        end if;
                    when IDLE =>
                        if desired_mode /= drawn_mode or
                           (desired_mode = 1 and blink_2hz /= drawn_blink) then
                            frame_page <= 0;
                            frame_col <= 0;
                            phase <= 0;
                            frame_background <= '0';
                            frame_fill <= '0';
                            if desired_mode = 1 then frame_fill <= blink_2hz;
                            elsif desired_mode = 2 or desired_mode = 3 then
                                frame_background <= '1';
                            end if;
                            state <= FRAME;
                        elsif desired_mode = 3 and event_pending = '1' then
                            event_pending <= '0';
                            if event_index = 0 or tracking_mode = '1' then
                                frame_page <= 0;
                                frame_col <= 0;
                                phase <= 0;
                                frame_background <= '1';
                                frame_fill <= '0';
                                point_after_frame <= '1';
                                state <= FRAME;
                            elsif event_valid = '1' then
                                sum_x <= 0;
                                sum_y <= 0;
                                state <= SCALE_POINT;
                            end if;
                        end if;
                    when SCALE_POINT =>
                        sum_x <= sum_x + direction_x(event_index);
                        sum_y <= sum_y + direction_y(event_index);
                        if scale_left = 0 then state <= PREP_POINT;
                        else scale_left <= scale_left - 1;
                        end if;
                    when PREP_POINT =>
                        dx := sum_x / 8;
                        dy := sum_y / 8;
                        if event_index <= 18 then target_x := 64 + dx;
                        else target_x := 64 - dx;
                        end if;
                        target_y := 62 - dy;
                        point_page <= target_y / 8;
                        point_base_col <= target_x - 1;
                        point_col <= 0;
                        point_data <= dot_mask(target_y mod 8);
                        phase <= 0;
                        state <= POINT;
                    when others => state <= RESET_LOW;
                end case;
            end if;
        end if;
    end process;
end architecture;
