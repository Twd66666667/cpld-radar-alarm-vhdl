library ieee;
use ieee.std_logic_1164.all;

entity tb_servo_pwm is
end entity tb_servo_pwm;

architecture sim of tb_servo_pwm is

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal enable    : std_logic := '0';
    signal angle_deg : integer range 0 to 180 := 0;
    signal pwm_out   : std_logic;

begin

	clk <= not clk after 500 ns;
	u_dut : entity work.servo_pwm
    port map (
        clk       => clk,
        rst       => rst,
        enable    => enable,
        angle_deg => angle_deg,
        pwm_out   => pwm_out
    );
    
	stimulus : process
	begin
		rst    <= '1';
		enable <= '0';
		angle_deg <= 0;
		wait for 2 us;

		rst    <= '0';
		enable <= '1';

		angle_deg <= 0;
		wait for 40 ms;

		angle_deg <= 90;
		wait for 40 ms;

		angle_deg <= 180;
		wait for 40 ms;

		enable <= '0';
		wait for 1 ms;

		wait;
	end process;
	
end architecture sim;