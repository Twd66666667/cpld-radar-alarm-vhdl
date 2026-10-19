library ieee;
use ieee.std_logic_1164.all;

entity fusion_alarm is
port (
    run_en : in std_logic;
    distance_valid : in std_logic;
    level : in integer range 0 to 5;
    blink_2hz : in std_logic;
    led_alarm : out std_logic_vector(15 downto 0);
    alarm_level : out integer range 0 to 4
);
end entity;

architecture rtl of fusion_alarm is
begin
    process(run_en, distance_valid, level, blink_2hz)
    begin
        led_alarm <= (others => '0');
        alarm_level <= 0;
        if run_en = '1' and distance_valid = '1' then
            case level is
                when 1 => led_alarm(3 downto 0) <= (others => '1');
                when 2 =>
                    led_alarm(7 downto 4) <= (others => blink_2hz);
                    alarm_level <= 1;
                when 3 =>
                    led_alarm(11 downto 8) <= (others => blink_2hz);
                    alarm_level <= 2;
                when 4 =>
                    led_alarm(15 downto 12) <= (others => blink_2hz);
                    alarm_level <= 3;
                when 5 =>
                    led_alarm <= (others => blink_2hz);
                    alarm_level <= 4;
                when others => null;
            end case;
        end if;
    end process;
end architecture;
