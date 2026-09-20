library ieee;
use ieee.std_logic_1164.all;

entity scan_ctrl is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        run_en   : in  std_logic;
        tick_2s  : in  std_logic;
        angle_deg : out integer range 0 to 180
    );
end entity scan_ctrl;

architecture rtl of scan_ctrl is
	
	signal scan_index : integer range 0 to 7 :=0;
	
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				scan_index <= 0;
				
			elsif run_en = '0' then
				scan_index <= 0;
				
			elsif tick_2s = '1' then
				if scan_index = 7 then
					scan_index <= 0;
				else
					scan_index <= scan_index + 1;
				end if;
			end if;
		end if;
	end process;
	with scan_index select
		angle_deg <= 0   when 0,
					 45  when 1,
					 90  when 2,
					 135 when 3,
					 180 when 4,
					 135 when 5,
					 90  when 6,
					 45  when 7,
					 0   when others;
end architecture rtl;
