library ieee;
use ieee.std_logic_1164.all;

entity seg_display_ctrl is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    tick_1ms       : in  std_logic;
    blink_2hz      : in  std_logic;

    self_test_en   : in  std_logic;
    standby_en     : in  std_logic;
    run_en         : in  std_logic;

    angle_deg      : in  integer range 0 to 180;
    distance_1000  : in  integer range 0 to 9;
    distance_100   : in  integer range 0 to 9;
    distance_10    : in  integer range 0 to 9;
    distance_1     : in  integer range 0 to 9;
    distance_valid : in  std_logic;

    seg            : out std_logic_vector(6 downto 0);
    cat            : out std_logic_vector(7 downto 0)
);
end entity seg_display_ctrl;

architecture rtl of seg_display_ctrl is

    signal scan_index  : integer range 0 to 7 := 0;
    signal digit_value : integer range 0 to 11 := 11;

    signal angle_100 : integer range 0 to 9 := 0;
    signal angle_10  : integer range 0 to 9 := 0;
    signal angle_1   : integer range 0 to 9 := 0;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                scan_index <= 0;
            elsif tick_1ms = '1' then
                if scan_index = 7 then
                    scan_index <= 0;
                else
                    scan_index <= scan_index + 1;
                end if;
            end if;
        end if;
    end process;

    with scan_index select
        cat <= "11111110" when 0,
               "11111101" when 1,
               "11111011" when 2,
               "11110111" when 3,
               "11101111" when 4,
               "11011111" when 5,
               "10111111" when 6,
               "01111111" when 7,
               "11111111" when others;

    process(angle_deg)
    begin
        angle_100 <= 0;
        angle_10  <= 0;
        angle_1   <= 0;

        case angle_deg is
            when 0 =>
                angle_100 <= 0;
                angle_10  <= 0;
                angle_1   <= 0;
            when 45 =>
                angle_100 <= 0;
                angle_10  <= 4;
                angle_1   <= 5;
            when 90 =>
                angle_100 <= 0;
                angle_10  <= 9;
                angle_1   <= 0;
            when 135 =>
                angle_100 <= 1;
                angle_10  <= 3;
                angle_1   <= 5;
            when 180 =>
                angle_100 <= 1;
                angle_10  <= 8;
                angle_1   <= 0;
            when others =>
                angle_100 <= 0;
                angle_10  <= 0;
                angle_1   <= 0;
        end case;
    end process;

    process(
        rst,
        scan_index,
        self_test_en,
        standby_en,
        run_en,
        blink_2hz,
        angle_100,
        angle_10,
        angle_1,
        distance_1000,
        distance_100,
        distance_10,
        distance_1,
        distance_valid
    )
    begin
        digit_value <= 11;

        if rst = '1' then
            digit_value <= 11;

        elsif self_test_en = '1' then
            if blink_2hz = '1' then
                digit_value <= 8;
            else
                digit_value <= 11;
            end if;

        elsif standby_en = '1' then
            case scan_index is
                when 7 | 6 | 5 =>
                    digit_value <= 0;
                when 4 =>
                    digit_value <= 11;
                when 3 | 2 | 1 | 0 =>
                    digit_value <= 10;
                when others =>
                    digit_value <= 11;
            end case;

        elsif run_en = '1' then
            case scan_index is
                when 7 =>
                    digit_value <= angle_100;
                when 6 =>
                    digit_value <= angle_10;
                when 5 =>
                    digit_value <= angle_1;
                when 4 =>
                    digit_value <= 11;
                when 3 =>
                    if distance_valid = '1' then
                        digit_value <= distance_1000;
                    else
                        digit_value <= 10;
                    end if;
                when 2 =>
                    if distance_valid = '1' then
                        digit_value <= distance_100;
                    else
                        digit_value <= 10;
                    end if;
                when 1 =>
                    if distance_valid = '1' then
                        digit_value <= distance_10;
                    else
                        digit_value <= 10;
                    end if;
                when 0 =>
                    if distance_valid = '1' then
                        digit_value <= distance_1;
                    else
                        digit_value <= 10;
                    end if;
                when others =>
                    digit_value <= 11;
            end case;
        end if;
    end process;

    u_seg7_decoder : entity work.seg7_decoder
    port map (
        value => digit_value,
        seg   => seg
    );

end architecture rtl;
