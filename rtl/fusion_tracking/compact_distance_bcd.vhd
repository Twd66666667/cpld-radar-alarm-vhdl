library ieee;
use ieee.std_logic_1164.all;

entity compact_distance_bcd is
port (
    clk : in std_logic;
    rst : in std_logic;
    clear : in std_logic;
    result_done : in std_logic;
    distance_mm : in integer range 0 to 4000;
    distance_valid : in std_logic;
    digit_1000 : out integer range 0 to 9;
    digit_100 : out integer range 0 to 9;
    digit_10 : out integer range 0 to 9;
    digit_1 : out integer range 0 to 9;
    bcd_valid : out std_logic;
    digit_done : out std_logic
);
end entity;

architecture rtl of compact_distance_bcd is
    type state_type is (IDLE_STATE, DIVIDE_STATE, ONES_STATE);
    signal state : state_type := IDLE_STATE;
    signal place : integer range 0 to 2 := 0;
    signal divisor : integer range 10 to 1000;
    signal work_value : integer range 0 to 4000 := 0;
    signal result_done_d : std_logic := '0';
    signal q1000, q100, q10, q1 : integer range 0 to 9 := 0;
begin
    digit_1000 <= q1000;
    digit_100 <= q100;
    digit_10 <= q10;
    digit_1 <= q1;
    with place select divisor <=
        1000 when 0, 100 when 1, 10 when others;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or clear = '1' then
                state <= IDLE_STATE;
                result_done_d <= '0';
                bcd_valid <= '0';
                digit_done <= '0';
            else
                result_done_d <= result_done;
                digit_done <= '0';
                case state is
                    when IDLE_STATE =>
                        if result_done_d = '1' then
                            q1000 <= 0;
                            q100 <= 0;
                            q10 <= 0;
                            q1 <= 0;
                            bcd_valid <= '0';
                            if distance_valid = '1' then
                                work_value <= distance_mm;
                                place <= 0;
                                state <= DIVIDE_STATE;
                            else
                                digit_done <= '1';
                            end if;
                        end if;
                    when DIVIDE_STATE =>
                        if work_value >= divisor then
                            work_value <= work_value - divisor;
                            case place is
                                when 0 => q1000 <= q1000 + 1;
                                when 1 => q100 <= q100 + 1;
                                when others => q10 <= q10 + 1;
                            end case;
                        elsif place = 2 then
                            state <= ONES_STATE;
                        else
                            place <= place + 1;
                        end if;
                    when ONES_STATE =>
                        q1 <= work_value;
                        bcd_valid <= '1';
                        digit_done <= '1';
                        state <= IDLE_STATE;
                    when others => state <= IDLE_STATE;
                end case;
            end if;
        end if;
    end process;
end architecture;
