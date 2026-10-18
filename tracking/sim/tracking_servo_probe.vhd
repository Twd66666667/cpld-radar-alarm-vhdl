library ieee;
use ieee.std_logic_1164.all;

-- Expose the calibrated table and the real PWM generator for VWF inspection.
entity tracking_servo_probe is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    enable         : in  std_logic;
    scan_index     : in  integer range 0 to 36;
    pulse_width_us : out integer range 450 to 2500;
    pwm_out        : out std_logic
);
end entity tracking_servo_probe;

architecture structural of tracking_servo_probe is
    signal pulse_width_s : integer range 450 to 2500;
begin
    pulse_width_us <= pulse_width_s;

    u_map : entity work.tracking_servo_map
    port map (
        scan_index     => scan_index,
        pulse_width_us => pulse_width_s,
        angle_100      => open,
        angle_10       => open,
        angle_1        => open
    );

    u_pwm : entity work.enhanced_servo_pwm
    port map (
        clk            => clk,
        rst            => rst,
        enable         => enable,
        pulse_width_us => pulse_width_s,
        pwm_out        => pwm_out
    );
end architecture structural;
