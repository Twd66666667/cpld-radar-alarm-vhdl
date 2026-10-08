library ieee;
use ieee.std_logic_1164.all;

entity distance_bcd is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    result_done    : in  std_logic;
    distance_mm    : in  integer range 0 to 4000;
    distance_valid : in  std_logic;

    digit_1000     : out integer range 0 to 9;
    digit_100      : out integer range 0 to 9;
    digit_10       : out integer range 0 to 9;
    digit_1        : out integer range 0 to 9;
    bcd_valid      : out std_logic
);
end entity distance_bcd;

architecture rtl of distance_bcd is

    type state_type is (
        IDLE_STATE,
        THOUSANDS_STATE,
        HUNDREDS_STATE,
        TENS_STATE,
        ONES_STATE
    );

    signal current_state : state_type := IDLE_STATE;
    signal result_done_d : std_logic := '0';
    signal work_value    : integer range 0 to 4000 := 0;

    signal digit_1000_reg : integer range 0 to 9 := 0;
    signal digit_100_reg  : integer range 0 to 9 := 0;
    signal digit_10_reg   : integer range 0 to 9 := 0;
    signal digit_1_reg    : integer range 0 to 9 := 0;

begin

    digit_1000 <= digit_1000_reg;
    digit_100  <= digit_100_reg;
    digit_10   <= digit_10_reg;
    digit_1    <= digit_1_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= IDLE_STATE;
                result_done_d <= '0';
                work_value <= 0;

                digit_1000_reg <= 0;
                digit_100_reg  <= 0;
                digit_10_reg   <= 0;
                digit_1_reg    <= 0;
                bcd_valid      <= '0';

            else
                result_done_d <= result_done;

                case current_state is
                    when IDLE_STATE =>
                        if result_done_d = '1' then
                            digit_1000_reg <= 0;
                            digit_100_reg  <= 0;
                            digit_10_reg   <= 0;
                            digit_1_reg    <= 0;
                            bcd_valid      <= '0';

                            if distance_valid = '1' then
                                work_value <= distance_mm;
                                current_state <= THOUSANDS_STATE;
                            else
                                work_value <= 0;
                                current_state <= IDLE_STATE;
                            end if;
                        end if;

                    when THOUSANDS_STATE =>
                        if work_value >= 1000 then
                            work_value <= work_value - 1000;
                            digit_1000_reg <= digit_1000_reg + 1;
                        else
                            current_state <= HUNDREDS_STATE;
                        end if;

                    when HUNDREDS_STATE =>
                        if work_value >= 100 then
                            work_value <= work_value - 100;
                            digit_100_reg <= digit_100_reg + 1;
                        else
                            current_state <= TENS_STATE;
                        end if;

                    when TENS_STATE =>
                        if work_value >= 10 then
                            work_value <= work_value - 10;
                            digit_10_reg <= digit_10_reg + 1;
                        else
                            current_state <= ONES_STATE;
                        end if;

                    when ONES_STATE =>
                        digit_1_reg <= work_value;
                        bcd_valid <= '1';
                        current_state <= IDLE_STATE;

                    when others =>
                        current_state <= IDLE_STATE;
                        bcd_valid <= '0';
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
