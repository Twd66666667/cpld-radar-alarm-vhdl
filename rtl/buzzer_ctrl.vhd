library ieee;
use ieee.std_logic_1164.all;

entity buzzer_ctrl is
port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    run_en       : in  std_logic;
    tick_1ms     : in  std_logic;
    alarm_level  : in  integer range 0 to 4;
    buzzer_out   : out std_logic
);
end entity buzzer_ctrl;

architecture rtl of buzzer_ctrl is

	signal tone_count    : integer range 0 to 249 := 0;
    signal tone_state    : std_logic := '0';

    signal beep_count_ms : integer range 0 to 999 := 0;
    signal beep_gate     : std_logic := '0';

begin
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' or run_en = '0' or alarm_level = 0 then
				tone_count <= 0;
				tone_state <= '0';

			else
				if tone_count = 249 then
					tone_count <= 0;
					tone_state <= not tone_state;

				else tone_count <=tone_count +1;

				end if;
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if rst ='1' or run_en = '0' or alarm_level = 0 then
				beep_count_ms <= 0;

			elsif tick_1ms = '1' then
				case alarm_level is
					when 1 =>
                        if beep_count_ms >= 999 then
                            beep_count_ms <= 0;
                        else
                            beep_count_ms <= beep_count_ms + 1;
                        end if;

                    when 2 =>
                        if beep_count_ms >= 499 then
                            beep_count_ms <= 0;
                        else
                            beep_count_ms <= beep_count_ms + 1;
                        end if;

                    when 3 =>
                        if beep_count_ms >= 249 then
                            beep_count_ms <= 0;
                        else
                            beep_count_ms <= beep_count_ms + 1;
                        end if;

                    when 4 =>
                        if beep_count_ms >= 199 then
                            beep_count_ms <= 0;
                        else
                            beep_count_ms <= beep_count_ms + 1;
                        end if;

                    when others =>
                        beep_count_ms <= 0;

                end case;
            end if;
        end if;
	end process;


	beep_gate <= '1' when alarm_level > 0 and beep_count_ms <100
		else '0';

	buzzer_out <=  tone_state when run_en = '1' and beep_gate = '1'
		else '0';

end architecture rtl;