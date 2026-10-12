library ieee;
use ieee.std_logic_1164.all;

entity enhanced_dot_matrix_ctrl is
port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    tick_1ms        : in  std_logic;
    blink_2hz       : in  std_logic;
    self_test_en    : in  std_logic;
    standby_en      : in  std_logic;
    run_en          : in  std_logic;
    scan_index      : in  integer range 0 to 36;

    level_0         : in  integer range 0 to 5;
    level_45        : in  integer range 0 to 5;
    level_90        : in  integer range 0 to 5;
    level_135       : in  integer range 0 to 5;
    level_180       : in  integer range 0 to 5;

    matrix_row       : out std_logic_vector(7 downto 0);
    matrix_red_col   : out std_logic_vector(0 to 7);
    matrix_green_col : out std_logic_vector(0 to 7)
);
end entity enhanced_dot_matrix_ctrl;

architecture rtl of enhanced_dot_matrix_ctrl is
    signal scan_row : integer range 0 to 7 := 0;
    signal mix_phase : integer range 0 to 3 := 0;
    signal current_level : integer range 0 to 5 := 0;

    function red_for(level_value : integer; phase_value : integer)
        return std_logic is
    begin
        case level_value is
            when 2 =>
                if phase_value = 0 then return '1'; else return '0'; end if;
            when 3 | 4 | 5 => return '1';
            when others => return '0';
        end case;
    end function;

    function green_for(level_value : integer; phase_value : integer)
        return std_logic is
    begin
        case level_value is
            when 1 | 2 | 3 => return '1';
            when 4 =>
                if phase_value = 0 or phase_value = 1 then
                    return '1';
                else
                    return '0';
                end if;
            when others => return '0';
        end case;
    end function;

begin

    with scan_index select
    current_level <= level_0   when 0,
                     level_45  when 9,
                     level_90  when 18,
                     level_135 when 27,
                     level_180 when 36,
                     0         when others;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                scan_row <= 0;
                mix_phase <= 0;
            else
                if mix_phase = 3 then
                    mix_phase <= 0;
                else
                    mix_phase <= mix_phase + 1;
                end if;

                if tick_1ms = '1' then
                    if scan_row = 7 then
                        scan_row <= 0;
                    else
                        scan_row <= scan_row + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    with scan_row select
    matrix_row <= "11111110" when 0,
                  "11111101" when 1,
                  "11111011" when 2,
                  "11110111" when 3,
                  "11101111" when 4,
                  "11011111" when 5,
                  "10111111" when 6,
                  "01111111" when 7,
                  "11111111" when others;

    process(scan_row, blink_2hz, self_test_en, standby_en, run_en,
            mix_phase, current_level, level_0, level_45, level_90,
            level_135, level_180)
    begin
        matrix_red_col   <= (others => '0');
        matrix_green_col <= (others => '0');

        if self_test_en = '1' then
            if blink_2hz = '1' then
                matrix_red_col   <= (others => '1');
                matrix_green_col <= (others => '1');
            end if;
        elsif standby_en = '1' then
            case scan_row is
                when 3 => matrix_green_col <= "11111110";
                when 4 => matrix_green_col <= "00111000";
                when 5 => matrix_green_col <= "01010100";
                when 6 => matrix_green_col <= "10010010";
                when 7 => matrix_green_col <= "00010000";
                when others => null;
            end case;
        elsif run_en = '1' then
            case scan_row is
                when 3 =>
                    matrix_red_col(0 to 2) <= (others => red_for(level_180, mix_phase));
                    matrix_green_col(0 to 2) <= (others => green_for(level_180, mix_phase));
                    matrix_red_col(3) <= red_for(current_level, mix_phase);
                    matrix_green_col(3) <= green_for(current_level, mix_phase);
                    matrix_red_col(4 to 6) <= (others => red_for(level_0, mix_phase));
                    matrix_green_col(4 to 6) <= (others => green_for(level_0, mix_phase));
                when 4 =>
                    matrix_red_col(2) <= red_for(level_135, mix_phase);
                    matrix_green_col(2) <= green_for(level_135, mix_phase);
                    matrix_red_col(3) <= red_for(level_90, mix_phase);
                    matrix_green_col(3) <= green_for(level_90, mix_phase);
                    matrix_red_col(4) <= red_for(level_45, mix_phase);
                    matrix_green_col(4) <= green_for(level_45, mix_phase);
                when 5 =>
                    matrix_red_col(1) <= red_for(level_135, mix_phase);
                    matrix_green_col(1) <= green_for(level_135, mix_phase);
                    matrix_red_col(3) <= red_for(level_90, mix_phase);
                    matrix_green_col(3) <= green_for(level_90, mix_phase);
                    matrix_red_col(5) <= red_for(level_45, mix_phase);
                    matrix_green_col(5) <= green_for(level_45, mix_phase);
                when 6 =>
                    matrix_red_col(0) <= red_for(level_135, mix_phase);
                    matrix_green_col(0) <= green_for(level_135, mix_phase);
                    matrix_red_col(3) <= red_for(level_90, mix_phase);
                    matrix_green_col(3) <= green_for(level_90, mix_phase);
                    matrix_red_col(6) <= red_for(level_45, mix_phase);
                    matrix_green_col(6) <= green_for(level_45, mix_phase);
                when 7 =>
                    matrix_red_col(3) <= red_for(level_90, mix_phase);
                    matrix_green_col(3) <= green_for(level_90, mix_phase);
                when others => null;
            end case;
        end if;
    end process;

end architecture rtl;
