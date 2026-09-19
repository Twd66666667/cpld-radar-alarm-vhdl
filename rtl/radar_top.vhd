library ieee;
use ieee.std_logic_1164.all;

entity radar_top is
	port (
		clk : in std_logic;
		sw7 : in std_logic;
		led : out std_logic_vector(15 downto 0)
	);
end entity radar_top;

architecture structural of radar_top is

	signal system_rst  : std_logic;
	signal tick_1ms_s    : std_logic;
	signal tick_250ms_s  : std_logic;
	signal tick_2s_s     : std_logic; 
	signal blink_2hz_s   : std_logic;
	
	signal self_test_en_s : std_logic;
	signal standby_en_s   : std_logic;
	signal run_en_s       : std_logic;

begin
	system_rst <=not sw7;
	u_timebase : entity work.timebase
		port map (
			clk    => clk,
			rst   => system_rst,
			tick_1ms =>tick_1ms_s,
			tick_250ms =>tick_250ms_s,
			tick_2s => tick_2s_s,
			blink_2hz =>blink_2hz_s
		);
	
	u_system_ctrl : entity work.system_ctrl
    port map (
        clk          => clk,
        rst          => system_rst,
        tick_2s      => tick_2s_s,
        self_test_en => self_test_en_s,
        standby_en   => standby_en_s,
        run_en       => run_en_s
    );

	led <= (others => blink_2hz_s)
		when self_test_en_s = '1' 
		else (others => '0');
	
end architecture structural; 