library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tracking_lcd_ctrl is
port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    tick_1ms     : in  std_logic;
    run_en       : in  std_logic;
    scan_index   : in  integer range 0 to 36;
    target_index : in  integer range 0 to 36;
    target_valid : in  std_logic;
    mode_code    : in  integer range 0 to 2;
    lcd_db       : out std_logic_vector(7 downto 0);
    lcd_a0       : out std_logic;
    lcd_wr_n     : out std_logic;
    lcd_rd_n     : out std_logic;
    lcd_cs_n     : out std_logic;
    lcd_rst_n    : out std_logic
);
end entity tracking_lcd_ctrl;

architecture rtl of tracking_lcd_ctrl is
    type state_type is (
        RESET_LOW_STATE, RESET_WAIT_STATE,
        INIT_STATE, INIT_WAIT_STATE, IDLE_STATE,
        PAGE_STATE, PAGE_WAIT_STATE,
        COL_HIGH_STATE, COL_HIGH_WAIT_STATE,
        COL_LOW_STATE, COL_LOW_WAIT_STATE,
        DATA_STATE, DATA_WAIT_STATE, FRAME_DONE_STATE
    );
    signal current_state : state_type := RESET_LOW_STATE;

    type command_array_type is array (0 to 11) of
        std_logic_vector(7 downto 0);
    constant INIT_COMMANDS : command_array_type := (
        x"AE", x"A0", x"C8", x"A2", x"2F", x"24",
        x"81", x"18", x"40", x"A6", x"A4", x"AF"
    );
    signal init_index : integer range 0 to 11 := 0;

    signal writer_start   : std_logic := '0';
    signal writer_is_data : std_logic := '0';
    signal writer_data    : std_logic_vector(7 downto 0) := (others => '0');
    signal writer_busy    : std_logic;
    signal writer_done    : std_logic;

    signal page_index       : integer range 0 to 7 := 0;
    signal column_index     : integer range 0 to 127 := 0;
    signal frame_mode       : integer range 0 to 3 := 3;
    signal frame_scan       : integer range 0 to 36 := 0;
    signal frame_target     : integer range 0 to 36 := 0;
    signal frame_target_ok  : std_logic := '0';
    signal frame_valid      : std_logic := '0';

    -- Only the letters in SCAN, LOCK and LOST are stored.
    function glyph(letter_value : integer; glyph_col : integer)
        return std_logic_vector is
    begin
        case letter_value is
            when 0 => -- S
                case glyph_col is
                    when 0 => return x"46";
                    when 1 | 2 | 3 => return x"49";
                    when others => return x"31";
                end case;
            when 1 => -- C
                case glyph_col is
                    when 0 => return x"3E";
                    when 1 | 2 | 3 => return x"41";
                    when others => return x"22";
                end case;
            when 2 => -- A
                if glyph_col = 0 or glyph_col = 4 then
                    return x"7E";
                else
                    return x"11";
                end if;
            when 3 => -- N
                case glyph_col is
                    when 0 | 4 => return x"7F";
                    when 1 => return x"02";
                    when 2 => return x"04";
                    when others => return x"08";
                end case;
            when 4 => -- L
                if glyph_col = 0 then return x"7F";
                else return x"40"; end if;
            when 5 => -- O
                if glyph_col = 0 or glyph_col = 4 then
                    return x"3E";
                else
                    return x"41";
                end if;
            when 6 => -- K
                case glyph_col is
                    when 0 => return x"7F";
                    when 1 => return x"08";
                    when 2 => return x"14";
                    when 3 => return x"22";
                    when others => return x"41";
                end case;
            when others => -- T
                if glyph_col = 2 then return x"7F";
                else return x"01"; end if;
        end case;
    end function;

    function render_byte(
        page_value   : integer;
        col_value    : integer;
        mode_value   : integer;
        scan_value   : integer;
        target_value : integer;
        target_ok    : std_logic
    ) return std_logic_vector is
        variable char_number : integer range 0 to 3;
        variable char_col    : integer range 0 to 5;
        variable letter      : integer range 0 to 7;
        variable marker_x    : integer range 8 to 116;
    begin
        if mode_value = 3 then
            return x"00";
        elsif page_value = 0 and col_value >= 8 and col_value < 32 then
            if col_value <= 12 then
                char_number := 0;
                char_col := col_value - 8;
            elsif col_value >= 14 and col_value <= 18 then
                char_number := 1;
                char_col := col_value - 14;
            elsif col_value >= 20 and col_value <= 24 then
                char_number := 2;
                char_col := col_value - 20;
            elsif col_value >= 26 and col_value <= 30 then
                char_number := 3;
                char_col := col_value - 26;
            else
                return x"00";
            end if;
            if mode_value = 0 then
                case char_number is
                    when 0 => letter := 0; -- S
                    when 1 => letter := 1; -- C
                    when 2 => letter := 2; -- A
                    when others => letter := 3; -- N
                end case;
            elsif mode_value = 1 then
                case char_number is
                    when 0 => letter := 4; -- L
                    when 1 => letter := 5; -- O
                    when 2 => letter := 1; -- C
                    when others => letter := 6; -- K
                end case;
            else
                case char_number is
                    when 0 => letter := 4; -- L
                    when 1 => letter := 5; -- O
                    when 2 => letter := 0; -- S
                    when others => letter := 7; -- T
                end case;
            end if;
            return glyph(letter, char_col);
        elsif page_value = 5 and col_value >= 8 and col_value <= 116 then
            if col_value = 8 or col_value = 62 or col_value = 116 then
                return x"1C";
            else
                return x"08";
            end if;
        elsif page_value = 6 then
            -- Match the enhanced radar view: 0 degrees is on the right.
            marker_x := 116 - 3 * scan_value;
            if col_value >= marker_x - 1 and col_value <= marker_x + 1 then
                return x"0E";
            end if;
        elsif page_value = 7 and target_ok = '1' then
            marker_x := 116 - 3 * target_value;
            if col_value >= marker_x - 1 and col_value <= marker_x + 1 then
                return x"1C";
            end if;
        end if;
        return x"00";
    end function;
