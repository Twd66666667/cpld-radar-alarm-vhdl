library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- VWF-only probe for the shared decimal converter and its one-cycle ready pulse.
entity fusion_bcd_vwf_top is
port (
    clk : in std_logic;
    rst : in std_logic;
    clear : in std_logic;
    result_done : in std_logic;
    distance_valid : in std_logic;
    distance_mm_u12 : in std_logic_vector(11 downto 0);
    thousands_u4 : out std_logic_vector(3 downto 0);
    hundreds_u4 : out std_logic_vector(3 downto 0);
    bcd_valid : out std_logic;
    digit_done : out std_logic
);
end entity;

architecture structural of fusion_bcd_vwf_top is
    signal d1000, d100, d10, d1 : integer range 0 to 9;
begin
    u_dut : entity work.fusion_distance_bcd port map (
        clk => clk, rst => rst, clear => clear,
        result_done => result_done,
        distance_mm => to_integer(unsigned(distance_mm_u12)),
        distance_valid => distance_valid,
        digit_1000 => d1000, digit_100 => d100,
        digit_10 => d10, digit_1 => d1,
        bcd_valid => bcd_valid, digit_done => digit_done);
    thousands_u4 <= std_logic_vector(to_unsigned(d1000, 4));
    hundreds_u4 <= std_logic_vector(to_unsigned(d100, 4));
end architecture;
