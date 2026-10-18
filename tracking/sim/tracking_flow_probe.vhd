library ieee;
use ieee.std_logic_1164.all;

-- VWF integration wrapper.  The board top uses the same three components,
-- while this wrapper exposes their handshake pins for a readable waveform.
entity tracking_flow_probe is
port (
    clk               : in  std_logic;
    rst               : in  std_logic;
    run_en            : in  std_logic;
    tick_1ms          : in  std_logic;
    ultra_busy        : in  std_logic;
    ultra_done        : in  std_logic;
    sample_valid      : in  std_logic;
    sample_distance   : in  integer range 0 to 4000;
    scan_index        : out integer range 0 to 36;
    mode_code         : out integer range 0 to 2;
    cycle_start       : out std_logic;
    servo_quiet       : out std_logic;
    ultra_start       : out std_logic;
    result_done       : out std_logic;
    result_valid      : out std_logic;
    filtered_distance : out integer range 0 to 4000
);
end entity tracking_flow_probe;

architecture structural of tracking_flow_probe is
    signal result_done_s       : std_logic;
    signal result_valid_s      : std_logic;
    signal filtered_distance_s : integer range 0 to 4000;
    signal cycle_start_s       : std_logic;
begin
    result_done       <= result_done_s;
    result_valid      <= result_valid_s;
    filtered_distance <= filtered_distance_s;
    cycle_start       <= cycle_start_s;

    u_tracker : entity work.target_tracker_ctrl
    port map (
        clk          => clk,
        rst          => rst,
        run_en       => run_en,
        tick_1ms     => tick_1ms,
        result_done  => result_done_s,
        result_valid => result_valid_s,
        distance_mm  => filtered_distance_s,
        scan_index   => scan_index,
        target_index => open,
        target_valid => open,
        mode_code    => mode_code,
        cycle_start  => cycle_start_s
    );

    u_measure : entity work.enhanced_measure_ctrl
    port map (
        clk         => clk,
        rst         => rst,
        run_en      => run_en,
        tick_1ms    => tick_1ms,
        cycle_start => cycle_start_s,
        ultra_busy  => ultra_busy,
        ultra_done  => ultra_done,
        ultra_start => ultra_start,
        servo_quiet => servo_quiet
    );

    u_filter : entity work.distance_median3
    port map (
        clk               => clk,
        rst               => rst,
        run_en            => run_en,
        sample_done       => ultra_done,
        sample_distance   => sample_distance,
        sample_valid      => sample_valid,
        result_done       => result_done_s,
        filtered_distance => filtered_distance_s,
        filtered_valid    => result_valid_s
    );
end architecture structural;
