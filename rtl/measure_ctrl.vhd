library ieee;
use ieee.std_logic_1164.all;

entity measure_ctrl is
port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    tick_1ms     : in  std_logic;
    run_en       : in  std_logic;
    tick_250ms   : in  std_logic;
    tick_2s      : in  std_logic;
    ultra_busy   : in  std_logic;
    ultra_done   : in  std_logic;
    ultra_start  : out std_logic;
    servo_quiet  : out std_logic
);
end entity measure_ctrl;

architecture rtl of measure_ctrl is

    type state_type is (
        IDLE_STATE,
        WAIT_SETTLE_STATE,
        QUIET_WAIT_STATE,
        START_STATE,
        WAIT_DONE_STATE,
        WAIT_GAP_STATE,
        WAIT_NEXT_STATE
    );

    signal current_state : state_type := IDLE_STATE;
    signal sample_count  : integer range 0 to 2 := 0;
    signal settle_count  : integer range 0 to 1 := 0;
    signal quiet_count_ms : integer range 0 to 49 := 0;
    signal gap_count_ms  : integer range 0 to 59 := 0;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= IDLE_STATE;
                ultra_start   <= '0';
                sample_count  <= 0;
                settle_count  <= 0;
                quiet_count_ms <= 0;
                gap_count_ms  <= 0;

            else
                -- ultra_start is a one-clock pulse.
                ultra_start <= '0';

                case current_state is
                    when IDLE_STATE =>
                        sample_count <= 0;
                        settle_count <= 0;
                        quiet_count_ms <= 0;
                        gap_count_ms <= 0;

                        if run_en = '1' then
                            current_state <= WAIT_SETTLE_STATE;
                        end if;

                    when WAIT_SETTLE_STATE =>
                        if run_en = '0' then
                            current_state <= IDLE_STATE;

                        elsif tick_250ms = '1' then
                            if settle_count = 1 then
                                settle_count <= 0;
                                quiet_count_ms <= 0;
                                current_state <= QUIET_WAIT_STATE;
                            else
                                settle_count <= settle_count + 1;
                            end if;
                        end if;

                    when QUIET_WAIT_STATE =>
                        if run_en = '0' then
                            current_state <= IDLE_STATE;

                        elsif tick_1ms = '1' then
                            if quiet_count_ms = 49 then
                                quiet_count_ms <= 0;
                                sample_count <= 0;
                                current_state <= START_STATE;
                            else
                                quiet_count_ms <= quiet_count_ms + 1;
                            end if;
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
                            if sample_count = 2 then
                                sample_count <= 0;
                                current_state <= WAIT_NEXT_STATE;
                            else
                                sample_count <= sample_count + 1;
                                gap_count_ms <= 0;
                                current_state <= WAIT_GAP_STATE;
                            end if;
                        end if;

                    when WAIT_GAP_STATE =>
                        if run_en = '0' then
                            current_state <= IDLE_STATE;

                        elsif tick_1ms = '1' then
                            if gap_count_ms = 59 then
                                gap_count_ms <= 0;
                                current_state <= START_STATE;
                            else
                                gap_count_ms <= gap_count_ms + 1;
                            end if;
                        end if;

                    when WAIT_NEXT_STATE =>
                        if run_en = '0' then
                            current_state <= IDLE_STATE;

                        elsif tick_2s = '1' then
                            settle_count <= 0;
                            current_state <= WAIT_SETTLE_STATE;
                        end if;

                    when others =>
                        current_state <= IDLE_STATE;
                end case;
            end if;
        end if;
    end process;

    -- Stop servo PWM before and throughout all three ultrasonic samples.
    -- The servo first receives PWM for 500 ms, then the system waits another
    -- 50 ms after PWM stops so power and ground disturbances can settle.
    servo_quiet <= '1'
        when current_state = QUIET_WAIT_STATE or
             current_state = START_STATE or
             current_state = WAIT_DONE_STATE or
             current_state = WAIT_GAP_STATE
        else '0';

end architecture rtl;
