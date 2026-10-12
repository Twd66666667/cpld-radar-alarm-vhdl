library ieee;
use ieee.std_logic_1164.all;

entity enhanced_direction_levels is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    run_en         : in  std_logic;
    result_done    : in  std_logic;
    scan_index     : in  integer range 0 to 36;
    distance_mm    : in  integer range 0 to 4000;
    distance_valid : in  std_logic;
    level_0        : out integer range 0 to 5;
    level_45       : out integer range 0 to 5;
    level_90       : out integer range 0 to 5;
    level_135      : out integer range 0 to 5;
    level_180      : out integer range 0 to 5
);
end entity enhanced_direction_levels;

architecture rtl of enhanced_direction_levels is

    function classify_distance(
        distance_value : integer;
        valid_value    : std_logic
    ) return integer is
    begin
        if valid_value = '0' then
            return 0;
        elsif distance_value >= 800 then
            return 1;
        elsif distance_value >= 600 then
            return 2;
        elsif distance_value >= 400 then
            return 3;
        elsif distance_value >= 200 then
            return 4;
        else
            return 5;
        end if;
    end function;

begin

    process(clk)
        variable new_level : integer range 0 to 5;
    begin
        if rising_edge(clk) then
            if rst = '1' or run_en = '0' then
                level_0   <= 0;
                level_45  <= 0;
                level_90  <= 0;
                level_135 <= 0;
                level_180 <= 0;
            elsif result_done = '1' then
                new_level := classify_distance(distance_mm, distance_valid);

                case scan_index is
                    when 0   => level_0   <= new_level;
                    when 9   => level_45  <= new_level;
                    when 18  => level_90  <= new_level;
                    when 27  => level_135 <= new_level;
                    when 36  => level_180 <= new_level;
                    when others => null;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
