library ieee;
use ieee.std_logic_1164.all;

entity enhanced_lcd_renderer is
port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    self_test_en   : in  std_logic;
    standby_en     : in  std_logic;
    run_en         : in  std_logic;
    blink_2hz      : in  std_logic;
    scan_index     : in  integer range 0 to 36;
    result_done    : in  std_logic;
    distance_mm    : in  integer range 0 to 4000;
    distance_valid : in  std_logic;
    render_page    : in  integer range 0 to 7;
    render_col     : in  integer range 0 to 127;
    pixel_byte     : out std_logic_vector(7 downto 0)
);
end entity enhanced_lcd_renderer;

architecture rtl of enhanced_lcd_renderer is
    type level_array_type is array (0 to 36) of integer range 0 to 5;
    signal level_memory : level_array_type := (others => 0);

    function classify_distance(distance_value : integer; valid_value : std_logic)
        return integer is
    begin
        if valid_value = '0' then return 0;
        elsif distance_value >= 800 then return 1;
        elsif distance_value >= 600 then return 2;
        elsif distance_value >= 400 then return 3;
        elsif distance_value >= 200 then return 4;
        else return 5;
        end if;
    end function;

    function bit_mask(bit_index : integer) return std_logic_vector is
    begin
        case bit_index is
            when 0 => return "00000001";
            when 1 => return "00000010";
            when 2 => return "00000100";
            when 3 => return "00001000";
            when 4 => return "00010000";
            when 5 => return "00100000";
            when 6 => return "01000000";
            when 7 => return "10000000";
            when others => return "00000000";
        end case;
    end function;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or run_en = '0' then
                level_memory <= (others => 0);
            elsif result_done = '1' then
                level_memory(scan_index) <= classify_distance(distance_mm, distance_valid);
            end if;
        end if;
    end process;

    process(self_test_en, standby_en, run_en, blink_2hz,
            scan_index, level_memory, render_page, render_col)
        variable pixels      : std_logic_vector(7 downto 0);
        variable point_level : integer range 0 to 5;
        variable point_y     : integer range 0 to 63;
        variable cursor_x    : integer range 0 to 127;
    begin
        pixels := (others => '0');
        point_level := 0;
        point_y := 12;
        cursor_x := 118 - scan_index * 3;

        if self_test_en = '1' then
            if blink_2hz = '1' then pixels := (others => '1'); end if;
        elsif standby_en = '1' or run_en = '1' then
            -- Five horizontal guide lines represent the five distance bands.
            if render_col >= 8 and render_col <= 120 then
                if render_page = 1 then pixels := pixels or bit_mask(4); end if;
                if render_page = 2 then pixels := pixels or bit_mask(6); end if;
                if render_page = 4 then pixels := pixels or bit_mask(0); end if;
                if render_page = 5 then pixels := pixels or bit_mask(2); end if;
                if render_page = 6 then pixels := pixels or bit_mask(4); end if;
            end if;

            if render_page = 7 and render_col >= 8 and render_col <= 120 then
                pixels := pixels or bit_mask(6);
            end if;

            if run_en = '1' then
                -- Left is 180 degrees; right is 0 degrees. Each angle owns
                -- three adjacent columns so all 37 stored values remain clear.
                case render_col is
                    when   9 to  11 => point_level := level_memory(36);
                    when  12 to  14 => point_level := level_memory(35);
                    when  15 to  17 => point_level := level_memory(34);
                    when  18 to  20 => point_level := level_memory(33);
                    when  21 to  23 => point_level := level_memory(32);
                    when  24 to  26 => point_level := level_memory(31);
                    when  27 to  29 => point_level := level_memory(30);
                    when  30 to  32 => point_level := level_memory(29);
                    when  33 to  35 => point_level := level_memory(28);
                    when  36 to  38 => point_level := level_memory(27);
                    when  39 to  41 => point_level := level_memory(26);
                    when  42 to  44 => point_level := level_memory(25);
                    when  45 to  47 => point_level := level_memory(24);
                    when  48 to  50 => point_level := level_memory(23);
                    when  51 to  53 => point_level := level_memory(22);
                    when  54 to  56 => point_level := level_memory(21);
                    when  57 to  59 => point_level := level_memory(20);
                    when  60 to  62 => point_level := level_memory(19);
                    when  63 to  65 => point_level := level_memory(18);
                    when  66 to  68 => point_level := level_memory(17);
                    when  69 to  71 => point_level := level_memory(16);
                    when  72 to  74 => point_level := level_memory(15);
                    when  75 to  77 => point_level := level_memory(14);
                    when  78 to  80 => point_level := level_memory(13);
                    when  81 to  83 => point_level := level_memory(12);
                    when  84 to  86 => point_level := level_memory(11);
                    when  87 to  89 => point_level := level_memory(10);
                    when  90 to  92 => point_level := level_memory(9);
                    when  93 to  95 => point_level := level_memory(8);
                    when  96 to  98 => point_level := level_memory(7);
                    when  99 to 101 => point_level := level_memory(6);
                    when 102 to 104 => point_level := level_memory(5);
                    when 105 to 107 => point_level := level_memory(4);
                    when 108 to 110 => point_level := level_memory(3);
                    when 111 to 113 => point_level := level_memory(2);
                    when 114 to 116 => point_level := level_memory(1);
                    when 117 to 119 => point_level := level_memory(0);
                    when others => point_level := 0;
                end case;

                case point_level is
                    when 1 => point_y := 12;
                    when 2 => point_y := 22;
                    when 3 => point_y := 32;
                    when 4 => point_y := 42;
                    when 5 => point_y := 52;
                    when others => point_y := 12;
                end case;

                if point_level /= 0 then
                    if render_page = (point_y - 1) / 8 then
                        pixels := pixels or bit_mask((point_y - 1) mod 8);
                    end if;
                    if render_page = point_y / 8 then
                        pixels := pixels or bit_mask(point_y mod 8);
                    end if;
                    if render_page = (point_y + 1) / 8 then
                        pixels := pixels or bit_mask((point_y + 1) mod 8);
                    end if;
                end if;

                if render_col >= cursor_x - 1 and render_col <= cursor_x + 1 and
                   render_page = 0 then
                    pixels := pixels or "01111100";
                end if;
            end if;
        end if;

        pixel_byte <= pixels;
    end process;
end architecture rtl;
