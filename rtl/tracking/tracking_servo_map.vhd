library ieee;
use ieee.std_logic_1164.all;

entity tracking_servo_map is
port (
    scan_index     : in  integer range 0 to 36;
    pulse_width_us : out integer range 450 to 2500;
    angle_100      : out integer range 0 to 1;
    angle_10       : out integer range 0 to 9;
    angle_1        : out integer range 0 to 9
);
end entity tracking_servo_map;

architecture rtl of tracking_servo_map is
begin
    -- Keep the exact 37 experimentally calibrated positions used by the
    -- working enhanced project.  In particular, 90 degrees is 1380 us.
    with scan_index select
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

    angle_100 <= 1 when scan_index >= 20 else 0;
    angle_1   <= 5 when scan_index mod 2 = 1 else 0;
    with scan_index select
    angle_10 <=
        0 when 0 | 1 | 20 | 21,
        1 when 2 | 3 | 22 | 23,
        2 when 4 | 5 | 24 | 25,
        3 when 6 | 7 | 26 | 27,
        4 when 8 | 9 | 28 | 29,
        5 when 10 | 11 | 30 | 31,
        6 when 12 | 13 | 32 | 33,
        7 when 14 | 15 | 34 | 35,
        8 when 16 | 17 | 36,
        9 when 18 | 19,
        0 when others;
end architecture rtl;
