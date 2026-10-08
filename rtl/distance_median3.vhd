library ieee;
use ieee.std_logic_1164.all;

entity distance_median3 is
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
end entity distance_median3;

architecture rtl of distance_median3 is

    signal sample_done_d : std_logic := '0';
    signal sample_index  : integer range 0 to 2 := 0;

    signal sample_0       : integer range 0 to 4000 := 0;
    signal sample_1       : integer range 0 to 4000 := 0;
    signal sample_0_valid : std_logic := '0';
    signal sample_1_valid : std_logic := '0';

    signal result_done_reg       : std_logic := '0';
    signal filtered_distance_reg : integer range 0 to 4000 := 0;
    signal filtered_valid_reg    : std_logic := '0';

    function median_of_three(
        value_a : integer;
        value_b : integer;
        value_c : integer
    ) return integer is
    begin
        if value_a <= value_b then
            if value_b <= value_c then
                return value_b;
            elsif value_a <= value_c then
                return value_c;
            else
                return value_a;
            end if;
        else
            if value_a <= value_c then
                return value_a;
            elsif value_b <= value_c then
                return value_c;
            else
                return value_b;
            end if;
        end if;
    end function;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or run_en = '0' then
                sample_done_d        <= '0';
                sample_index         <= 0;
                sample_0             <= 0;
                sample_1             <= 0;
                sample_0_valid       <= '0';
                sample_1_valid       <= '0';
                result_done_reg      <= '0';
                filtered_distance_reg <= 0;
                filtered_valid_reg   <= '0';

            else
                -- distance_calc updates one clock after sample_done is observed.
                -- Delay the pulse so the corresponding distance is already stable.
                sample_done_d   <= sample_done;
                result_done_reg <= '0';

                if sample_done_d = '1' then
                    case sample_index is
                        when 0 =>
                            sample_0       <= sample_distance;
                            sample_0_valid <= sample_valid;
                            sample_index   <= 1;

                        when 1 =>
                            sample_1       <= sample_distance;
                            sample_1_valid <= sample_valid;
                            sample_index   <= 2;

                        when 2 =>
                            -- Three valid samples: reject one outlier with the median.
                            if sample_0_valid = '1' and
                               sample_1_valid = '1' and
                               sample_valid = '1' then

                                filtered_distance_reg <= median_of_three(
                                    sample_0,
                                    sample_1,
                                    sample_distance
                                );
                                filtered_valid_reg <= '1';

                            -- Two valid samples: use their mean.
                            elsif sample_0_valid = '1' and
                                  sample_1_valid = '1' then

                                filtered_distance_reg <=
                                    (sample_0 + sample_1) / 2;
                                filtered_valid_reg <= '1';

                            elsif sample_0_valid = '1' and
                                  sample_valid = '1' then

                                filtered_distance_reg <=
                                    (sample_0 + sample_distance) / 2;
                                filtered_valid_reg <= '1';

                            elsif sample_1_valid = '1' and
                                  sample_valid = '1' then

                                filtered_distance_reg <=
                                    (sample_1 + sample_distance) / 2;
                                filtered_valid_reg <= '1';

                            -- One valid sample is still better than reporting no target.
                            elsif sample_0_valid = '1' then
                                filtered_distance_reg <= sample_0;
                                filtered_valid_reg <= '1';

                            elsif sample_1_valid = '1' then
                                filtered_distance_reg <= sample_1;
                                filtered_valid_reg <= '1';

                            elsif sample_valid = '1' then
                                filtered_distance_reg <= sample_distance;
                                filtered_valid_reg <= '1';

                            else
                                filtered_distance_reg <= 0;
                                filtered_valid_reg <= '0';
                            end if;

                            result_done_reg <= '1';
                            sample_index <= 0;

                        when others =>
                            sample_index <= 0;
                    end case;
                end if;
            end if;
        end if;
    end process;

    result_done       <= result_done_reg;
    filtered_distance <= filtered_distance_reg;
    filtered_valid    <= filtered_valid_reg;

end architecture rtl;
