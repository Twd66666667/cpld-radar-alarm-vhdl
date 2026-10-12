library ieee;
use ieee.std_logic_1164.all;

entity enhanced_lcd_renderer is
    port(
        self_test_en : in  std_logic;
        standby_en   : in  std_logic;
        run_en       : in  std_logic;
        blink_2hz    : in  std_logic;

        scan_index   : in  integer range 0 to 36;

        level_0      : in  integer range 0 to 5;
        level_45     : in  integer range 0 to 5;
        level_90     : in  integer range 0 to 5;
        level_135    : in  integer range 0 to 5;
        level_180    : in  integer range 0 to 5;

        render_page  : in  integer range 0 to 7;
        render_col   : in  integer range 0 to 127;
        pixel_byte   : out std_logic_vector(7 downto 0)
    );
end entity enhanced_lcd_renderer;

architecture rtl of enhanced_lcd_renderer is

    function bit_mask(bit_index : integer)
        return std_logic_vector is
    begin
        case bit_index is
            when 0      => return "00000001";
            when 1      => return "00000010";
            when 2      => return "00000100";
            when 3      => return "00001000";
            when 4      => return "00010000";
            when 5      => return "00100000";
            when 6      => return "01000000";
            when 7      => return "10000000";
            when others => return "00000000";
        end case;
    end function;

begin

    process(
        self_test_en,
        standby_en,
        run_en,
        blink_2hz,
        scan_index,
        level_0,
        level_45,
        level_90,
        level_135,
        level_180,
        render_page,
        render_col
    )
        variable pixels : std_logic_vector(7 downto 0);
        variable diag_y : integer range 0 to 62;
        variable sweep_x : integer range 0 to 127;
        variable sweep_y : integer range 0 to 63;
    begin
        pixels := (others => '0');
        sweep_x := 118;
        sweep_y := 62;

        -- A moving notch above the angle baseline represents the continuous
        -- scan.  Mapping the 0..36 index directly to one X coordinate is much
        -- smaller than storing 37 pairs of semicircle coordinates, leaving
        -- room for the board's original LED, matrix and seven-segment logic.
        sweep_x := 118 - scan_index * 3;
        sweep_y := 58;

        if self_test_en = '1' then
            if blink_2hz = '1' then
                pixels := (others => '1');
            end if;

        elsif standby_en = '1' or run_en = '1' then
            -- The baseline is shared by the 0- and 180-degree directions.
            if render_page = 7 and
               render_col >= 8 and render_col <= 120 then
                pixels := pixels or "01000000";
            end if;

            -- Vertical 90-degree direction.
            if render_col = 64 then
                case render_page is
                    when 0      => pixels := pixels or "11000000";
                    when 1 to 6 => pixels := (others => '1');
                    when 7      => pixels := pixels or "01111111";
                    when others => null;
                end case;
            end if;

            -- Symmetric 45- and 135-degree directions.
            if render_col >= 8 and render_col <= 120 then
                diag_y := 62 - abs(render_col - 64);
                if render_page = diag_y / 8 then
                    pixels := pixels or bit_mask(diag_y mod 8);
                end if;
            end if;

            if run_en = '1' then
                -- 0 degrees: five distance bands from far to near.
                if render_page = 7 then
                    case level_0 is
                        when 1 => if render_col = 116 then pixels := pixels or x"0E"; end if;
                        when 2 => if render_col = 107 then pixels := pixels or x"0E"; end if;
                        when 3 => if render_col = 98  then pixels := pixels or x"0E"; end if;
                        when 4 => if render_col = 87  then pixels := pixels or x"0E"; end if;
                        when 5 => if render_col = 76  then pixels := pixels or x"0E"; end if;
                        when others => null;
                    end case;

                    case level_180 is
                        when 1 => if render_col = 12 then pixels := pixels or x"0E"; end if;
                        when 2 => if render_col = 21 then pixels := pixels or x"0E"; end if;
                        when 3 => if render_col = 30 then pixels := pixels or x"0E"; end if;
                        when 4 => if render_col = 41 then pixels := pixels or x"0E"; end if;
                        when 5 => if render_col = 52 then pixels := pixels or x"0E"; end if;
                        when others => null;
                    end case;
                end if;

                -- The original marker occupied only column 64 and disappeared
                -- into the vertical scan line.  Share one column-window test
                -- across all five levels to form a visible 3-pixel-wide dot.
                if render_col >= 63 and render_col <= 65 then
                    case level_90 is
                        when 1 =>
                            if render_page = 1 then pixels := pixels or x"0E"; end if;
                        when 2 =>
                            if render_page = 2 then pixels := pixels or x"1C"; end if;
                        when 3 =>
                            if render_page = 3 then pixels := pixels or x"38"; end if;
                        when 4 =>
                            if render_page = 5 then pixels := pixels or x"07"; end if;
                        when 5 =>
                            if render_page = 6 then pixels := pixels or x"0E"; end if;
                        when others => null;
                    end case;
                end if;

                -- 45-degree markers.
                case level_45 is
                    when 1 =>
                        if render_page = 3 and render_col = 101 then pixels := pixels or x"07"; end if;
                    when 2 =>
                        if render_page = 4 and render_col = 93 then pixels := pixels or x"07"; end if;
                    when 3 =>
                        if render_page = 4 and render_col = 88 then pixels := pixels or x"E0"; end if;
                    when 4 =>
                        if render_page = 5 and render_col = 80 then pixels := pixels or x"E0"; end if;
                    when 5 =>
                        if render_page = 6 and render_col = 72 then pixels := pixels or x"E0"; end if;
                    when others => null;
                end case;

                -- 135-degree markers mirror the 45-degree markers.
                case level_135 is
                    when 1 =>
                        if render_page = 3 and render_col = 27 then pixels := pixels or x"07"; end if;
                    when 2 =>
                        if render_page = 4 and render_col = 35 then pixels := pixels or x"07"; end if;
                    when 3 =>
                        if render_page = 4 and render_col = 40 then pixels := pixels or x"E0"; end if;
                    when 4 =>
                        if render_page = 5 and render_col = 48 then pixels := pixels or x"E0"; end if;
                    when 5 =>
                        if render_page = 6 and render_col = 56 then pixels := pixels or x"E0"; end if;
                    when others => null;
                end case;

                -- Moving scan marker.  The five-pixel cross is deliberately
                -- different from the filled obstacle dots, so both remain
                -- visible when they are close together.
                if render_col = sweep_x then
                    if render_page = (sweep_y - 2) / 8 then
                        pixels := pixels or bit_mask((sweep_y - 2) mod 8);
                    end if;
                    if render_page = (sweep_y - 1) / 8 then
                        pixels := pixels or bit_mask((sweep_y - 1) mod 8);
                    end if;
                    if render_page = sweep_y / 8 then
                        pixels := pixels or bit_mask(sweep_y mod 8);
                    end if;
                    if render_page = (sweep_y + 1) / 8 then
                        pixels := pixels or bit_mask((sweep_y + 1) mod 8);
                    end if;
                    if render_page = (sweep_y + 2) / 8 then
                        pixels := pixels or bit_mask((sweep_y + 2) mod 8);
                    end if;
                end if;

                if render_col >= sweep_x - 2 and render_col <= sweep_x + 2 and
                   render_page = sweep_y / 8 then
                    pixels := pixels or bit_mask(sweep_y mod 8);
                end if;
            end if;
        end if;

        pixel_byte <= pixels;
    end process;

end architecture rtl;
