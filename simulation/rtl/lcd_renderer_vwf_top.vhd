library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Selects representative LCD coordinates so the combinational renderer can
-- be checked in VWF without attempting to display all 1024 frame bytes.
entity lcd_renderer_vwf_top is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        next_case       : in  std_logic;
        case_u4         : out std_logic_vector(3 downto 0);
        render_page_u3  : out std_logic_vector(2 downto 0);
        render_col_u7   : out std_logic_vector(6 downto 0);
        pixel_byte      : out std_logic_vector(7 downto 0)
    );
end entity lcd_renderer_vwf_top;

architecture structural of lcd_renderer_vwf_top is
    signal case_s : integer range 0 to 7 := 0;
    signal self_test_s : std_logic := '0';
    signal standby_s   : std_logic := '0';
    signal run_s       : std_logic := '0';
    signal blink_s     : std_logic := '0';
    signal level_0_s   : integer range 0 to 5 := 0;
    signal level_45_s  : integer range 0 to 5 := 0;
    signal level_90_s  : integer range 0 to 5 := 0;
    signal level_135_s : integer range 0 to 5 := 0;
    signal level_180_s : integer range 0 to 5 := 0;
    signal page_s      : integer range 0 to 7 := 0;
    signal col_s       : integer range 0 to 127 := 0;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                case_s <= 0;
            elsif next_case = '1' then
                if case_s = 7 then
                    case_s <= 0;
                else
                    case_s <= case_s + 1;
                end if;
            end if;
        end if;
    end process;

    process(case_s)
    begin
        self_test_s <= '0';
        standby_s   <= '0';
        run_s       <= '0';
        blink_s     <= '0';
        level_0_s   <= 0;
        level_45_s  <= 0;
        level_90_s  <= 0;
        level_135_s <= 0;
        level_180_s <= 0;
        page_s      <= 0;
        col_s       <= 0;

        case case_s is
            when 0 =>
                -- Self-test fill: expected FFh.
                self_test_s <= '1';
                blink_s     <= '1';

            when 1 =>
                -- Horizontal baseline: expected bit 6 = 40h.
                standby_s <= '1';
                page_s    <= 7;
                col_s     <= 20;

            when 2 =>
                -- Vertical 90-degree line: expected FFh.
                standby_s <= '1';
                page_s    <= 3;
                col_s     <= 64;

            when 3 =>
                -- 45-degree scan line: expected 40h.
                standby_s <= '1';
                page_s    <= 5;
                col_s     <= 80;

            when 4 =>
                -- Three-column 90-degree marker beside the vertical line.
                run_s      <= '1';
                level_90_s <= 3;
                page_s     <= 3;
                col_s      <= 63;

            when 5 =>
                -- 45-degree level-3 obstacle marker: expected E0h.
                run_s      <= '1';
                level_45_s <= 3;
                page_s     <= 4;
                col_s      <= 88;

            when 6 =>
                -- Mirrored 135-degree level-3 marker: expected E0h.
                run_s       <= '1';
                level_135_s <= 3;
                page_s      <= 4;
                col_s       <= 40;

            when others =>
                -- Off state: expected 00h.
                null;
        end case;
    end process;

    u_dut : entity work.lcd_radar_renderer
        port map (
            self_test_en => self_test_s,
            standby_en   => standby_s,
            run_en       => run_s,
            blink_2hz    => blink_s,
            level_0      => level_0_s,
            level_45     => level_45_s,
            level_90     => level_90_s,
            level_135    => level_135_s,
            level_180    => level_180_s,
            render_page  => page_s,
            render_col   => col_s,
            pixel_byte   => pixel_byte
        );

    case_u4        <= std_logic_vector(to_unsigned(case_s, 4));
    render_page_u3 <= std_logic_vector(to_unsigned(page_s, 3));
    render_col_u7  <= std_logic_vector(to_unsigned(col_s, 7));
end architecture structural;
