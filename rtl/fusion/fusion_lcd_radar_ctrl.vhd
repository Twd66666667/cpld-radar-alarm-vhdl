library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fusion_lcd_radar_ctrl is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    tick_1ms       : in  std_logic;
    self_test_en   : in  std_logic;
    standby_en     : in  std_logic;
    run_en         : in  std_logic;
    blink_2hz      : in  std_logic;
    scan_index     : in  integer range 0 to 36;
    result_done    : in  std_logic;
    distance_hundreds : in integer range 0 to 9;
    distance_thousands : in integer range 0 to 9;
    distance_valid : in  std_logic;

    lcd_db         : out std_logic_vector(7 downto 0);
    lcd_a0         : out std_logic;
    lcd_wr_n       : out std_logic;
    lcd_rd_n       : out std_logic;
    lcd_cs_n       : out std_logic;
    lcd_rst_n      : out std_logic
);
end entity fusion_lcd_radar_ctrl;

architecture rtl of fusion_lcd_radar_ctrl is
    type state_type is (
        RESET_LOW_STATE,
        RESET_WAIT_STATE,
        INIT_STATE,
        INIT_WAIT_STATE,
        IDLE_STATE,
        FRAME_PAGE_STATE,
        FRAME_PAGE_WAIT_STATE,
        FRAME_COL_HIGH_STATE,
        FRAME_COL_HIGH_WAIT_STATE,
        FRAME_COL_LOW_STATE,
        FRAME_COL_LOW_WAIT_STATE,
        FRAME_PREP_STATE,
        FRAME_DATA_STATE,
        FRAME_DATA_WAIT_STATE,
        FRAME_DONE_STATE,
        START_POINT_STATE,
        POINT_SCALE_STATE,
        POINT_PREP_STATE,
        POINT_PAGE_STATE,
        POINT_PAGE_WAIT_STATE,
        POINT_COL_HIGH_STATE,
        POINT_COL_HIGH_WAIT_STATE,
        POINT_COL_LOW_STATE,
        POINT_COL_LOW_WAIT_STATE,
        POINT_DATA_STATE,
        POINT_DATA_WAIT_STATE
    );

    signal current_state : state_type := RESET_LOW_STATE;

    type init_command_array_type is array (0 to 11) of
        std_logic_vector(7 downto 0);
    constant INIT_COMMANDS : init_command_array_type := (
        x"AE", x"A0", x"C8", x"A2", x"2F", x"24",
        x"81", x"18", x"40", x"A6", x"A4", x"AF"
    );

    signal init_index : integer range 0 to 11 := 0;

    signal writer_start   : std_logic := '0';
    signal writer_is_data : std_logic := '0';
    signal writer_data    : std_logic_vector(7 downto 0) := (others => '0');
    signal writer_busy    : std_logic;
    signal writer_done    : std_logic;

    signal event_pending  : std_logic := '0';
    signal event_index    : integer range 0 to 36 := 0;
    signal event_valid    : std_logic := '0';

    signal displayed_mode  : integer range 0 to 3 := 1;
    signal displayed_blink : std_logic := '1';
    signal frame_target_mode : integer range 0 to 3 := 0;
    signal frame_background  : std_logic := '1';
    signal frame_fill        : std_logic := '0';
    signal point_after_frame : std_logic := '0';

    signal frame_page : integer range 0 to 7 := 0;
    signal frame_col  : integer range 0 to 127 := 0;
    signal frame_byte : std_logic_vector(7 downto 0) := (others => '0');

    signal point_page     : integer range 0 to 7 := 0;
    signal point_base_col : integer range 0 to 125 := 0;
    signal point_col      : integer range 0 to 2 := 0;
    signal point_data     : std_logic_vector(7 downto 0) := (others => '0');
    signal coord_x_sum    : integer range 0 to 480 := 0;
    signal coord_y_sum    : integer range 0 to 480 := 0;
    signal scale_left     : integer range 0 to 7 := 0;

    function direction_x(index_value : integer) return integer is
    begin
        case index_value is
            when 0 | 1 | 35 | 36 => return 60;
            when 2 | 34          => return 60;
            when 3 | 33          => return 60;
            when 4 | 32          => return 60;
            when 5 | 31          => return 58;
            when 6 | 30          => return 55;
            when 7 | 29          => return 52;
            when 8 | 28          => return 49;
            when 9 | 27          => return 45;
            when 10 | 26         => return 41;
            when 11 | 25         => return 37;
            when 12 | 24         => return 32;
            when 13 | 23         => return 27;
            when 14 | 22         => return 22;
            when 15 | 21         => return 17;
            when 16 | 20         => return 11;
            when 17 | 19         => return 6;
            when others          => return 0;
        end case;
    end function;

    function direction_y(index_value : integer) return integer is
    begin
        case index_value is
            when 0 | 36          => return 0;
            when 1 | 35          => return 6;
            when 2 | 34          => return 11;
            when 3 | 33          => return 17;
            when 4 | 32          => return 22;
            when 5 | 31          => return 27;
            when 6 | 30          => return 32;
            when 7 | 29          => return 37;
            when 8 | 28          => return 41;
            when 9 | 27          => return 45;
            when 10 | 26         => return 49;
            when 11 | 25         => return 52;
            when 12 | 24         => return 55;
            when 13 | 23         => return 58;
            when 14 | 22         => return 60;
            when 15 | 21         => return 60;
            when 16 | 20         => return 60;
            when 17 | 18 | 19    => return 60;
            when others          => return 0;
        end case;
    end function;

    function dot_mask(bit_value : integer) return std_logic_vector is
    begin
        case bit_value is
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

    function outer_y(offset_two : integer) return integer is
    begin
        case offset_two is
            when 0 => return 2;
            when 1 => return 2;
            when 2 => return 2;
            when 3 => return 2;
            when 4 => return 3;
            when 5 => return 3;
            when 6 => return 3;
            when 7 => return 4;
            when 8 => return 4;
            when 9 => return 5;
            when 10 => return 5;
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

