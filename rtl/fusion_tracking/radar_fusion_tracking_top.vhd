library ieee;
use ieee.std_logic_1164.all;

entity radar_fusion_tracking_top is
port (
    clk : in std_logic;
    sw7 : in std_logic;
    sw6 : in std_logic;
    sw5 : in std_logic;
    echo_in : in std_logic;
    trig_out : out std_logic;
    servo_pwm_out : out std_logic;
    led : out std_logic_vector(15 downto 0);
    buzzer_out : out std_logic;
    seg : out std_logic_vector(6 downto 0);
    cat : out std_logic_vector(7 downto 0);
    matrix_row : out std_logic_vector(7 downto 0);
    matrix_red_col : out std_logic_vector(0 to 7);
    matrix_green_col : out std_logic_vector(0 to 7);
    lcd_db : out std_logic_vector(7 downto 0);
    lcd_a0 : out std_logic;
    lcd_wr_n : out std_logic;
    lcd_rd_n : out std_logic;
    lcd_cs_n : out std_logic;
    lcd_rst_n : out std_logic
);
end entity;

architecture structural of radar_fusion_tracking_top is
    signal system_rst, tick_1ms_s, tick_2s_s, blink_2hz_s : std_logic;
    signal self_test_s, standby_s, run_s : std_logic;
    signal basic_run_s, enhanced_run_s, normal_run_s, tracking_run_s : std_logic;
    signal sw_meta, sw_sync, mode_reg : std_logic := '0';
    signal sw5_meta, sw5_sync, track_reg, tracking_active : std_logic := '0';
    signal mode_stable_ms : integer range 0 to 19 := 0;
    signal reset_hold : integer range 0 to 3 := 0;

    signal basic_angle : integer range 0 to 180;
    signal scan_index : integer range 0 to 36;
    signal normal_index, tracking_index : integer range 0 to 36;
    signal index_last : integer range 0 to 36 := 0;
    signal angle_100 : integer range 0 to 1;
    signal angle_10, angle_1 : integer range 0 to 9;
    signal pwm_width : integer range 450 to 2500;
    signal cycle_start : std_logic;
    signal normal_cycle, tracking_cycle : std_logic;
    signal ultra_start_s, servo_quiet, servo_enable : std_logic;
    signal angle_changed, result_ready : std_logic := '0';
    signal ultra_busy, ultra_done, ultra_valid : std_logic;
    signal echo_us : integer range 0 to 30000;
    signal distance_mm : integer range 0 to 4000;
    signal distance_valid : std_logic;
    signal result_done, filtered_valid : std_logic;
    signal filtered_mm : integer range 0 to 4000;
    signal d1000, d100, d10, d1 : integer range 0 to 9;
    signal bcd_valid, bcd_done, shown_valid : std_logic;
    signal level_0, level_45, level_90, level_135, level_180 : integer range 0 to 5;
    signal current_level : integer range 0 to 5;
    signal alarm_led : std_logic_vector(15 downto 0);
    signal alarm_level : integer range 0 to 4;
    signal alarm_valid, basic_buzzer : std_logic;
    signal basic_matrix_row : std_logic_vector(7 downto 0);
    signal basic_matrix_red, basic_matrix_green : std_logic_vector(0 to 7);
