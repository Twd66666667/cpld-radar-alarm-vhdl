library ieee;
use ieee.std_logic_1164.all;

entity fusion_matrix is
port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    tick_1ms        : in  std_logic;
    run_en          : in  std_logic;
    angle_deg       : in  integer range 0 to 180;

    level_0   : in integer range 0 to 5;
    level_45  : in integer range 0 to 5;
    level_90  : in integer range 0 to 5;
    level_135 : in integer range 0 to 5;
    level_180 : in integer range 0 to 5;

    blink_2hz    : in std_logic;
	self_test_en : in std_logic;
	standby_en   : in std_logic;

    matrix_row       : out std_logic_vector(7 downto 0);
    matrix_red_col   : out std_logic_vector(0 to 7);
    matrix_green_col : out std_logic_vector(0 to 7)
);
end entity fusion_matrix;

architecture rtl of fusion_matrix is
	signal scan_row : integer range 0 to 7 := 0;
	
	subtype color_code_type is integer range 0 to 5;

	constant COLOR_OFF          : color_code_type := 0;
	constant COLOR_GREEN        : color_code_type := 1;
	constant COLOR_YELLOW_GREEN : color_code_type := 2;
	constant COLOR_YELLOW       : color_code_type := 3;
	constant COLOR_ORANGE       : color_code_type := 4;
	constant COLOR_RED          : color_code_type := 5;

	signal color_0   : color_code_type := COLOR_OFF;
	signal color_45  : color_code_type := COLOR_OFF;
	signal color_90  : color_code_type := COLOR_OFF;
	signal color_135 : color_code_type := COLOR_OFF;
	signal color_180 : color_code_type := COLOR_OFF;
	
	subtype mix_phase_type is integer range 0 to 3;
	signal mix_phase : mix_phase_type := 0;
	
	signal current_color : color_code_type := COLOR_OFF;
	
	function get_red_level(
	color_code : color_code_type;
	phase_value : mix_phase_type	
	) return std_logic is
	begin
		case color_code is
			when COLOR_YELLOW_GREEN =>
				if phase_value = 0 then
					return '1';
				else
					return '0';
				end if ;
			
			when COLOR_YELLOW|COLOR_ORANGE| COLOR_RED =>
				return '1';
			
			when others =>
				return '0';
		end case;
	end function;
				
	function get_green_level(
    color_code  : color_code_type;
    phase_value : mix_phase_type
	) return std_logic is
	begin
		case color_code is
			when COLOR_GREEN | COLOR_YELLOW_GREEN | COLOR_YELLOW =>
				return '1';

			when COLOR_ORANGE =>
				-- Red stays fully on while green uses a 50% duty cycle.
				-- This keeps orange distinct from both pure red and yellow.
				if phase_value = 0 or phase_value = 1 then
					return '1';
				else
					return '0';
				end if;

			when others =>
				return '0';
		end case;
	end function;	
	
		
begin

	with angle_deg select
	current_color <=
		color_0   when 0,
		color_45  when 45,
		color_90  when 90,
		color_135 when 135,
		color_180 when 180,
		COLOR_OFF when others;
	
	color_0 <= level_0;

	color_45 <= level_45;

	color_90 <= level_90;

	color_135 <= level_135;

	color_180 <= level_180;
	
	
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

				if tick_1ms ='1' then
					if scan_row = 7 then
						scan_row <= 0;
					else
						scan_row <= scan_row +1;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	with scan_row select
	matrix_row <=
		"11111110" when 0,
		"11111101" when 1,
		"11111011" when 2,
		"11110111" when 3,
		"11101111" when 4,
		"11011111" when 5,
		"10111111" when 6,
		"01111111" when 7,
		"11111111" when others;
	
	
	process(scan_row, blink_2hz, self_test_en, standby_en, run_en,
			mix_phase,
			current_color,
			color_0,
			color_45,
			color_90,
			color_135,
			color_180)
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
				when 0 =>
					matrix_green_col <= "00000000";

				when 1 =>
					matrix_green_col <= "00000000";

				when 2 =>
					matrix_green_col <= "00000000";

				when 3 =>
					matrix_green_col <= "11111110";

				when 4 =>
					matrix_green_col <= "00111000";

				when 5 =>
					matrix_green_col <= "01010100";

				when 6 =>
					matrix_green_col <= "10010010";

				when 7 =>
					matrix_green_col <= "00010000";

				when others =>
					matrix_green_col <= (others => '0');
			end case;

		elsif run_en = '1' then
			case scan_row is
        -- 最下面三行没有图案，保持默认熄灭
        when 0 | 1 | 2 =>
            null;

        -- 水平线：左边180°，中心为当前角度，右边0°
        when 3 =>
            matrix_red_col(0 to 2) <=
                (others => get_red_level(color_180, mix_phase));

            matrix_green_col(0 to 2) <=
                (others => get_green_level(color_180, mix_phase));

            matrix_red_col(3) <=
                get_red_level(current_color, mix_phase);

            matrix_green_col(3) <=
                get_green_level(current_color, mix_phase);

            matrix_red_col(4 to 6) <=
                (others => get_red_level(color_0, mix_phase));

            matrix_green_col(4 to 6) <=
                (others => get_green_level(color_0, mix_phase));

        -- 135°、90°、45°
        when 4 =>
            matrix_red_col(2) <=
                get_red_level(color_135, mix_phase);
            matrix_green_col(2) <=
                get_green_level(color_135, mix_phase);

            matrix_red_col(3) <=
                get_red_level(color_90, mix_phase);
            matrix_green_col(3) <=
                get_green_level(color_90, mix_phase);

            matrix_red_col(4) <=
                get_red_level(color_45, mix_phase);
            matrix_green_col(4) <=
                get_green_level(color_45, mix_phase);

        when 5 =>
            matrix_red_col(1) <=
                get_red_level(color_135, mix_phase);
            matrix_green_col(1) <=
                get_green_level(color_135, mix_phase);

            matrix_red_col(3) <=
                get_red_level(color_90, mix_phase);
            matrix_green_col(3) <=
                get_green_level(color_90, mix_phase);

            matrix_red_col(5) <=
                get_red_level(color_45, mix_phase);
            matrix_green_col(5) <=
                get_green_level(color_45, mix_phase);

        when 6 =>
            matrix_red_col(0) <=
                get_red_level(color_135, mix_phase);
            matrix_green_col(0) <=
                get_green_level(color_135, mix_phase);

            matrix_red_col(3) <=
                get_red_level(color_90, mix_phase);
            matrix_green_col(3) <=
                get_green_level(color_90, mix_phase);

            matrix_red_col(6) <=
                get_red_level(color_45, mix_phase);
            matrix_green_col(6) <=
                get_green_level(color_45, mix_phase);

        -- 最上方只有90°线
        when 7 =>
            matrix_red_col(3) <=
                get_red_level(color_90, mix_phase);
            matrix_green_col(3) <=
                get_green_level(color_90, mix_phase);

        when others =>
            null;
    end case;
		end if;
	end process;
end architecture rtl;
