library ieee;
use ieee.std_logic_1164.all;

entity lcd_bus_writer is
	port(
		clk : in std_logic;
		rst : in std_logic;
		start : in std_logic;
		is_data :in std_logic;
		data_in :in std_logic_vector(7 downto 0);
		
		busy : out std_logic;
		done : out std_logic;
		
		lcd_db : out std_logic_vector(7 downto 0);
		lcd_a0 : out std_logic;
		lcd_wr_n : out std_logic;
		lcd_rd_n : out std_logic;
		lcd_cs_n : out std_logic
	);
end entity lcd_bus_writer;

architecture rtl of lcd_bus_writer is
	type state_type is (
    IDLE_STATE,
    SETUP_STATE,
    WRITE_STATE,
    FINISH_STATE
	);

	signal current_state : state_type := IDLE_STATE;
	signal data_latched    : std_logic_vector(7 downto 0) := (others => '0');
	signal is_data_latched : std_logic := '0';
	
	
begin
	lcd_db   <= data_latched;
	lcd_a0   <= is_data_latched;
	-- Reading is unused. During system reset CS is inactive, so RD may be
	-- held low without selecting the LCD; it returns high in normal work.
	lcd_rd_n <= not rst;

	busy <= '0' when current_state = IDLE_STATE else '1';
	done <= '1' when current_state = FINISH_STATE else '0';

	lcd_cs_n <= '1' when current_state = IDLE_STATE else '0';
	lcd_wr_n <= '0' when current_state = WRITE_STATE else '1';
	
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				current_state   <= IDLE_STATE;
				data_latched    <= (others => '0');
				is_data_latched <= '0';

			else
				case current_state is
					when IDLE_STATE =>
						if start = '1' then
							data_latched    <= data_in;
							is_data_latched <= is_data;
							current_state   <= SETUP_STATE;
						end if;

					when SETUP_STATE =>
						current_state <= WRITE_STATE;

					when WRITE_STATE =>
						current_state <= FINISH_STATE;

					when FINISH_STATE =>
						current_state <= IDLE_STATE;

					when others =>
						current_state <= IDLE_STATE;
				end case;
			end if;
		end if;
	end process;
	
	
	
end architecture rtl;
