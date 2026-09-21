library ieee;
use ieee.std_logic_1164.all;

entity measure_ctrl is
port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    run_en       : in  std_logic;
    tick_250ms   : in  std_logic;
    tick_2s      : in  std_logic;
    ultra_busy   : in  std_logic;
    ultra_done   : in  std_logic;
    ultra_start  : out std_logic
);
end entity measure_ctrl;

architecture rtl of measure_ctrl is

    type state_type is (
        IDLE_STATE,
        WAIT_SETTLE_STATE,
        START_STATE,
        WAIT_DONE_STATE,
        WAIT_NEXT_STATE
    );

    signal current_state : state_type := IDLE_STATE;

begin
	process(clk)
	begin
		if rising_edge(clk)then
			if rst ='1' then
				current_state <= IDLE_STATE;
				ultra_start <= '0';

			else
				ultra_start <= '0';
				case current_state is
					when IDLE_STATE =>
						if run_en = '1' then
							current_state <= WAIT_SETTLE_STATE;
						end if;

					when WAIT_SETTLE_STATE =>
						if run_en = '0' then
							current_state <= IDLE_STATE;
						elsif tick_250ms = '1' then
							current_state <= START_STATE;
						end if;

					when START_STATE =>
						if run_en = '0' then
							current_state <= IDLE_STATE;

						elsif ultra_busy = '0' then
							ultra_start <= '1';
							current_state <= WAIT_DONE_STATE;
						end if;

					when WAIT_DONE_STATE =>
						if run_en = '0' then
							current_state <= IDLE_STATE;

						elsif ultra_done = '1' then
							current_state <= WAIT_NEXT_STATE;

						end if;

					when WAIT_NEXT_STATE =>
						if run_en = '0' then
						   current_state <= IDLE_STATE;

						elsif tick_2s = '1' then
						   current_state <= WAIT_SETTLE_STATE;
						end if;

					when others =>
						current_state <= IDLE_STATE;

				end case;
			end if;
		end if;
	end process;

end architecture rtl;