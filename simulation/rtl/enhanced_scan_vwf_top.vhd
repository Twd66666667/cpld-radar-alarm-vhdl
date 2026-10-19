library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity enhanced_scan_vwf_top is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        run_en       : in  std_logic;
        tick_1ms     : in  std_logic;
        scan_index_u6 : out std_logic_vector(5 downto 0);
        angle_u8      : out std_logic_vector(7 downto 0);
        pulse_us_u12  : out std_logic_vector(11 downto 0);
        cycle_start   : out std_logic
    );
end entity enhanced_scan_vwf_top;

architecture structural of enhanced_scan_vwf_top is
    signal pulse_s : integer range 450 to 2500;
    signal index_s : integer range 0 to 36;
    signal a100_s  : integer range 0 to 1;
    signal a10_s   : integer range 0 to 9;
    signal a1_s    : integer range 0 to 9;
begin
    u_dut : entity work.enhanced_scan_ctrl
        port map (
            clk            => clk,
            rst            => rst,
            run_en         => run_en,
            tick_1ms       => tick_1ms,
            pulse_width_us => pulse_s,
            scan_index     => index_s,
            angle_100      => a100_s,
            angle_10       => a10_s,
            angle_1        => a1_s,
            cycle_start    => cycle_start
        );

    scan_index_u6 <= std_logic_vector(to_unsigned(index_s, 6));
    angle_u8      <= std_logic_vector(to_unsigned(
        a100_s * 100 + a10_s * 10 + a1_s, 8));
    pulse_us_u12  <= std_logic_vector(to_unsigned(pulse_s, 12));
end architecture structural;
