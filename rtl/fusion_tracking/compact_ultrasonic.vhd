library ieee;
use ieee.std_logic_1164.all;

entity compact_ultrasonic is
port (
    clk, rst, start, echo_in : in std_logic;
    trig_out, busy, done, valid : out std_logic;
    echo_time_us : out integer range 0 to 30000
);
end entity;

architecture rtl of compact_ultrasonic is
    type state_type is (IDLE_STATE, TRIGGER_STATE, WAIT_ECHO_STATE,
                        MEASURE_STATE, DONE_STATE);
    signal state : state_type := IDLE_STATE;
    signal echo_meta, echo_sync : std_logic := '0';
    -- Trigger, wait and pulse width are consecutive phases: only one timer
    -- is active. Keep the original 20 us trigger and both 30 ms timeouts.
    signal phase_count : integer range 0 to 30000 := 0;
    signal valid_reg : std_logic := '0';
begin
    trig_out <= '1' when state = TRIGGER_STATE else '0';
    busy <= '0' when state = IDLE_STATE else '1';
    done <= '1' when state = DONE_STATE else '0';
    valid <= valid_reg;
    -- The timer stops at completion and holds through IDLE. Consumers latch
    -- it only when done and valid are high; invalid transactions discard it.
    echo_time_us <= phase_count;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                echo_meta <= '0';
                echo_sync <= '0';
                state <= IDLE_STATE;
                phase_count <= 0;
                valid_reg <= '0';
            else
                echo_meta <= echo_in;
                echo_sync <= echo_meta;
                case state is
                    when IDLE_STATE =>
                        if start = '1' then
                            phase_count <= 0;
                            valid_reg <= '0';
                            state <= TRIGGER_STATE;
                        end if;
                    when TRIGGER_STATE =>
                        if phase_count = 19 then
                            phase_count <= 0;
                            state <= WAIT_ECHO_STATE;
                        else phase_count <= phase_count + 1;
                        end if;
                    when WAIT_ECHO_STATE =>
                        if echo_sync = '1' then
                            phase_count <= 1;
                            state <= MEASURE_STATE;
                        elsif phase_count = 29999 then
                            phase_count <= 0;
                            valid_reg <= '0';
                            state <= DONE_STATE;
                        else phase_count <= phase_count + 1;
                        end if;
                    when MEASURE_STATE =>
                        if echo_sync = '0' then
                            valid_reg <= '1';
                            state <= DONE_STATE;
                        elsif phase_count = 30000 then
                            valid_reg <= '0';
                            state <= DONE_STATE;
                        else phase_count <= phase_count + 1;
                        end if;
                    when DONE_STATE => state <= IDLE_STATE;
                    when others => state <= IDLE_STATE;
                end case;
            end if;
        end if;
    end process;
end architecture;
