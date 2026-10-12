library ieee;
use ieee.std_logic_1164.all;

entity enhanced_servo_pwm is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    enable         : in  std_logic;
    pulse_width_us : in  integer range 450 to 2500;
    pwm_out        : out std_logic
);
end entity enhanced_servo_pwm;

architecture rtl of enhanced_servo_pwm is
    signal pwm_count : integer range 0 to 19999 := 0;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or enable = '0' then
                pwm_count <= 0;
            elsif pwm_count = 19999 then
                pwm_count <= 0;
            else
                pwm_count <= pwm_count + 1;
            end if;
        end if;
    end process;

    pwm_out <= '1'
        when rst = '0' and enable = '1' and
             pwm_count < pulse_width_us
        else '0';

end architecture rtl;
