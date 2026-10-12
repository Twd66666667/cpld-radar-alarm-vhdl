library ieee;
use ieee.std_logic_1164.all;

entity radar_enhanced_top is
port (
    clk           : in  std_logic;
    sw7           : in  std_logic;
    servo_pwm_out : out std_logic;
    echo_in       : in  std_logic;
    trig_out      : out std_logic;

    led              : out std_logic_vector(15 downto 0);
    buzzer_out       : out std_logic;
    seg              : out std_logic_vector(6 downto 0);
    cat              : out std_logic_vector(7 downto 0);
    matrix_row       : out std_logic_vector(7 downto 0);
    matrix_red_col   : out std_logic_vector(0 to 7);
    matrix_green_col : out std_logic_vector(0 to 7);

    lcd_db        : out std_logic_vector(7 downto 0);
    lcd_a0        : out std_logic;
    lcd_wr_n      : out std_logic;
    lcd_rd_n      : out std_logic;
    lcd_cs_n      : out std_logic;
    lcd_rst_n     : out std_logic
);
end entity radar_enhanced_top;

architecture structural of radar_enhanced_top is

    signal system_rst   : std_logic;
    signal tick_1ms_s   : std_logic;
    signal tick_250ms_s : std_logic;
    signal tick_2s_s    : std_logic;
    signal blink_2hz_s  : std_logic;

    signal self_test_en_s : std_logic;
    signal standby_en_s   : std_logic;
    signal run_en_s       : std_logic;

    signal scan_index_s     : integer range 0 to 36;
    signal angle_100_s      : integer range 0 to 1;
    signal angle_10_s       : integer range 0 to 9;
    signal angle_1_s        : integer range 0 to 9;
    signal pulse_width_us_s : integer range 450 to 2500;
    signal cycle_start_s    : std_logic;
    signal servo_quiet_s    : std_logic;
    signal servo_enable_s   : std_logic;

    signal ultra_start_s  : std_logic;
    signal ultra_busy_s   : std_logic;
    signal ultra_done_s   : std_logic;
    signal ultra_valid_s  : std_logic;
    signal echo_time_us_s : integer range 0 to 30000;

    signal distance_mm_s    : integer range 0 to 4000;
    signal distance_valid_s : std_logic;

    signal filtered_done_s     : std_logic;
    signal filtered_distance_s : integer range 0 to 4000;
    signal filtered_valid_s    : std_logic;

    signal previous_index_s     : integer range 0 to 36 := 0;
    signal angle_changed_s      : std_logic;
    signal current_result_ready_s : std_logic := '0';

    signal distance_1000_s : integer range 0 to 9;
    signal distance_100_s  : integer range 0 to 9;
    signal distance_10_s   : integer range 0 to 9;
    signal distance_1_s    : integer range 0 to 9;
    signal distance_bcd_valid_s : std_logic;
    signal display_distance_valid_s : std_logic;

    signal alarm_level_s : integer range 0 to 4;
    signal alarm_distance_valid_s : std_logic;

    signal lcd_render_page_s : integer range 0 to 7;
    signal lcd_render_col_s  : integer range 0 to 127;
    signal lcd_pixel_byte_s  : std_logic_vector(7 downto 0);

