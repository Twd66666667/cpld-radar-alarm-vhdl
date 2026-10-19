library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity median3_vwf_top is
port (
    clk               : in  std_logic;
    rst               : in  std_logic;
    run_en            : in  std_logic;
    sample_done       : in  std_logic;
    sample_valid      : in  std_logic;
    value_high        : in  std_logic;
    result_done       : out std_logic;
    filtered_valid    : out std_logic;
    filtered_distance : out std_logic_vector(11 downto 0)
);
end entity median3_vwf_top;

architecture structural of median3_vwf_top is
    signal sample_distance_s   : integer range 0 to 4000;
    signal filtered_distance_s : integer range 0 to 4000;
begin
    sample_distance_s <= 900 when value_high = '1' else 100;
    filtered_distance <= std_logic_vector(to_unsigned(filtered_distance_s, 12));

    u_distance_median3 : entity work.distance_median3
    port map (
        clk               => clk,
        rst               => rst,
        run_en            => run_en,
        sample_done       => sample_done,
        sample_distance   => sample_distance_s,
        sample_valid      => sample_valid,
        result_done       => result_done,
        filtered_distance => filtered_distance_s,
        filtered_valid    => filtered_valid
    );
end architecture structural;
