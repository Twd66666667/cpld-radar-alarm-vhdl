library ieee;
use ieee.std_logic_1164.all;

entity fusion_levels is
port (
    clk : in std_logic;
    rst : in std_logic;
    run_en : in std_logic;
    result_done : in std_logic;
    angle_deg : in integer range 0 to 180;
    distance_mm : in integer range 0 to 4000;
    distance_valid : in std_logic;
    current_level : out integer range 0 to 5;
    level_0 : out integer range 0 to 5;
    level_45 : out integer range 0 to 5;
    level_90 : out integer range 0 to 5;
    level_135 : out integer range 0 to 5;
    level_180 : out integer range 0 to 5
);
end entity;

architecture rtl of fusion_levels is
    signal done_d : std_logic := '0';
    signal classified : integer range 0 to 5;
begin
    current_level <= classified;
    process(distance_mm, distance_valid)
    begin
        if distance_valid = '0' then classified <= 0;
        elsif distance_mm >= 800 then classified <= 1;
        elsif distance_mm >= 600 then classified <= 2;
        elsif distance_mm >= 400 then classified <= 3;
        elsif distance_mm >= 200 then classified <= 4;
        else classified <= 5;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or run_en = '0' then
                done_d <= '0';
                level_0 <= 0;
                level_45 <= 0;
                level_90 <= 0;
                level_135 <= 0;
                level_180 <= 0;
            else
                done_d <= result_done;
                if done_d = '1' then
                    case angle_deg is
                        when 0 => level_0 <= classified;
                        when 45 => level_45 <= classified;
                        when 90 => level_90 <= classified;
                        when 135 => level_135 <= classified;
                        when 180 => level_180 <= classified;
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process;
end architecture;
