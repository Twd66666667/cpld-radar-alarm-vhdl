library ieee;
use ieee.std_logic_1164.all;

entity servo_pwm is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        enable    : in  std_logic;
        angle_deg : in  integer range 0 to 180;
        pwm_out   : out std_logic
    );
end entity servo_pwm;

architecture rtl of servo_pwm is

    signal pwm_count : integer range 0 to 19999 := 0;
    signal pulse_width_us : integer range 450 to 2500 := 450;

begin
	process(clk)
	begin
		if rising_edge(clk) then
			if rst ='1' then
				pwm_count <=0;
			
			elsif enable = '0' then
				pwm_count <= 0;
			else
				if pwm_count = 19999 then
					pwm_count <= 0;
				else pwm_count <= pwm_count +1;
				end if;
			end if;
		end if;
	end process;
	
	with angle_deg select
    pulse_width_us <= 480  when 0,
                      880 when 45,
                      1380 when 90,
                      1880 when 135,
                      2340 when 180,
                      1380 when others;
                      
    pwm_out <= '1'
		when rst = '0' and enable = '1' and pwm_count <pulse_width_us 
		else '0';
end architecture rtl;
