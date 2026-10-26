library ieee;
use ieee.std_logic_1164.all;

entity fusion_tracking_ctrl is
port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    run_en          : in  std_logic;
    enhanced_mode   : in  std_logic;
    tracking_mode   : in  std_logic;
    tick_1ms        : in  std_logic;
    tick_2s         : in  std_logic;
    result_done     : in  std_logic;
    result_valid    : in  std_logic;
    distance_mm     : in  integer range 0 to 4000;
    scan_index      : out integer range 0 to 36;
    basic_angle_deg : out integer range 0 to 180;
    angle_changed   : out std_logic;
    target_index    : out integer range 0 to 36;
    target_valid    : out std_logic;
    mode_code       : out integer range 0 to 2;
    cycle_start     : out std_logic
);
end entity fusion_tracking_ctrl;

architecture rtl of fusion_tracking_ctrl is
    -- mode_code: 0 = global search, 1 = locked, 2 = local recovery.
    type phase_type is (
        GLOBAL_PHASE, CONFIRM_ACQUIRE_PHASE,
        LOCAL_CENTER_PHASE, LOCAL_LEFT_PHASE, LOCAL_RIGHT_PHASE,
        DECIDE_LOCAL_PHASE, RECOVERY_SETUP_PHASE, RECOVERY_PHASE,
        CONFIRM_RECOVERY_PHASE
    );

    signal phase            : phase_type := GLOBAL_PHASE;
    signal scan_reg         : integer range 0 to 36 := 0;
    signal next_index       : integer range 0 to 36 := 0;
    signal target_reg       : integer range 0 to 36 := 0;
    signal target_valid_reg : std_logic := '0';
    signal mode_reg         : integer range 0 to 2 := 0;
    signal cycle_start_reg  : std_logic := '0';
    signal waiting_result   : std_logic := '0';
    signal elapsed_ms       : integer range 0 to 649 := 0;
    signal run_en_d         : std_logic := '0';
    signal global_up        : std_logic := '1';

    signal center_hit       : std_logic := '0';
    signal left_hit         : std_logic := '0';
    signal right_hit        : std_logic := '0';
    signal recovery_step    : integer range 0 to 10 := 0;

    function recovery_delta(step_value : integer) return integer is
    begin
        case step_value is
            when 0 => return -2;
            when 1 => return  2;
            when 2 => return -3;
            when 3 => return  3;
            when 4 => return -4;
            when 5 => return  4;
            when 6 => return -5;
            when 7 => return  5;
            when 8 => return -6;
            when 9 => return  6;
            when others => return 0;
        end case;
    end function;