begin
    -- SW6 is sampled through two flip-flops and accepted after 20 equal ms samples.
    -- A change restarts both modes, flushing the previous angle's echo and display data.
    system_rst <= '1' when sw7 = '0' or reset_hold /= 0 else '0';
    process(clk)
    begin
        if rising_edge(clk) then
            sw_meta <= sw6;
            sw_sync <= sw_meta;
            sw5_meta <= sw5;
            sw5_sync <= sw5_meta;
            if sw7 = '0' then
                mode_reg <= sw_sync;
                track_reg <= sw5_sync;
                mode_stable_ms <= 0;
                reset_hold <= 3;
            else
                if reset_hold /= 0 then reset_hold <= reset_hold - 1; end if;
                if tick_1ms_s = '1' then
                    if sw_sync = mode_reg and sw5_sync = track_reg then
                        mode_stable_ms <= 0;
                    elsif mode_stable_ms = 19 then
                        mode_reg <= sw_sync;
                        track_reg <= sw5_sync;
                        mode_stable_ms <= 0;
                        reset_hold <= 3;
                    else
                        mode_stable_ms <= mode_stable_ms + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    basic_run_s <= run_s and not mode_reg;
    enhanced_run_s <= run_s and mode_reg;
    tracking_active <= mode_reg and track_reg;
    normal_run_s <= run_s and not tracking_active;
    tracking_run_s <= run_s and tracking_active;
    scan_index <= tracking_index when tracking_active = '1' else normal_index;
    cycle_start <= tracking_cycle when tracking_active = '1' else normal_cycle;
    servo_enable <= standby_s or (run_s and not servo_quiet);

    angle_changed <= '1' when run_s = '1' and scan_index /= index_last else '0';
    shown_valid <= bcd_valid and result_ready and not angle_changed;
    alarm_valid <= filtered_valid and result_ready and not angle_changed;

    process(clk)
    begin
        if rising_edge(clk) then
            index_last <= scan_index;
            if system_rst = '1' or run_s = '0' then
                result_ready <= '0';
            elsif angle_changed = '1' then
                result_ready <= '0';
            elsif result_done = '1' then
                result_ready <= filtered_valid;
            end if;
        end if;
    end process;

    u_timebase : entity work.timebase port map (
        clk => clk, rst => system_rst, tick_1ms => tick_1ms_s,
        tick_250ms => open, tick_2s => tick_2s_s,
        blink_2hz => blink_2hz_s);
    u_system : entity work.system_ctrl port map (
        clk => clk, rst => system_rst, tick_2s => tick_2s_s,
        self_test_en => self_test_s, standby_en => standby_s, run_en => run_s);
    u_scan : entity work.shared_scan_ctrl port map (
        clk => clk, rst => system_rst, run_en => normal_run_s,
        enhanced_mode => mode_reg, tick_1ms => tick_1ms_s,
        tick_2s => tick_2s_s,
        scan_index => normal_index, basic_angle_deg => basic_angle,
        cycle_start => normal_cycle);
    u_tracker : entity work.target_tracker_ctrl port map (
        clk => clk, rst => system_rst, run_en => tracking_run_s,
        tick_1ms => tick_1ms_s, result_done => result_done,
        result_valid => filtered_valid, distance_mm => filtered_mm,
        scan_index => tracking_index, target_index => open,
        target_valid => open, mode_code => open,
        cycle_start => tracking_cycle);
    u_servo_map : entity work.tracking_servo_map port map (
        scan_index => scan_index, pulse_width_us => pwm_width,
        angle_100 => angle_100, angle_10 => angle_10,
        angle_1 => angle_1);
    u_servo : entity work.enhanced_servo_pwm port map (
        clk => clk, rst => system_rst, enable => servo_enable,
        pulse_width_us => pwm_width, pwm_out => servo_pwm_out);
    u_measure : entity work.fusion_measure_ctrl port map (
        clk => clk, rst => system_rst, run_en => run_s,
        enhanced_mode => mode_reg, tick_1ms => tick_1ms_s,
        cycle_start => cycle_start, ultra_busy => ultra_busy,
        ultra_done => ultra_done, ultra_start => ultra_start_s,
        servo_quiet => servo_quiet);
    u_ultrasonic : entity work.ultrasonic port map (
        clk => clk, rst => system_rst, start => ultra_start_s,
        echo_in => echo_in, trig_out => trig_out, busy => ultra_busy,
        done => ultra_done, valid => ultra_valid, echo_time_us => echo_us);
    u_calc : entity work.distance_calc port map (
        clk => clk, rst => system_rst, done => ultra_done,
        valid => ultra_valid, echo_time_us => echo_us,
        distance_mm => distance_mm, distance_valid => distance_valid);
    u_filter : entity work.distance_median3 port map (
        clk => clk, rst => system_rst, run_en => run_s,
        sample_done => ultra_done, sample_distance => distance_mm,
        sample_valid => distance_valid, result_done => result_done,
        filtered_distance => filtered_mm, filtered_valid => filtered_valid);
    u_bcd : entity work.fusion_distance_bcd port map (
        clk => clk, rst => system_rst, clear => angle_changed,
        result_done => result_done, distance_mm => filtered_mm,
        distance_valid => filtered_valid, digit_1000 => d1000,
        digit_100 => d100, digit_10 => d10, digit_1 => d1,
        bcd_valid => bcd_valid, digit_done => bcd_done);
    u_seg : entity work.enhanced_seg_display_ctrl port map (
        clk => clk, rst => system_rst, tick_1ms => tick_1ms_s,
        blink_2hz => blink_2hz_s, self_test_en => self_test_s,
        standby_en => standby_s, run_en => run_s,
        angle_100 => angle_100,
        angle_10 => angle_10,
        angle_1 => angle_1,
        distance_1000 => d1000, distance_100 => d100,
        distance_10 => d10, distance_1 => d1,
        distance_valid => shown_valid, seg => seg, cat => cat);
    u_levels : entity work.fusion_levels port map (
        clk => clk, rst => system_rst, run_en => basic_run_s,
        result_done => result_done, angle_deg => basic_angle,
        distance_mm => filtered_mm, distance_valid => filtered_valid,
        current_level => current_level,
        level_0 => level_0, level_45 => level_45, level_90 => level_90,
        level_135 => level_135, level_180 => level_180);
    u_matrix : entity work.fusion_matrix port map (
        clk => clk, rst => system_rst, tick_1ms => tick_1ms_s,
        blink_2hz => blink_2hz_s, self_test_en => self_test_s,
        standby_en => standby_s, run_en => basic_run_s,
        angle_deg => basic_angle,
        level_0 => level_0, level_45 => level_45,
        level_90 => level_90, level_135 => level_135,
        level_180 => level_180, matrix_row => basic_matrix_row,
        matrix_red_col => basic_matrix_red,
        matrix_green_col => basic_matrix_green);
    u_alarm : entity work.fusion_alarm port map (
        run_en => run_s, distance_valid => alarm_valid,
        level => current_level, blink_2hz => blink_2hz_s,
        led_alarm => alarm_led, alarm_level => alarm_level);
    u_buzzer : entity work.buzzer_ctrl port map (
        clk => clk, rst => system_rst, run_en => basic_run_s,
        tick_1ms => tick_1ms_s, alarm_level => alarm_level,
        buzzer_out => basic_buzzer);
    u_lcd : entity work.compact_lcd_radar_ctrl port map (
        clk => clk, rst => system_rst, tick_1ms => tick_1ms_s,
        self_test_en => self_test_s and mode_reg,
        standby_en => standby_s and mode_reg,
        run_en => enhanced_run_s, tracking_mode => tracking_active,
        blink_2hz => blink_2hz_s,
        scan_index => scan_index, result_done => bcd_done and mode_reg,
        distance_hundreds => d100, distance_thousands => d1000,
        distance_valid => filtered_valid,
        lcd_db => lcd_db, lcd_a0 => lcd_a0, lcd_wr_n => lcd_wr_n,
        lcd_rd_n => lcd_rd_n, lcd_cs_n => lcd_cs_n, lcd_rst_n => lcd_rst_n);

    led <= (others => blink_2hz_s) when self_test_s = '1' else
           alarm_led when run_s = '1' else (others => '0');
    buzzer_out <= basic_buzzer when mode_reg = '0' else '0';
    matrix_row <= basic_matrix_row when mode_reg = '0' else (others => '1');
    matrix_red_col <= basic_matrix_red when mode_reg = '0' else (others => '0');
    matrix_green_col <= basic_matrix_green when mode_reg = '0' else (others => '0');
end architecture;
