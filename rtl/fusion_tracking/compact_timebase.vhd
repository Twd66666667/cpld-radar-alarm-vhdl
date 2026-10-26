library ieee;
use ieee.std_logic_1164.all;

entity compact_timebase is
	port(
		clk        : in std_logic;
		rst        : in std_logic;
		tick_1ms   : out std_logic;
		tick_250ms : out std_logic;
		tick_2s    : out std_logic;
		blink_2hz  : out std_logic;
        tone_2khz : out std_logic
	);
end entity compact_timebase;

architecture rtl of compact_timebase is

	signal count_250us : integer range 0 to 249 := 0;
    signal quarter : integer range 0 to 3 := 0;
	signal count_250ms     : integer range 0 to 249 := 0;
	signal count_250ms_2s  : integer range 0 to 7 := 0;
	signal blink_state     : std_logic := '0';
	
begin 
					
	-- Use one 1 ms prescaler, then derive the slower enables from it.
	-- This avoids implementing separate 250000- and 2000000-cycle counters.
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				count_250us <= 0;
                quarter <= 0;
				count_250ms    <= 0;
				count_250ms_2s <= 0;
				blink_state    <= '0';
				tick_1ms      <= '0';
				tick_250ms    <= '0';
				tick_2s       <= '0';
			else
				tick_1ms   <= '0';
				tick_250ms <= '0';
				tick_2s    <= '0';

				if count_250us = 249 then
                    count_250us <= 0;
                    if quarter = 3 then
                        quarter <= 0;
					tick_1ms  <= '1';

					if count_250ms = 249 then
						count_250ms <= 0;
						tick_250ms <= '1';
						blink_state <= not blink_state;

						if count_250ms_2s = 7 then
							count_250ms_2s <= 0;
							tick_2s <= '1';
						else
							count_250ms_2s <= count_250ms_2s + 1;
						end if;
					else
						count_250ms <= count_250ms + 1;
					end if;
				else
                        quarter <= quarter + 1;
                    end if;
                else
                    count_250us <= count_250us + 1;
				end if;
			end if;
		end if;
	end process;

	blink_2hz <= blink_state;
    tone_2khz <= '1' when quarter = 1 or quarter = 3 else '0';

end architecture rtl;
