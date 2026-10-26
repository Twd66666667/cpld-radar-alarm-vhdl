library ieee;
use ieee.std_logic_1164.all;

entity streaming_median3 is
port (
    clk               : in  std_logic;
    rst               : in  std_logic;
    run_en            : in  std_logic;
    sample_done       : in  std_logic;
    sample_distance   : in  integer range 0 to 4000;
    sample_valid      : in  std_logic;
    result_done       : out std_logic;
    filtered_distance : out integer range 0 to 4000;
    filtered_valid    : out std_logic
);
end entity;

architecture rtl of streaming_median3 is
    signal sample_done_d : std_logic := '0';
    signal sample_index : integer range 0 to 2 := 0;
    signal valid_count : integer range 0 to 2 := 0;
    signal low_value, high_value : integer range 0 to 4000 := 0;
    signal mean_pending : std_logic := '0';
    signal result_reg, valid_reg : std_logic := '0';
    signal distance_reg : integer range 0 to 4000 := 0;
begin
    result_done <= result_reg;
    filtered_distance <= distance_reg;
    filtered_valid <= valid_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or run_en = '0' then
                sample_done_d <= '0';
                sample_index <= 0;
                valid_count <= 0;
                mean_pending <= '0';
                result_reg <= '0';
                valid_reg <= '0';
                distance_reg <= 0;
            else
                sample_done_d <= sample_done;
                result_reg <= '0';
                if mean_pending = '1' then
                    distance_reg <= (low_value + high_value) / 2;
                    valid_reg <= '1';
                    result_reg <= '1';
                    mean_pending <= '0';
                elsif sample_done_d = '1' then
                    if sample_index = 0 then
                        sample_index <= 1;
                        valid_count <= 0;
                        if sample_valid = '1' then
                            low_value <= sample_distance;
                            high_value <= sample_distance;
                            valid_count <= 1;
                        end if;
                    elsif sample_index = 1 then
                        sample_index <= 2;
                        if sample_valid = '1' then
                            if valid_count = 0 then
                                low_value <= sample_distance;
                                high_value <= sample_distance;
                                valid_count <= 1;
                            else
                                if sample_distance < low_value then
                                    low_value <= sample_distance;
                                else
                                    high_value <= sample_distance;
                                end if;
                                valid_count <= 2;
                            end if;
                        end if;
                    else
                        sample_index <= 0;
                        if valid_count = 2 then
                            if sample_valid = '1' then
                                if sample_distance <= low_value then
                                    distance_reg <= low_value;
                                elsif sample_distance >= high_value then
                                    distance_reg <= high_value;
                                else
                                    distance_reg <= sample_distance;
                                end if;
                                valid_reg <= '1';
                                result_reg <= '1';
                            else
                                mean_pending <= '1';
                            end if;
                        elsif valid_count = 1 and sample_valid = '1' then
                            high_value <= sample_distance;
                            mean_pending <= '1';
                        else
                            distance_reg <= 0;
                            valid_reg <= '0';
                            result_reg <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
