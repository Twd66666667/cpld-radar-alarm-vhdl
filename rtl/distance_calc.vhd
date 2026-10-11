library ieee;
use ieee.std_logic_1164.all;

entity distance_calc is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    done           : in  std_logic;
    valid          : in  std_logic;
    echo_time_us   : in  integer range 0 to 30000;
    distance_mm    : out integer range 0 to 4000;
    distance_valid : out std_logic
);
end entity distance_calc;

architecture rtl of distance_calc is

begin

	process(clk)
		variable calculated_mm : integer range 0 to 5200;
	begin
		if rising_edge(clk) then
			if rst = '1' then
				distance_mm <= 0;
				distance_valid <= '0';

			elsif done = '1' then
				if valid = '1' then
					-- 11/64 = 0.171875, close to the original 17/100.
					-- Divisions by powers of two synthesize as wiring shifts and
					-- avoid the large general-purpose divider used by /100.
					calculated_mm := (echo_time_us / 8) +
					                 (echo_time_us / 32) +
					                 (echo_time_us / 64);

					if calculated_mm >= 20 and calculated_mm <= 4000 then
						distance_mm <= calculated_mm;
						distance_valid <= '1';

					else
						distance_mm  <=0;
						distance_valid <= '0';
					end if;

				else
					distance_mm  <=0;
					distance_valid <= '0';
				end if;
			end if;
		end if;
	end process;



end architecture rtl;