begin
    lcd_rst_n <= '0' when current_state = RESET_LOW_STATE else '1';

    u_writer : entity work.lcd_bus_writer
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
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state    <= RESET_LOW_STATE;
                init_index       <= 0;
                writer_start     <= '0';
                writer_is_data   <= '0';
                writer_data      <= (others => '0');
                page_index       <= 0;
                column_index     <= 0;
                frame_mode       <= 3;
                frame_scan       <= 0;
                frame_target     <= 0;
                frame_target_ok  <= '0';
                frame_valid      <= '0';
            else
                writer_start <= '0';
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
                                init_index <= init_index + 1;
                                current_state <= INIT_STATE;
                            end if;
                        end if;
                    when IDLE_STATE =>
                        if run_en = '0' then
                            if frame_valid = '0' or frame_mode /= 3 then
                                frame_mode <= 3;
                                page_index <= 0;
                                column_index <= 0;
                                current_state <= PAGE_STATE;
                            end if;
                        elsif frame_valid = '0' or frame_mode /= mode_code or
                              frame_scan /= scan_index or
                              frame_target /= target_index or
                              frame_target_ok /= target_valid then
                            frame_mode      <= mode_code;
                            frame_scan      <= scan_index;
                            frame_target    <= target_index;
                            frame_target_ok <= target_valid;
                            page_index      <= 0;
                            column_index    <= 0;
                            current_state   <= PAGE_STATE;
                        end if;
                    when PAGE_STATE =>
                        if writer_busy = '0' then
                            writer_data <= "10110" &
                                std_logic_vector(to_unsigned(page_index, 3));
                            writer_is_data <= '0';
                            writer_start <= '1';
                            current_state <= PAGE_WAIT_STATE;
                        end if;
                    when PAGE_WAIT_STATE =>
                        if writer_done = '1' then current_state <= COL_HIGH_STATE; end if;
                    when COL_HIGH_STATE =>
                        if writer_busy = '0' then
                            writer_data <= x"10";
                            writer_is_data <= '0';
                            writer_start <= '1';
                            current_state <= COL_HIGH_WAIT_STATE;
                        end if;
                    when COL_HIGH_WAIT_STATE =>
                        if writer_done = '1' then current_state <= COL_LOW_STATE; end if;
                    when COL_LOW_STATE =>
                        if writer_busy = '0' then
                            writer_data <= x"00";
                            writer_is_data <= '0';
                            writer_start <= '1';
                            current_state <= COL_LOW_WAIT_STATE;
                        end if;
                    when COL_LOW_WAIT_STATE =>
                        if writer_done = '1' then current_state <= DATA_STATE; end if;
                    when DATA_STATE =>
                        if writer_busy = '0' then
                            writer_data <= render_byte(
                                page_index, column_index, frame_mode,
                                frame_scan, frame_target, frame_target_ok);
                            writer_is_data <= '1';
                            writer_start <= '1';
                            current_state <= DATA_WAIT_STATE;
                        end if;
                    when DATA_WAIT_STATE =>
                        if writer_done = '1' then
                            if column_index = 127 then
                                column_index <= 0;
                                if page_index = 7 then
                                    current_state <= FRAME_DONE_STATE;
                                else
                                    page_index <= page_index + 1;
                                    current_state <= PAGE_STATE;
                                end if;
                            else
                                column_index <= column_index + 1;
                                current_state <= DATA_STATE;
                            end if;
                        end if;
                    when FRAME_DONE_STATE =>
                        frame_valid      <= '1';
                        current_state    <= IDLE_STATE;
                    when others => current_state <= RESET_LOW_STATE;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
