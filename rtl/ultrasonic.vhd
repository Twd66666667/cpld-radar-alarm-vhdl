library ieee;
use ieee.std_logic_1164.all;

entity ultrasonic is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        start        : in  std_logic;
        echo_in      : in  std_logic;
        trig_out     : out std_logic;
        busy         : out std_logic;
        done         : out std_logic;
        valid        : out std_logic;
        echo_time_us : out integer range 0 to 30000
    );
end entity ultrasonic;

architecture rtl of ultrasonic is

		signal echo_meta : std_logic :='0';
		signal echo_sync : std_logic :='0';

		type state_type is (
			IDLE_STATE,
			TRIGGER_STATE,
			WAIT_ECHO_STATE,
			MEASURE_STATE,
			DONE_STATE
		);
		signal current_state : state_type := IDLE_STATE;
		signal trig_count : integer range 0 to 19 := 0;

		signal wait_count    : integer range 0 to 29999 := 0;
		signal echo_time_reg : integer range 0 to 30000 := 0;
		signal result_valid  : std_logic := '0';

		signal echo_time_count : integer range 0 to 30000 := 0;

begin
	trig_out <= '1' when current_state = TRIGGER_STATE
	else '0';

	busy <= '0' when current_state = IDLE_STATE
	else '1';

	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				echo_meta <='0';
				echo_sync <='0';
			else
				echo_meta <= echo_in;
				echo_sync <= echo_meta;
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				current_state <= idle_state;
				trig_count    <= 0;
				wait_count    <= 0;
				echo_time_reg <= 0;
				echo_time_count <= 0;
				result_valid  <= '0';

			else
				case current_state is

					when IDLE_STATE =>
						trig_count <= 0;
						wait_count <= 0;
						if start ='1' then
							echo_time_reg <= 0;
							echo_time_count <=0;
							result_valid <= '0';
							current_state <= TRIGGER_STATE;
						end if;

					when TRIGGER_STATE =>
						if trig_count = 19 then
							trig_count <= 0;
							wait_count <= 0;
							current_state <= WAIT_ECHO_STATE;
						else
							trig_count <= trig_count +1;
						end if;

					when WAIT_ECHO_STATE =>
						if echo_sync = '1' then
							echo_time_count <= 1;
							wait_count <= 0;
							current_state <= MEASURE_STATE;
						elsif wait_count =29999 then
							wait_count    <= 0;
							echo_time_reg <= 0;
							result_valid  <= '0';
							current_state <= DONE_STATE;

						else
							wait_count <= wait_count +1;
						end if;

					when MEASURE_STATE =>
						if echo_sync = '0' then
							echo_time_reg <= echo_time_count;
							result_valid <= '1';
							current_state <= DONE_STATE;

						elsif echo_time_count = 30000 then
							echo_time_reg <= 0;
							result_valid <= '0';
							current_state <= DONE_STATE;

						else
							echo_time_count <= echo_time_count +1 ;

						end if;

					when DONE_STATE =>
						current_state <= IDLE_STATE;
				end case;
			end if;
		end if;
	end process;


	done <= '1' when current_state = DONE_STATE
	else '0';

	valid <= '1' when result_valid = '1'
	else '0';

	echo_time_us  <= echo_time_reg;


end architecture rtl;