begin
    lcd_rst_n <= '0' when current_state = RESET_LOW_STATE else '1';

    u_lcd_bus_writer : entity work.lcd_bus_writer
    port map (
        clk      => clk,
        rst      => rst,
        start    => writer_start,
        is_data  => writer_is_data,
        data_in  => writer_data,
        busy     => writer_busy,
        done     => writer_done,
        lcd_db   => lcd_db,
        lcd_a0   => lcd_a0,
        lcd_wr_n => lcd_wr_n,
        lcd_rd_n => lcd_rd_n,
        lcd_cs_n => lcd_cs_n
    );

    process(clk)
        variable pixel_y      : integer range 0 to 63;
        variable pattern      : std_logic_vector(7 downto 0);
        variable dx           : integer range 0 to 64;
        variable delta_x      : integer range 0 to 60;
        variable delta_y      : integer range 0 to 60;
        variable target_x     : integer range 4 to 124;
        variable target_y     : integer range 2 to 62;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state       <= RESET_LOW_STATE;
                init_index          <= 0;
                writer_start        <= '0';
                writer_is_data      <= '0';
                writer_data         <= (others => '0');
                event_pending       <= '0';
                event_index         <= 0;
                event_valid         <= '0';
                -- Force the first active mode to refresh LCD RAM after reset.
                displayed_mode      <= 1;
                displayed_blink     <= '1';
                frame_target_mode   <= 0;
                frame_background    <= '1';
                frame_fill          <= '0';
                point_after_frame   <= '0';
                frame_page          <= 0;
                frame_col           <= 0;
                frame_byte          <= (others => '0');
                point_page          <= 0;
                point_base_col      <= 0;
                point_col           <= 0;
                point_data          <= (others => '0');
                coord_x_sum         <= 0;
                coord_y_sum         <= 0;
                scale_left          <= 0;
            else
                writer_start <= '0';

                if result_done = '1' and run_en = '1' then
                    event_pending  <= '1';
                    event_index    <= scan_index;
                    event_valid    <= distance_valid;
                    if distance_thousands /= 0 or distance_hundreds >= 7 then
                        scale_left <= 7;
                    else
                        scale_left <= distance_hundreds;
                    end if;
                end if;

                case current_state is
                    when RESET_LOW_STATE =>
                        if tick_1ms = '1' then
                            current_state <= RESET_WAIT_STATE;
                        end if;

                    when RESET_WAIT_STATE =>
                        if tick_1ms = '1' then
                            current_state <= INIT_STATE;
                        end if;

                    when INIT_STATE =>
                        if writer_busy = '0' then
                            writer_data    <= INIT_COMMANDS(init_index);
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= INIT_WAIT_STATE;
                        end if;

                    when INIT_WAIT_STATE =>
                        if writer_done = '1' then
                            if init_index = 11 then
                                current_state <= IDLE_STATE;
                            else
                                init_index    <= init_index + 1;
                                current_state <= INIT_STATE;
                            end if;
                        end if;

                    when IDLE_STATE =>
                        if self_test_en = '1' then
                            if displayed_mode /= 1 or displayed_blink /= blink_2hz then
                                frame_target_mode <= 1;
                                frame_background  <= '0';
                                frame_fill        <= blink_2hz;
                                point_after_frame <= '0';
                                frame_page        <= 0;
                                frame_col         <= 0;
                                current_state     <= FRAME_PAGE_STATE;
                            end if;
                        elsif standby_en = '1' then
                            if displayed_mode /= 2 then
                                frame_target_mode <= 2;
                                frame_background  <= '1';
                                frame_fill        <= '0';
                                point_after_frame <= '0';
                                frame_page        <= 0;
                                frame_col         <= 0;
                                current_state     <= FRAME_PAGE_STATE;
                            end if;
                        elsif run_en = '1' then
                            if displayed_mode /= 3 then
                                frame_target_mode <= 3;
                                frame_background  <= '1';
                                frame_fill        <= '0';
                                point_after_frame <= '0';
                                frame_page        <= 0;
                                frame_col         <= 0;
                                current_state     <= FRAME_PAGE_STATE;
                            elsif event_pending = '1' then
                                event_pending <= '0';
                                if event_index = 0 then
                                    frame_target_mode <= 3;
                                    frame_background  <= '1';
                                    frame_fill        <= '0';
                                    point_after_frame <= '1';
                                    frame_page        <= 0;
                                    frame_col         <= 0;
                                    current_state     <= FRAME_PAGE_STATE;
                                else
                                    current_state <= START_POINT_STATE;
                                end if;
                            end if;
                        elsif displayed_mode /= 0 then
                            frame_target_mode <= 0;
                            frame_background  <= '0';
                            frame_fill        <= '0';
                            point_after_frame <= '0';
                            frame_page        <= 0;
                            frame_col         <= 0;
                            current_state     <= FRAME_PAGE_STATE;
                        end if;

                    when FRAME_PAGE_STATE =>
                        if writer_busy = '0' then
                            writer_data <= "10110" &
                                           std_logic_vector(to_unsigned(frame_page, 3));
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= FRAME_PAGE_WAIT_STATE;
                        end if;

                    when FRAME_PAGE_WAIT_STATE =>
                        if writer_done = '1' then
                            current_state <= FRAME_COL_HIGH_STATE;
                        end if;

                    when FRAME_COL_HIGH_STATE =>
                        if writer_busy = '0' then
                            writer_data    <= x"10";
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= FRAME_COL_HIGH_WAIT_STATE;
                        end if;

                    when FRAME_COL_HIGH_WAIT_STATE =>
                        if writer_done = '1' then
                            current_state <= FRAME_COL_LOW_STATE;
                        end if;

                    when FRAME_COL_LOW_STATE =>
                        if writer_busy = '0' then
                            writer_data    <= x"00";
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= FRAME_COL_LOW_WAIT_STATE;
                        end if;

                    when FRAME_COL_LOW_WAIT_STATE =>
                        if writer_done = '1' then
                            current_state <= FRAME_PREP_STATE;
                        end if;

                    when FRAME_PREP_STATE =>
                        pattern := (others => '0');
                        if frame_background = '1' then
                            if frame_col >= 64 then dx := frame_col - 64;
                            else dx := 64 - frame_col;
                            end if;
                            if dx <= 60 then
                                pixel_y := outer_y(dx / 2);
                                if frame_page = pixel_y / 8 then
                                    pattern(pixel_y mod 8) := '1';
                                end if;
                            end if;
                            if frame_page = 7 and frame_col >= 4 and
                               frame_col <= 124 then
                                pattern(6) := '1';
                            end if;
                            frame_byte <= pattern;
                        else
                            frame_byte <= (others => frame_fill);
                        end if;
                        current_state <= FRAME_DATA_STATE;

                    when FRAME_DATA_STATE =>
                        if writer_busy = '0' then
                            writer_data    <= frame_byte;
                            writer_is_data <= '1';
                            writer_start   <= '1';
                            current_state  <= FRAME_DATA_WAIT_STATE;
                        end if;

                    when FRAME_DATA_WAIT_STATE =>
                        if writer_done = '1' then
                            if frame_col = 127 then
                                frame_col <= 0;
                                if frame_page = 7 then
                                    current_state <= FRAME_DONE_STATE;
                                else
                                    frame_page    <= frame_page + 1;
                                    current_state <= FRAME_PAGE_STATE;
                                end if;
                            else
                                frame_col     <= frame_col + 1;
                                current_state <= FRAME_PREP_STATE;
                            end if;
                        end if;

                    when FRAME_DONE_STATE =>
                        displayed_mode  <= frame_target_mode;
                        displayed_blink <= frame_fill;
                        if point_after_frame = '1' then
                            point_after_frame <= '0';
                            current_state <= START_POINT_STATE;
                        else
                            current_state <= IDLE_STATE;
                        end if;

                    when START_POINT_STATE =>
                        if event_valid = '0' then current_state <= IDLE_STATE;
                        else
                            coord_x_sum <= 0;
                            coord_y_sum <= 0;
                            current_state <= POINT_SCALE_STATE;
                        end if;

                    when POINT_SCALE_STATE =>
                        coord_x_sum <= coord_x_sum + direction_x(event_index);
                        coord_y_sum <= coord_y_sum + direction_y(event_index);
                        if scale_left = 0 then
                            current_state <= POINT_PREP_STATE;
                        else
                            scale_left <= scale_left - 1;
                        end if;

                    when POINT_PREP_STATE =>
                        delta_x := coord_x_sum / 8;
                        delta_y := coord_y_sum / 8;
                        if event_index <= 18 then target_x := 64 + delta_x;
                        else target_x := 64 - delta_x;
                        end if;
                        target_y := 62 - delta_y;
                        point_page <= target_y / 8;
                        point_base_col <= target_x - 1;
                        point_col <= 0;
                        point_data <= dot_mask(target_y mod 8);
                        current_state <= POINT_PAGE_STATE;

                    when POINT_PAGE_STATE =>
                        if writer_busy = '0' then
                            writer_data <= "10110" &
                                           std_logic_vector(to_unsigned(point_page, 3));
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= POINT_PAGE_WAIT_STATE;
                        end if;

                    when POINT_PAGE_WAIT_STATE =>
                        if writer_done = '1' then
                            current_state <= POINT_COL_HIGH_STATE;
                        end if;

                    when POINT_COL_HIGH_STATE =>
                        if writer_busy = '0' then
                            writer_data <= std_logic_vector(to_unsigned(
                                16 + point_base_col / 16, 8));
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= POINT_COL_HIGH_WAIT_STATE;
                        end if;

                    when POINT_COL_HIGH_WAIT_STATE =>
                        if writer_done = '1' then
                            current_state <= POINT_COL_LOW_STATE;
                        end if;

                    when POINT_COL_LOW_STATE =>
                        if writer_busy = '0' then
                            writer_data <= std_logic_vector(to_unsigned(
                                point_base_col mod 16, 8));
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= POINT_COL_LOW_WAIT_STATE;
                        end if;

                    when POINT_COL_LOW_WAIT_STATE =>
                        if writer_done = '1' then
                            current_state <= POINT_DATA_STATE;
                        end if;

                    when POINT_DATA_STATE =>
                        if writer_busy = '0' then
                            writer_data    <= point_data;
                            writer_is_data <= '1';
                            writer_start   <= '1';
                            current_state  <= POINT_DATA_WAIT_STATE;
                        end if;

                    when POINT_DATA_WAIT_STATE =>
                        if writer_done = '1' then
                            if point_col = 2 then
                                current_state <= IDLE_STATE;
                            else
                                point_col     <= point_col + 1;
                                current_state <= POINT_DATA_STATE;
                            end if;
                        end if;

                    when others =>
                        current_state <= RESET_LOW_STATE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
