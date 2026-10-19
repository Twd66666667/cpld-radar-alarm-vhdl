library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Simulation-only integration wrapper.  Timebase pulses are supplied by the
-- VWF so the long 2 s / 250 ms / 1 ms waits can be compressed while all
-- control, ultrasonic, conversion, filtering and alarm RTL stays unchanged.
entity basic_flow_vwf_top is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        tick_1ms     : in  std_logic;
        tick_250ms   : in  std_logic;
        tick_2s      : in  std_logic;
        blink_2hz    : in  std_logic;

        self_test_en : out std_logic;
        standby_en   : out std_logic;
        run_en       : out std_logic;
        angle_deg_u8 : out std_logic_vector(7 downto 0);
        servo_enable : out std_logic;
        servo_quiet  : out std_logic;
        servo_pwm    : out std_logic;
        echo_in_mon  : out std_logic;
        trig_out     : out std_logic;
        ultra_done   : out std_logic;
        result_done  : out std_logic;
        distance_u12 : out std_logic_vector(11 downto 0);
        result_valid : out std_logic;
        alarm_u3     : out std_logic_vector(2 downto 0);
        led_alarm    : out std_logic_vector(15 downto 0);
        buzzer_out   : out std_logic
    );
end entity basic_flow_vwf_top;

architecture structural of basic_flow_vwf_top is
    type echo_state_type is (ECHO_IDLE, WAIT_TRIG_END, ECHO_DELAY, ECHO_HIGH);

    signal self_test_s : std_logic;
    signal standby_s   : std_logic;
    signal run_s       : std_logic;
    signal angle_s     : integer range 0 to 180;
    signal quiet_s     : std_logic;
    signal servo_en_s  : std_logic;
    signal servo_pwm_s : std_logic;

    signal start_s       : std_logic;
    signal trig_s        : std_logic;
    signal ultra_busy_s  : std_logic;
    signal ultra_done_s  : std_logic;
    signal ultra_valid_s : std_logic;
    signal echo_time_s   : integer range 0 to 30000;
    signal echo_in_s     : std_logic := '0';

    signal sample_distance_s : integer range 0 to 4000;
    signal sample_valid_s    : std_logic;
    signal result_done_s     : std_logic;
    signal result_distance_s : integer range 0 to 4000;
    signal result_valid_s    : std_logic;
    signal alarm_level_s     : integer range 0 to 4;
    signal led_s             : std_logic_vector(15 downto 0);
    signal buzzer_s          : std_logic;

    signal echo_state : echo_state_type := ECHO_IDLE;
    signal echo_count : integer range 0 to 1100 := 0;
begin
    servo_en_s <= (standby_s or run_s) and not quiet_s;

    u_system_ctrl : entity work.system_ctrl
        port map (
            clk          => clk,
            rst          => rst,
            tick_2s      => tick_2s,
            self_test_en => self_test_s,
            standby_en   => standby_s,
            run_en       => run_s
        );

    u_scan_ctrl : entity work.scan_ctrl
        port map (
            clk       => clk,
            rst       => rst,
            run_en    => run_s,
            tick_2s   => tick_2s,
            angle_deg => angle_s
        );

    u_servo_pwm : entity work.servo_pwm
        port map (
            clk       => clk,
            rst       => rst,
            enable    => servo_en_s,
            angle_deg => angle_s,
            pwm_out   => servo_pwm_s
        );

    u_measure_ctrl : entity work.measure_ctrl
        port map (
            clk         => clk,
            rst         => rst,
            tick_1ms    => tick_1ms,
            run_en      => run_s,
            tick_250ms  => tick_250ms,
            tick_2s     => tick_2s,
            ultra_busy  => ultra_busy_s,
            ultra_done  => ultra_done_s,
            ultra_start => start_s,
            servo_quiet => quiet_s
        );

    u_ultrasonic : entity work.ultrasonic
        port map (
            clk          => clk,
            rst          => rst,
            start        => start_s,
            echo_in      => echo_in_s,
            trig_out     => trig_s,
            busy         => ultra_busy_s,
            done         => ultra_done_s,
            valid        => ultra_valid_s,
            echo_time_us => echo_time_s
        );

    u_distance_calc : entity work.distance_calc
        port map (
            clk            => clk,
            rst            => rst,
            done           => ultra_done_s,
            valid          => ultra_valid_s,
            echo_time_us   => echo_time_s,
            distance_mm    => sample_distance_s,
            distance_valid => sample_valid_s
        );

    u_distance_median3 : entity work.distance_median3
        port map (
            clk               => clk,
            rst               => rst,
            run_en            => run_s,
            sample_done       => ultra_done_s,
            sample_distance   => sample_distance_s,
            sample_valid      => sample_valid_s,
            result_done       => result_done_s,
            filtered_distance => result_distance_s,
            filtered_valid    => result_valid_s
        );

    u_alarm_led_ctrl : entity work.alarm_led_ctrl
        port map (
            run_en         => run_s,
            distance_valid => result_valid_s,
            distance_mm    => result_distance_s,
            blink_2hz      => blink_2hz,
            led_alarm      => led_s,
            alarm_level    => alarm_level_s
        );

    u_buzzer_ctrl : entity work.buzzer_ctrl
        port map (
            clk         => clk,
            rst         => rst,
            run_en      => run_s,
            tick_1ms    => tick_1ms,
            alarm_level => alarm_level_s,
            buzzer_out  => buzzer_s
        );

    -- Simulation echo source: each trigger is answered after 8 us with a
    -- 1000 us ECHO pulse.  The real ultrasonic RTL therefore measures about
    -- 184 mm after the calibrated conversion, which selects alarm level 4.
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                echo_state <= ECHO_IDLE;
                echo_count <= 0;
                echo_in_s  <= '0';
            else
                case echo_state is
                    when ECHO_IDLE =>
                        echo_in_s <= '0';
                        if trig_s = '1' then
                            echo_state <= WAIT_TRIG_END;
                        end if;

                    when WAIT_TRIG_END =>
                        if trig_s = '0' then
                            echo_count <= 0;
                            echo_state <= ECHO_DELAY;
                        end if;

                    when ECHO_DELAY =>
                        if echo_count = 7 then
                            echo_count <= 0;
                            echo_in_s  <= '1';
                            echo_state <= ECHO_HIGH;
                        else
                            echo_count <= echo_count + 1;
                        end if;

                    when ECHO_HIGH =>
                        if echo_count = 999 then
                            echo_count <= 0;
                            echo_in_s  <= '0';
                            echo_state <= ECHO_IDLE;
                        else
                            echo_count <= echo_count + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    self_test_en <= self_test_s;
    standby_en   <= standby_s;
    run_en       <= run_s;
    angle_deg_u8 <= std_logic_vector(to_unsigned(angle_s, 8));
    servo_enable <= servo_en_s;
    servo_quiet  <= quiet_s;
    servo_pwm    <= servo_pwm_s;
    echo_in_mon  <= echo_in_s;
    trig_out     <= trig_s;
    ultra_done   <= ultra_done_s;
    result_done  <= result_done_s;
    distance_u12 <= std_logic_vector(to_unsigned(result_distance_s, 12));
    result_valid <= result_valid_s;
    alarm_u3     <= std_logic_vector(to_unsigned(alarm_level_s, 3));
    led_alarm    <= led_s;
    buzzer_out   <= buzzer_s;
end architecture structural;
