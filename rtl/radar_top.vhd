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

	signal rst_timebase  : std_logic;
	signal tick_1ms_s    : std_logic;
	signal tick_250ms_s  : std_logic;
	signal tick_2s_s     : std_logic;
	signal blink_2hz_s   : std_logic;

begin
	rst_timebase <=not sw7;
	u_timebase : entity work.timebase
		port map (
			clk    => clk,
			rst   => rst_timebase,
			tick_1ms =>tick_1ms_s,
			tick_250ms =>tick_250ms_s,
			tick_2s => tick_2s_s,
			blink_2hz =>blink_2hz_s
		);

	led(0) <=blink_2hz_s when sw7 = '1' else '0';
	led(15 downto 1) <= (others => '0');
	
end architecture structural; 