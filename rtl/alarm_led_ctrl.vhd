library ieee;
use ieee.std_logic_1164.all;

entity alarm_led_ctrl is
port (
    run_en         : in  std_logic;
    distance_valid : in  std_logic;
    distance_mm    : in  integer range 0 to 4000;
    blink_2hz      : in  std_logic;
    led_alarm      : out std_logic_vector(15 downto 0);
    alarm_level    : out integer range 0 to 4
);
end entity alarm_led_ctrl;

architecture rtl of alarm_led_ctrl is

begin

	process(run_en, distance_valid, distance_mm, blink_2hz)
	begin
		led_alarm <= (others => '0');
		alarm_level <= 0;

		if run_en ='1' and distance_valid ='1' then

			 if distance_mm >= 800 then
                -- 四个蓝色LED常亮
                led_alarm(3 downto 0) <= (others => '1');
                alarm_level <= 0;

            elsif distance_mm >= 600 then
                -- 四个绿色LED以2 Hz闪烁
                led_alarm(7 downto 4) <= (others => blink_2hz);
                alarm_level <= 1;

            elsif distance_mm >= 400 then
                -- 四个黄色LED以2 Hz闪烁
                led_alarm(11 downto 8) <= (others => blink_2hz);
                alarm_level <= 2;

            elsif distance_mm >= 200 then
                -- 四个红色LED以2 Hz闪烁
                led_alarm(15 downto 12) <= (others => blink_2hz);
                alarm_level <= 3;

            else
                -- 小于200 mm，全部LED闪烁
                led_alarm <= (others => blink_2hz);
                alarm_level <= 4;
            end if;

		end if;
	end process;

end architecture rtl;