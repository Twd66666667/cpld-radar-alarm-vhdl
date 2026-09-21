library ieee;
use ieee.std_logic_1164.all;

entity radar_top is
	port (
		clk : in std_logic;
		sw7 : in std_logic;
		led : out std_logic_vector(15 downto 0);
		servo_pwm_out :out std_logic;
		echo_in  :in std_logic;
		trig_out  :out std_logic

	);
end entity radar_top;

architecture structural of radar_top is

	signal system_rst  : std_logic;
	signal tick_1ms_s    : std_logic;
	signal tick_250ms_s  : std_logic;
	signal tick_2s_s     : std_logic;
	signal blink_2hz_s   : std_logic;

	signal self_test_en_s : std_logic;
	signal standby_en_s   : std_logic;
	signal run_en_s       : std_logic;

	signal angle_deg_s : integer range 0 to 180;

	signal servo_enable_s : std_logic;

	signal ultra_start_s   : std_logic;
	signal ultra_busy_s    : std_logic;
	signal ultra_done_s    : std_logic;
	signal ultra_valid_s   : std_logic;
	signal echo_time_us_s  : integer range 0 to 30000;

	signal distance_mm_s    : integer range 0 to 4000;
	signal distance_valid_s : std_logic;

	signal led_alarm_s   : std_logic_vector(15 downto 0);
	signal alarm_level_s : integer range 0 to 4;

begin
	system_rst <=not sw7;
	servo_enable_s <= standby_en_s or run_en_s;
	u_timebase : entity work.timebase
		port map (
			clk    => clk,
			rst   => system_rst,
			tick_1ms =>tick_1ms_s,
			tick_250ms =>tick_250ms_s,
			tick_2s => tick_2s_s,
			blink_2hz =>blink_2hz_s
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

    u_scan_ctrl : entity work.scan_ctrl
    port map (
        clk       => clk,
        rst       => system_rst,
        run_en    => run_en_s,
        tick_2s   => tick_2s_s,
        angle_deg => angle_deg_s
    );

    u_servo_pwm : entity work.servo_pwm
    port map (
        clk       => clk,
        rst       => system_rst,
        enable    => servo_enable_s,
        angle_deg => angle_deg_s,
        pwm_out   => servo_pwm_out
    );

    u_measure_ctrl : entity work.measure_ctrl
	port map (
		clk         => clk,
		rst         => system_rst,
		run_en      => run_en_s,
		tick_250ms  => tick_250ms_s,
		tick_2s     => tick_2s_s,
		ultra_busy  => ultra_busy_s,
		ultra_done  => ultra_done_s,
		ultra_start => ultra_start_s
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

	u_alarm_led_ctrl : entity work.alarm_led_ctrl
	port map (
		run_en         => run_en_s,
		distance_valid => distance_valid_s,
		distance_mm    => distance_mm_s,
		blink_2hz      => blink_2hz_s,
		led_alarm      => led_alarm_s,
		alarm_level    => alarm_level_s
	);

	led <=(others => blink_2hz_s) when self_test_en_s = '1'

		else led_alarm_s when run_en_s = '1'

		else (others => '0');
end architecture structural;