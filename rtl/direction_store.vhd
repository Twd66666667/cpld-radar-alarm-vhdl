library ieee;
use ieee.std_logic_1164.all;

entity direction_store is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    run_en         : in  std_logic;
    result_done    : in  std_logic;
    angle_deg      : in  integer range 0 to 180;
    distance_mm    : in  integer range 0 to 4000;
    distance_valid : in  std_logic;

    distance_0_mm   : out integer range 0 to 4000;
    distance_45_mm  : out integer range 0 to 4000;
    distance_90_mm  : out integer range 0 to 4000;
    distance_135_mm : out integer range 0 to 4000;
    distance_180_mm : out integer range 0 to 4000;

    valid_0         : out std_logic;
    valid_45        : out std_logic;
    valid_90        : out std_logic;
    valid_135       : out std_logic;
    valid_180       : out std_logic
);
end entity direction_store;

architecture rtl of direction_store is

    signal result_done_d : std_logic := '0';

begin

	process(clk)
	begin
		if rising_edge(clk) then

			if rst = '1'  or run_en = '0' then
				distance_0_mm   <= 0;
				distance_45_mm  <= 0;
				distance_90_mm  <= 0;
				distance_135_mm <= 0;
				distance_180_mm <= 0;

				valid_0   <= '0';
				valid_45  <= '0';
				valid_90  <= '0';
				valid_135 <= '0';
				valid_180 <= '0';
				
				result_done_d <= '0';
			
			else 
				result_done_d <= result_done;
				
				if result_done_d = '1' then

					case angle_deg is
						when 0 =>
						distance_0_mm <= distance_mm;
						valid_0 <=  distance_valid;
					
						when 45 =>
						distance_45_mm <= distance_mm;
						valid_45 <= distance_valid;
						
						when 90 =>
						distance_90_mm <= distance_mm;
						valid_90 <= distance_valid;
						
						when 135 =>
						distance_135_mm <= distance_mm;
						valid_135 <= distance_valid;
						
						when 180 =>
						distance_180_mm <= distance_mm;
						valid_180 <= distance_valid;
						
						when others =>
						null;
						
					end case;
					
				end if;	
			end if;
		end if;		
	end process;

end architecture rtl;
