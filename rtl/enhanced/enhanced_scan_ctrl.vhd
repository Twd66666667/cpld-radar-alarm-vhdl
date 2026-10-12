library ieee;
use ieee.std_logic_1164.all;

entity enhanced_scan_ctrl is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    run_en         : in  std_logic;
    tick_1ms       : in  std_logic;
    pulse_width_us : out integer range 450 to 2500;
    scan_index     : out integer range 0 to 36;
    angle_100      : out integer range 0 to 1;
    angle_10       : out integer range 0 to 9;
    angle_1        : out integer range 0 to 9;
    cycle_start    : out std_logic
);
end entity enhanced_scan_ctrl;

architecture rtl of enhanced_scan_ctrl is

    signal index_reg    : integer range 0 to 36 := 0;
    signal angle_100_reg : integer range 0 to 1 := 0;
    signal angle_10_reg  : integer range 0 to 9 := 0;
    signal angle_1_reg   : integer range 0 to 9 := 0;
    signal period_count : integer range 0 to 399 := 0;
    signal direction_up : std_logic := '1';
    signal run_en_d     : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                index_reg    <= 0;
                angle_100_reg <= 0;
                angle_10_reg  <= 0;
                angle_1_reg   <= 0;
                period_count <= 0;
                direction_up <= '1';
                run_en_d     <= '0';
                cycle_start  <= '0';

            else
                run_en_d    <= run_en;
                cycle_start <= '0';

                if run_en = '0' then
                    index_reg    <= 0;
                    angle_100_reg <= 0;
                    angle_10_reg  <= 0;
                    angle_1_reg   <= 0;
                    period_count <= 0;
                    direction_up <= '1';

                elsif run_en_d = '0' then
                    -- Start the first measurement cycle at 0 degrees.
                    period_count <= 0;
                    cycle_start  <= '1';

                elsif tick_1ms = '1' then
                    if period_count = 399 then
                        period_count <= 0;
                        cycle_start  <= '1';

                        if direction_up = '1' then
                            if index_reg = 36 then
                                index_reg    <= 35;
                                angle_100_reg <= 1;
                                angle_10_reg  <= 7;
                                angle_1_reg   <= 5;
                                direction_up <= '0';
                            else
                                index_reg <= index_reg + 1;

                                if angle_1_reg = 0 then
                                    angle_1_reg <= 5;
                                else
                                    angle_1_reg <= 0;
                                    if angle_10_reg = 9 then
                                        angle_10_reg <= 0;
                                        angle_100_reg <= angle_100_reg + 1;
                                    else
                                        angle_10_reg <= angle_10_reg + 1;
                                    end if;
                                end if;
                            end if;
                        else
                            if index_reg = 0 then
                                index_reg    <= 1;
                                angle_100_reg <= 0;
                                angle_10_reg  <= 0;
                                angle_1_reg   <= 5;
                                direction_up <= '1';
                            else
                                index_reg <= index_reg - 1;

                                if angle_1_reg = 5 then
                                    angle_1_reg <= 0;
                                else
                                    angle_1_reg <= 5;
                                    if angle_10_reg = 0 then
                                        angle_10_reg <= 9;
                                        angle_100_reg <= angle_100_reg - 1;
                                    else
                                        angle_10_reg <= angle_10_reg - 1;
                                    end if;
                                end if;
                            end if;
                        end if;
                    else
                        period_count <= period_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    scan_index <= index_reg;
    angle_100 <= angle_100_reg;
    angle_10  <= angle_10_reg;
    angle_1   <= angle_1_reg;

    -- Piecewise-linear interpolation of the five calibrated servo points.
    with index_reg select
    pulse_width_us <=
        480  when 0,
        524  when 1,
        569  when 2,
        613  when 3,
        658  when 4,
        702  when 5,
        747  when 6,
        791  when 7,
        836  when 8,
        880  when 9,
        936  when 10,
        991  when 11,
        1047 when 12,
        1102 when 13,
        1158 when 14,
        1213 when 15,
        1269 when 16,
        1324 when 17,
        1380 when 18,
        1436 when 19,
        1491 when 20,
        1547 when 21,
        1602 when 22,
        1658 when 23,
        1713 when 24,
        1769 when 25,
        1824 when 26,
        1880 when 27,
        1931 when 28,
        1982 when 29,
        2033 when 30,
        2084 when 31,
        2136 when 32,
        2187 when 33,
        2238 when 34,
        2289 when 35,
        2340 when 36,
        1380 when others;

end architecture rtl;
