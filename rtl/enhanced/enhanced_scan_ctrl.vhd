library ieee;
use ieee.std_logic_1164.all;

entity enhanced_scan_ctrl is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    run_en         : in  std_logic;
    tick_1ms       : in  std_logic;
    angle_deg      : out integer range 0 to 180;
    pulse_width_us : out integer range 450 to 2500;
    cycle_start    : out std_logic
);
end entity enhanced_scan_ctrl;

architecture rtl of enhanced_scan_ctrl is

    signal angle_reg    : integer range 0 to 180 := 0;
    signal period_count : integer range 0 to 399 := 0;
    signal direction_up : std_logic := '1';
    signal run_en_d     : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                angle_reg    <= 0;
                period_count <= 0;
                direction_up <= '1';
                run_en_d     <= '0';
                cycle_start  <= '0';

            else
                run_en_d    <= run_en;
                cycle_start <= '0';

                if run_en = '0' then
                    angle_reg    <= 0;
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
                            if angle_reg = 180 then
                                angle_reg    <= 175;
                                direction_up <= '0';
                            else
                                angle_reg <= angle_reg + 5;
                            end if;
                        else
                            if angle_reg = 0 then
                                angle_reg    <= 5;
                                direction_up <= '1';
                            else
                                angle_reg <= angle_reg - 5;
                            end if;
                        end if;
                    else
                        period_count <= period_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    angle_deg <= angle_reg;

    -- Piecewise-linear interpolation of the five calibrated servo points.
    with angle_reg select
    pulse_width_us <=
        480  when 0,
        524  when 5,
        569  when 10,
        613  when 15,
        658  when 20,
        702  when 25,
        747  when 30,
        791  when 35,
        836  when 40,
        880  when 45,
        936  when 50,
        991  when 55,
        1047 when 60,
        1102 when 65,
        1158 when 70,
        1213 when 75,
        1269 when 80,
        1324 when 85,
        1380 when 90,
        1436 when 95,
        1491 when 100,
        1547 when 105,
        1602 when 110,
        1658 when 115,
        1713 when 120,
        1769 when 125,
        1824 when 130,
        1880 when 135,
        1931 when 140,
        1982 when 145,
        2033 when 150,
        2084 when 155,
        2136 when 160,
        2187 when 165,
        2238 when 170,
        2289 when 175,
        2340 when 180,
        1380 when others;

end architecture rtl;
