library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity enhanced_lcd_radar_ctrl is
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
    distance_mm    : in  integer range 0 to 4000;
    distance_valid : in  std_logic;

    lcd_db         : out std_logic_vector(7 downto 0);
    lcd_a0         : out std_logic;
    lcd_wr_n       : out std_logic;
    lcd_rd_n       : out std_logic;
    lcd_cs_n       : out std_logic;
    lcd_rst_n      : out std_logic
);
end entity enhanced_lcd_radar_ctrl;

architecture rtl of enhanced_lcd_radar_ctrl is
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
        FRAME_BG_INIT_STATE,
        FRAME_BG_SQUARE_X_STATE,
        FRAME_BG_SQUARE_Y_STATE,
        FRAME_BG_CHECK_STATE,
        FRAME_DATA_STATE,
        FRAME_DATA_WAIT_STATE,
        FRAME_DONE_STATE,
        START_POINT_STATE,
        QUANTIZE_STATE,
        COORD_INIT_STATE,
        COORD_ACCUM_STATE,
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
    signal event_distance : integer range 0 to 4000 := 0;
    signal event_valid    : std_logic := '0';

    signal displayed_mode  : integer range 0 to 3 := 0;
    signal displayed_blink : std_logic := '0';
    signal frame_target_mode : integer range 0 to 3 := 0;
    signal frame_background  : std_logic := '1';
    signal frame_fill        : std_logic := '0';
    signal point_after_frame : std_logic := '0';

    signal frame_page : integer range 0 to 7 := 0;
    signal frame_col  : integer range 0 to 127 := 0;
    signal bg_bit     : integer range 0 to 7 := 0;
    signal frame_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal square_count : integer range 0 to 64 := 0;
    signal square_odd   : integer range 1 to 129 := 1;
    signal square_sum   : integer range 0 to 8192 := 0;

    signal quantize_remaining : integer range 0 to 799 := 0;
    signal quantize_level     : integer range 0 to 39 := 0;
    signal point_radius       : integer range 1 to 60 := 1;
    signal radius_step        : integer range 0 to 60 := 0;
    signal accum_x            : integer range 0 to 3840 := 0;
    signal accum_y            : integer range 0 to 3840 := 0;

    signal point_page     : integer range 0 to 7 := 0;
    signal point_base_col : integer range 0 to 125 := 0;
    signal point_col      : integer range 0 to 2 := 0;
    signal point_data     : std_logic_vector(7 downto 0) := (others => '0');

    function direction_x(index_value : integer) return integer is
    begin
        case index_value is
            when 0 | 1 | 35 | 36 => return 64;
            when 2 | 34          => return 63;
            when 3 | 33          => return 62;
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
            when 15 | 21         => return 62;
            when 16 | 20         => return 63;
            when 17 | 18 | 19    => return 64;
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
        variable dx           : integer range 0 to 64;
        variable dy           : integer range 0 to 62;
        variable level_value  : integer range 1 to 40;
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
                event_distance      <= 0;
                event_valid         <= '0';
                displayed_mode      <= 0;
                displayed_blink     <= '0';
                frame_target_mode   <= 0;
                frame_background    <= '1';
                frame_fill          <= '0';
                point_after_frame   <= '0';
                frame_page          <= 0;
                frame_col           <= 0;
                bg_bit              <= 0;
                frame_byte          <= (others => '0');
                square_count        <= 0;
                square_odd          <= 1;
                square_sum          <= 0;
                quantize_remaining  <= 0;
                quantize_level      <= 0;
                point_radius        <= 1;
                radius_step         <= 0;
                accum_x             <= 0;
                accum_y             <= 0;
                point_page          <= 0;
                point_base_col      <= 0;
                point_col           <= 0;
                point_data          <= (others => '0');
            else
                writer_start <= '0';

                if result_done = '1' and run_en = '1' then
                    event_pending  <= '1';
                    event_index    <= scan_index;
                    event_distance <= distance_mm;
                    event_valid    <= distance_valid;
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
                        if frame_background = '1' then
                            frame_byte   <= (others => '0');
                            bg_bit       <= 0;
                            current_state <= FRAME_BG_INIT_STATE;
                        else
                            frame_byte   <= (others => frame_fill);
                            current_state <= FRAME_DATA_STATE;
                        end if;

                    when FRAME_BG_INIT_STATE =>
                        square_count <= 0;
                        square_odd   <= 1;
                        square_sum   <= 0;
                        current_state <= FRAME_BG_SQUARE_X_STATE;

                    when FRAME_BG_SQUARE_X_STATE =>
                        if frame_col >= 64 then
                            dx := frame_col - 64;
                        else
                            dx := 64 - frame_col;
                        end if;

                        if square_count < dx then
                            square_sum   <= square_sum + square_odd;
                            square_count <= square_count + 1;
                            square_odd   <= square_odd + 2;
                        else
                            square_count <= 0;
                            square_odd   <= 1;
                            current_state <= FRAME_BG_SQUARE_Y_STATE;
                        end if;

                    when FRAME_BG_SQUARE_Y_STATE =>
                        pixel_y := frame_page * 8 + bg_bit;
                        if pixel_y <= 62 then
                            dy := 62 - pixel_y;
                            if square_count < dy then
                                square_sum   <= square_sum + square_odd;
                                square_count <= square_count + 1;
                                square_odd   <= square_odd + 2;
                            else
                                current_state <= FRAME_BG_CHECK_STATE;
                            end if;
                        else
                            current_state <= FRAME_BG_CHECK_STATE;
                        end if;

                    when FRAME_BG_CHECK_STATE =>
                        pixel_y := frame_page * 8 + bg_bit;

                        -- A tolerance of one radius unit produces a continuous
                        -- one-pixel circle after the integer pixel rounding.
                        if (pixel_y = 62 and frame_col >= 4 and frame_col <= 124) or
                           (square_sum >= 210  and square_sum <= 240) or
                           (square_sum >= 870  and square_sum <= 930) or
                           (square_sum >= 1980 and square_sum <= 2070) or
                           (square_sum >= 3540 and square_sum <= 3660) then
                            frame_byte(bg_bit) <= '1';
                        end if;

                        if bg_bit = 7 then
                            current_state <= FRAME_DATA_STATE;
                        else
                            bg_bit        <= bg_bit + 1;
                            current_state <= FRAME_BG_INIT_STATE;
                        end if;

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
                        if event_valid = '0' then
                            current_state <= IDLE_STATE;
                        elsif event_distance >= 800 then
                            point_radius  <= 60;
                            current_state <= COORD_INIT_STATE;
                        else
                            quantize_remaining <= event_distance;
                            quantize_level     <= 0;
                            current_state      <= QUANTIZE_STATE;
                        end if;

                    when QUANTIZE_STATE =>
                        if quantize_remaining >= 20 and quantize_level < 39 then
                            quantize_remaining <= quantize_remaining - 20;
                            quantize_level     <= quantize_level + 1;
                        else
                            if quantize_level = 0 then
                                level_value := 1;
                            else
                                level_value := quantize_level;
                            end if;
                            point_radius  <= level_value + level_value / 2;
                            current_state <= COORD_INIT_STATE;
                        end if;

                    when COORD_INIT_STATE =>
                        radius_step  <= 0;
                        accum_x      <= 0;
                        accum_y      <= 0;
                        current_state <= COORD_ACCUM_STATE;

                    when COORD_ACCUM_STATE =>
                        accum_x <= accum_x + direction_x(event_index);
                        accum_y <= accum_y + direction_y(event_index);
                        if radius_step + 1 >= point_radius then
                            current_state <= POINT_PREP_STATE;
                        else
                            radius_step <= radius_step + 1;
                        end if;

                    when POINT_PREP_STATE =>
                        delta_x := accum_x / 64;
                        delta_y := accum_y / 64;
                        if event_index <= 18 then
                            target_x := 64 + delta_x;
                        else
                            target_x := 64 - delta_x;
                        end if;
                        target_y := 62 - delta_y;

                        point_page     <= target_y / 8;
                        point_base_col <= target_x - 1;
                        point_col      <= 0;
                        point_data     <= dot_mask(target_y mod 8);
                        current_state  <= POINT_PAGE_STATE;

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
