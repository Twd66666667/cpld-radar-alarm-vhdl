library ieee;
use ieee.std_logic_1164.all;

entity fusion_measure_vwf_top is
port (
    clk : in std_logic;
    rst : in std_logic;
    run_en : in std_logic;
    enhanced_mode : in std_logic;
    tick_1ms : in std_logic;
    cycle_start : in std_logic;
    ultra_busy : in std_logic;
    ultra_done : in std_logic;
    ultra_start : out std_logic;
    servo_quiet : out std_logic
);
end entity;

architecture structural of fusion_measure_vwf_top is
begin
    u_dut : entity work.fusion_measure_ctrl port map (
        clk => clk, rst => rst, run_en => run_en,
        enhanced_mode => enhanced_mode, tick_1ms => tick_1ms,
        cycle_start => cycle_start, ultra_busy => ultra_busy,
        ultra_done => ultra_done, ultra_start => ultra_start,
        servo_quiet => servo_quiet);
end architecture;
