library ieee;
use ieee.std_logic_1164.all;

entity system_ctrl is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        tick_2s      : in  std_logic;
        self_test_en : out std_logic;
        standby_en   : out std_logic;
        run_en       : out std_logic
    );
end entity system_ctrl;

architecture rtl of system_ctrl is

	type state_type is(
		OFF_STATE,
		SELF_TEST_STATE,
		STANDBY_STATE,
		RUN_STATE
	);
	
	signal current_state : state_type := OFF_STATE;
	
begin
	
	process(clk)
	begin
		if rising_edge(clk) then 
			if rst = '1' then
				current_state <= OFF_STATE;
			else 
				case current_state is
					when OFF_STATE =>
						current_state <= SELF_TEST_STATE;
					when SELF_TEST_STATE =>
						if tick_2s = '1' then
							current_state <= STANDBY_STATE;
						end if;
					when STANDBY_STATE =>
						if tick_2s = '1' then
							current_state <= RUN_STATE;
						end if;
					when RUN_STATE =>
						current_state <= RUN_STATE;
						
				end case;
			end if;
		end if;					
	end process;
	
	self_test_en <= '1' when current_state = SELF_TEST_STATE else '0';
	standby_en   <= '1' when current_state = STANDBY_STATE else '0';
	run_en       <= '1' when current_state = RUN_STATE else '0';
	
end architecture rtl;