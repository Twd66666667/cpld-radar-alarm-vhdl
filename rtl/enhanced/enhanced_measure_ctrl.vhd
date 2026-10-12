library ieee;
use ieee.std_logic_1164.all;

entity enhanced_measure_ctrl is
port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    run_en      : in  std_logic;
    tick_1ms    : in  std_logic;
    cycle_start : in  std_logic;
    ultra_busy  : in  std_logic;
    ultra_done  : in  std_logic;
    ultra_start : out std_logic;
    servo_quiet : out std_logic
);
end entity enhanced_measure_ctrl;

architecture rtl of enhanced_measure_ctrl is

    type state_type is (
        IDLE_STATE,
        SERVO_DRIVE_STATE,
        QUIET_WAIT_STATE,
        START_STATE,
        WAIT_DONE_STATE,
        WAIT_GAP_STATE,
        WAIT_NEXT_STATE
    );

    signal current_state : state_type := IDLE_STATE;
    signal delay_count   : integer range 0 to 79 := 0;
    signal gap_count     : integer range 0 to 59 := 0;
    signal sample_count  : integer range 0 to 2 := 0;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or run_en = '0' then
                current_state <= IDLE_STATE;
                delay_count   <= 0;
                gap_count     <= 0;
                sample_count  <= 0;
                ultra_start   <= '0';

            else
                ultra_start <= '0';

                case current_state is
                    when IDLE_STATE =>
                        if cycle_start = '1' then
                            delay_count  <= 0;
                            sample_count <= 0;
                            current_state <= SERVO_DRIVE_STATE;
                        end if;

                    when SERVO_DRIVE_STATE =>
                        if tick_1ms = '1' then
                            if delay_count = 79 then
                                delay_count <= 0;
                                current_state <= QUIET_WAIT_STATE;
                            else
                                delay_count <= delay_count + 1;
                            end if;
                        end if;

                    when QUIET_WAIT_STATE =>
                        if tick_1ms = '1' then
                            if delay_count = 49 then
                                delay_count <= 0;
                                current_state <= START_STATE;
                            else
                                delay_count <= delay_count + 1;
                            end if;
                        end if;

                    when START_STATE =>
                        if ultra_busy = '0' then
                            ultra_start <= '1';
                            current_state <= WAIT_DONE_STATE;
                        end if;

                    when WAIT_DONE_STATE =>
                        if ultra_done = '1' then
                            if sample_count = 2 then
                                sample_count <= 0;
                                current_state <= WAIT_NEXT_STATE;
                            else
                                sample_count <= sample_count + 1;
                                gap_count <= 0;
                                current_state <= WAIT_GAP_STATE;
                            end if;
                        end if;

                    when WAIT_GAP_STATE =>
                        if tick_1ms = '1' then
                            if gap_count = 59 then
                                gap_count <= 0;
                                current_state <= START_STATE;
                            else
                                gap_count <= gap_count + 1;
                            end if;
                        end if;

                    when WAIT_NEXT_STATE =>
                        if cycle_start = '1' then
                            delay_count  <= 0;
                            sample_count <= 0;
                            current_state <= SERVO_DRIVE_STATE;
                        end if;

                    when others =>
                        current_state <= IDLE_STATE;
                end case;
            end if;
        end if;
    end process;

    servo_quiet <= '0' when current_state = SERVO_DRIVE_STATE else '1';

end architecture rtl;
