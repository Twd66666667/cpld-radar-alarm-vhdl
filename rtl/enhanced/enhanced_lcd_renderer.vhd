library ieee;
use ieee.std_logic_1164.all;

entity enhanced_lcd_renderer is
    port(
        self_test_en : in  std_logic;
        standby_en   : in  std_logic;
        run_en       : in  std_logic;
        blink_2hz    : in  std_logic;

        angle_deg    : in  integer range 0 to 180;

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
        angle_deg,
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

        -- Convert the 5-degree mechanical angle into a point on the outer
        -- semicircle.  A lookup table avoids multipliers and trigonometric
        -- calculations in the CPLD.
        case angle_deg is
            when   0 => sweep_x := 118; sweep_y := 62;
            when   5 => sweep_x := 118; sweep_y := 57;
            when  10 => sweep_x := 117; sweep_y := 53;
            when  15 => sweep_x := 116; sweep_y := 48;
            when  20 => sweep_x := 115; sweep_y := 44;
            when  25 => sweep_x := 113; sweep_y := 39;
            when  30 => sweep_x := 111; sweep_y := 35;
            when  35 => sweep_x := 108; sweep_y := 31;
            when  40 => sweep_x := 105; sweep_y := 27;
            when  45 => sweep_x := 102; sweep_y := 24;
            when  50 => sweep_x :=  99; sweep_y := 21;
            when  55 => sweep_x :=  95; sweep_y := 18;
            when  60 => sweep_x :=  91; sweep_y := 15;
            when  65 => sweep_x :=  87; sweep_y := 13;
            when  70 => sweep_x :=  82; sweep_y := 11;
            when  75 => sweep_x :=  78; sweep_y := 10;
            when  80 => sweep_x :=  73; sweep_y :=  9;
            when  85 => sweep_x :=  69; sweep_y :=  8;
            when  90 => sweep_x :=  64; sweep_y :=  8;
            when  95 => sweep_x :=  59; sweep_y :=  8;
            when 100 => sweep_x :=  55; sweep_y :=  9;
            when 105 => sweep_x :=  50; sweep_y := 10;
            when 110 => sweep_x :=  46; sweep_y := 11;
            when 115 => sweep_x :=  41; sweep_y := 13;
            when 120 => sweep_x :=  37; sweep_y := 15;
            when 125 => sweep_x :=  33; sweep_y := 18;
            when 130 => sweep_x :=  29; sweep_y := 21;
            when 135 => sweep_x :=  26; sweep_y := 24;
            when 140 => sweep_x :=  23; sweep_y := 27;
            when 145 => sweep_x :=  20; sweep_y := 31;
            when 150 => sweep_x :=  17; sweep_y := 35;
            when 155 => sweep_x :=  15; sweep_y := 39;
            when 160 => sweep_x :=  13; sweep_y := 44;
            when 165 => sweep_x :=  12; sweep_y := 48;
            when 170 => sweep_x :=  11; sweep_y := 53;
            when 175 => sweep_x :=  10; sweep_y := 57;
            when 180 => sweep_x :=  10; sweep_y := 62;
            when others => null;
        end case;

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