begin
    scan_index   <= scan_reg;
    target_index <= target_reg;
    target_valid <= target_valid_reg;
    mode_code    <= mode_reg;
    cycle_start  <= cycle_start_reg;
    with scan_reg select basic_angle_deg <=
        0 when 0, 45 when 9, 90 when 18,
        135 when 27, 180 when 36, 0 when others;

    process(clk)
        variable candidate : integer range -6 to 42;
    begin
        if rising_edge(clk) then
            if rst = '1' or run_en = '0' then
                phase            <= GLOBAL_PHASE;
                scan_reg         <= 0;
                next_index       <= 0;
                target_valid_reg <= '0';
                mode_reg         <= 0;
                cycle_start_reg  <= '0';
                angle_changed    <= '0';
                waiting_result   <= '0';
                elapsed_ms       <= 0;
                run_en_d         <= '0';
                global_up        <= '1';
            else
                run_en_d <= run_en;
                cycle_start_reg <= '0';
                angle_changed <= '0';

                if run_en_d = '0' then
                    elapsed_ms <= 0;
                    cycle_start_reg <= '1';
                    waiting_result <= tracking_mode;
                elsif tracking_mode = '0' then
                    -- Normal scans and tracking are mutually exclusive. Reuse
                    -- this angle, direction and timer instead of two engines.
                    if enhanced_mode = '1' and tick_1ms = '1' then
                        if elapsed_ms = 649 then elapsed_ms <= 0;
                        else elapsed_ms <= elapsed_ms + 1;
                        end if;
                    end if;
                    if (enhanced_mode = '0' and tick_2s = '1') or
                       (enhanced_mode = '1' and tick_1ms = '1' and elapsed_ms = 649) then
                        cycle_start_reg <= '1';
                        angle_changed <= '1';
                        if enhanced_mode = '0' then
                            if global_up = '1' then
                                if scan_reg = 36 then
                                    scan_reg <= 27;
                                    global_up <= '0';
                                else scan_reg <= scan_reg + 9;
                                end if;
                            else
                                if scan_reg = 0 then
                                    scan_reg <= 9;
                                    global_up <= '1';
                                else scan_reg <= scan_reg - 9;
                                end if;
                            end if;
                        elsif global_up = '1' then
                            if scan_reg = 36 then
                                scan_reg <= 35;
                                global_up <= '0';
                            else scan_reg <= scan_reg + 1;
                            end if;
                        else
                            if scan_reg = 0 then
                                scan_reg <= 1;
                                global_up <= '1';
                            else scan_reg <= scan_reg - 1;
                            end if;
                        end if;
                    end if;
                else
                if tick_1ms = '1' and elapsed_ms < 500 then
                    elapsed_ms <= elapsed_ms + 1;
                end if;

                if waiting_result = '1' then
                    if result_done = '1' then
                        waiting_result <= '0';

                        case phase is
                            when GLOBAL_PHASE =>
                                if result_valid = '1' and distance_mm <= 100 then
                                    -- A second measurement at the same angle
                                    -- rejects an isolated close echo.
                                    phase <= CONFIRM_ACQUIRE_PHASE;
                                elsif global_up = '1' then
                                    if scan_reg = 36 then
                                        next_index <= 35;
                                        global_up <= '0';
                                    else
                                        next_index <= scan_reg + 1;
                                    end if;
                                else
                                    if scan_reg = 0 then
                                        next_index <= 1;
                                        global_up <= '1';
                                    else
                                        next_index <= scan_reg - 1;
                                    end if;
                                end if;

                            when CONFIRM_ACQUIRE_PHASE =>
                                if result_valid = '1' and distance_mm <= 100 then
                                    target_reg       <= scan_reg;
                                    target_valid_reg <= '1';
                                    mode_reg         <= 1;
                                    phase            <= LOCAL_CENTER_PHASE;
                                else
                                    phase <= GLOBAL_PHASE;
                                    if global_up = '1' then
                                        if scan_reg = 36 then
                                            next_index <= 35;
                                            global_up <= '0';
                                        else
                                            next_index <= scan_reg + 1;
                                        end if;
                                    else
                                        if scan_reg = 0 then
                                            next_index <= 1;
                                            global_up <= '1';
                                        else
                                            next_index <= scan_reg - 1;
                                        end if;
                                    end if;
                                end if;

                            when LOCAL_CENTER_PHASE =>
                                center_hit <= '0';
                                left_hit   <= '0';
                                right_hit  <= '0';
                                if result_valid = '1' and distance_mm <= 120 then
                                    center_hit <= '1';
                                end if;
                                if target_reg > 0 then
                                    next_index <= target_reg - 1;
                                    phase    <= LOCAL_LEFT_PHASE;
                                elsif target_reg < 36 then
                                    next_index <= target_reg + 1;
                                    phase    <= LOCAL_RIGHT_PHASE;
                                else
                                    phase <= DECIDE_LOCAL_PHASE;
                                end if;

                            when LOCAL_LEFT_PHASE =>
                                if result_valid = '1' and distance_mm <= 120 then
                                    left_hit <= '1';
                                else
                                    left_hit <= '0';
                                end if;
                                if target_reg < 36 then
                                    next_index <= target_reg + 1;
                                    phase    <= LOCAL_RIGHT_PHASE;
                                else
                                    phase <= DECIDE_LOCAL_PHASE;
                                end if;

                            when LOCAL_RIGHT_PHASE =>
                                if result_valid = '1' and distance_mm <= 120 then
                                    right_hit <= '1';
                                else
                                    right_hit <= '0';
                                end if;
                                phase <= DECIDE_LOCAL_PHASE;

                            when RECOVERY_PHASE =>
                                if result_valid = '1' and distance_mm <= 120 then
                                    phase <= CONFIRM_RECOVERY_PHASE;
                                else
                                    recovery_step <= recovery_step + 1;
                                    phase <= RECOVERY_SETUP_PHASE;
                                end if;

                            when CONFIRM_RECOVERY_PHASE =>
                                if result_valid = '1' and distance_mm <= 120 then
                                    target_reg      <= scan_reg;
                                    mode_reg        <= 1;
                                    phase           <= LOCAL_CENTER_PHASE;
                                else
                                    recovery_step <= recovery_step + 1;
                                    phase <= RECOVERY_SETUP_PHASE;
                                end if;

                            when others =>
                                phase <= GLOBAL_PHASE;
                        end case;
                    end if;

                elsif phase = DECIDE_LOCAL_PHASE then
                    -- If both sides respond, keep the old center.  Ultrasonic
                    -- distance alone cannot identify two separate objects.
                    if center_hit = '0' and left_hit = '0' and
                       right_hit = '0' then
                        mode_reg      <= 2;
                        recovery_step <= 0;
                        phase         <= RECOVERY_SETUP_PHASE;
                    else
                        if left_hit = '1' and right_hit = '0' then
                            target_reg      <= target_reg - 1;
                            next_index      <= target_reg - 1;
                        elsif right_hit = '1' and left_hit = '0' then
                            target_reg      <= target_reg + 1;
                            next_index      <= target_reg + 1;
                        else
                            next_index <= target_reg;
                        end if;
                        phase <= LOCAL_CENTER_PHASE;
                    end if;

                elsif phase = RECOVERY_SETUP_PHASE then
                    if recovery_step = 10 then
                        -- Resume the sweep from the current physical angle.
                        target_valid_reg <= '0';
                        mode_reg         <= 0;
                        phase            <= GLOBAL_PHASE;
                        if global_up = '1' then
                            if scan_reg = 36 then
                                next_index <= 35;
                                global_up <= '0';
                            else
                                next_index <= scan_reg + 1;
                            end if;
                        else
                            if scan_reg = 0 then
                                next_index <= 1;
                                global_up <= '1';
                            else
                                next_index <= scan_reg - 1;
                            end if;
                        end if;
                    else
                        candidate := target_reg + recovery_delta(recovery_step);
                        if candidate >= 0 and candidate <= 36 then
                            next_index <= candidate;
                            phase    <= RECOVERY_PHASE;
                        else
                            recovery_step <= recovery_step + 1;
                        end if;
                    end if;

                elsif elapsed_ms = 500 then
                    -- The tracker never changes angle while a result is in
                    -- flight.  The measurement controller owns PWM quiet time.
                    scan_reg        <= next_index;
                    if scan_reg /= next_index then angle_changed <= '1'; end if;
                    cycle_start_reg <= '1';
                    elapsed_ms      <= 0;
                    waiting_result  <= '1';
                end if;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