begin

    system_rst <= not sw7;
    servo_enable_s <= standby_en_s or (run_en_s and not servo_quiet_s);

    angle_changed_s <= '1'
        when run_en_s = '1' and scan_index_s /= previous_index_s
        else '0';

    alarm_distance_valid_s <= filtered_valid_s and current_result_ready_s and
                              not angle_changed_s;
    display_distance_valid_s <= distance_bcd_valid_s and
                                current_result_ready_s and
                                not angle_changed_s;

    -- LED and dot matrix are intentionally unused in the enhanced build.
    -- Fixed inactive levels prevent the physical displays from floating.
    led              <= (others => '0');
    matrix_row       <= (others => '1');
    matrix_red_col   <= (others => '0');
    matrix_green_col <= (others => '0');

    process(clk)
    begin
        if rising_edge(clk) then
            if system_rst = '1' or run_en_s = '0' then
                previous_index_s <= scan_index_s;
                current_result_ready_s <= '0';
            else
                previous_index_s <= scan_index_s;
                if scan_index_s /= previous_index_s then
                    current_result_ready_s <= '0';
                elsif filtered_done_s = '1' then
                    current_result_ready_s <= filtered_valid_s;
                end if;
            end if;
        end if;
    end process;

    u_timebase : entity work.timebase
    port map (
        clk        => clk,
        rst        => system_rst,
        tick_1ms   => tick_1ms_s,
        tick_250ms => tick_250ms_s,
        tick_2s    => tick_2s_s,
        blink_2hz  => blink_2hz_s
    );

    u_system_ctrl : entity work.system_ctrl
    port map (
        clk          => clk,
        rst          => system_rst,
        tick_2s      => tick_2s_s,
        self_test_en => self_test_en_s,
        standby_en   => standby_en_s,
        run_en       => run_en_s
    );

    u_scan_ctrl : entity work.enhanced_scan_ctrl
    port map (
        clk            => clk,
        rst            => system_rst,
        run_en         => run_en_s,
        tick_1ms       => tick_1ms_s,
        pulse_width_us => pulse_width_us_s,
        scan_index     => scan_index_s,
        angle_100      => angle_100_s,
        angle_10       => angle_10_s,
        angle_1        => angle_1_s,
        cycle_start    => cycle_start_s
    );

    u_servo_pwm : entity work.enhanced_servo_pwm
    port map (
        clk            => clk,
        rst            => system_rst,
        enable         => servo_enable_s,
        pulse_width_us => pulse_width_us_s,
        pwm_out        => servo_pwm_out
    );

    u_measure_ctrl : entity work.enhanced_measure_ctrl
    port map (
        clk         => clk,
        rst         => system_rst,
        run_en      => run_en_s,
        tick_1ms    => tick_1ms_s,
        cycle_start => cycle_start_s,
        ultra_busy  => ultra_busy_s,
        ultra_done  => ultra_done_s,
        ultra_start => ultra_start_s,
        servo_quiet => servo_quiet_s
    );

    u_ultrasonic : entity work.ultrasonic
    port map (
        clk          => clk,
        rst          => system_rst,
        start        => ultra_start_s,
        echo_in      => echo_in,
        trig_out     => trig_out,
        busy         => ultra_busy_s,
        done         => ultra_done_s,
        valid        => ultra_valid_s,
        echo_time_us => echo_time_us_s
    );

    u_distance_calc : entity work.distance_calc
    port map (
        clk            => clk,
        rst            => system_rst,
        done           => ultra_done_s,
        valid          => ultra_valid_s,
        echo_time_us   => echo_time_us_s,
        distance_mm    => distance_mm_s,
        distance_valid => distance_valid_s
    );

    u_distance_median3 : entity work.distance_median3
    port map (
        clk               => clk,
        rst               => system_rst,
        run_en            => run_en_s,
        sample_done       => ultra_done_s,
        sample_distance   => distance_mm_s,
        sample_valid      => distance_valid_s,
        result_done       => filtered_done_s,
        filtered_distance => filtered_distance_s,
        filtered_valid    => filtered_valid_s
    );

    u_distance_bcd : entity work.distance_bcd
    port map (
        clk            => clk,
        rst            => system_rst,
        clear          => angle_changed_s,
        result_done    => filtered_done_s,
        distance_mm    => filtered_distance_s,
        distance_valid => filtered_valid_s,
        digit_1000     => distance_1000_s,
        digit_100      => distance_100_s,
        digit_10       => distance_10_s,
        digit_1        => distance_1_s,
        bcd_valid      => distance_bcd_valid_s
    );

    u_alarm_led_ctrl : entity work.alarm_led_ctrl
    port map (
        run_en         => run_en_s,
        distance_valid => alarm_distance_valid_s,
        distance_mm    => filtered_distance_s,
        blink_2hz      => blink_2hz_s,
        led_alarm      => open,
        alarm_level    => alarm_level_s
    );

    u_buzzer_ctrl : entity work.buzzer_ctrl
    port map (
        clk         => clk,
        rst         => system_rst,
        run_en      => run_en_s,
        tick_1ms    => tick_1ms_s,
        alarm_level => alarm_level_s,
        buzzer_out  => buzzer_out
    );

    u_seg_display_ctrl : entity work.enhanced_seg_display_ctrl
    port map (
        clk            => clk,
        rst            => system_rst,
        tick_1ms       => tick_1ms_s,
        blink_2hz      => blink_2hz_s,
        self_test_en   => self_test_en_s,
        standby_en     => standby_en_s,
        run_en         => run_en_s,
        angle_100      => angle_100_s,
        angle_10       => angle_10_s,
        angle_1        => angle_1_s,
        distance_1000  => distance_1000_s,
        distance_100   => distance_100_s,
        distance_10    => distance_10_s,
        distance_1     => distance_1_s,
        distance_valid => display_distance_valid_s,
        seg            => seg,
        cat            => cat
    );

    u_lcd_radar_renderer : entity work.enhanced_lcd_renderer
    port map (
        clk          => clk,
        rst          => system_rst,
        self_test_en => self_test_en_s,
        standby_en   => standby_en_s,
        run_en       => run_en_s,
        blink_2hz    => blink_2hz_s,
        scan_index   => scan_index_s,
        result_done  => filtered_done_s,
        distance_mm  => filtered_distance_s,
        distance_valid => filtered_valid_s,
        render_page  => lcd_render_page_s,
        render_col   => lcd_render_col_s,
        pixel_byte   => lcd_pixel_byte_s
    );

    u_lcd12864_ctrl : entity work.lcd12864_ctrl
    port map (
        clk         => clk,
        rst         => system_rst,
        tick_1ms    => tick_1ms_s,
        tick_250ms  => tick_250ms_s,
        pixel_byte  => lcd_pixel_byte_s,
        render_page => lcd_render_page_s,
        render_col  => lcd_render_col_s,
        init_done   => open,
        lcd_db      => lcd_db,
        lcd_a0      => lcd_a0,
        lcd_wr_n    => lcd_wr_n,
        lcd_rd_n    => lcd_rd_n,
        lcd_cs_n    => lcd_cs_n,
        lcd_rst_n   => lcd_rst_n
    );

end architecture structural;
