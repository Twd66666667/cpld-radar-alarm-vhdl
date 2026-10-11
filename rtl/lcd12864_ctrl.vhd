library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd12864_ctrl is
    port(
        clk          : in  std_logic;
        rst          : in  std_logic;
        tick_1ms     : in  std_logic;
        tick_250ms   : in  std_logic;

        pixel_byte   : in  std_logic_vector(7 downto 0);
        render_page  : out integer range 0 to 7;
        render_col   : out integer range 0 to 127;

        init_done    : out std_logic;

        lcd_db       : out std_logic_vector(7 downto 0);
        lcd_a0       : out std_logic;
        lcd_wr_n     : out std_logic;
        lcd_rd_n     : out std_logic;
        lcd_cs_n     : out std_logic;
        lcd_rst_n    : out std_logic
    );
end entity lcd12864_ctrl;

architecture rtl of lcd12864_ctrl is

    type state_type is (
        RESET_LOW_STATE,
        RESET_WAIT_STATE,
        INIT_STATE,
        INIT_WAIT_STATE,
        PAGE_CMD_STATE,
        PAGE_CMD_WAIT_STATE,
        COL_HIGH_STATE,
        COL_HIGH_WAIT_STATE,
        COL_LOW_STATE,
        COL_LOW_WAIT_STATE,
        DATA_STATE,
        DATA_WAIT_STATE,
        READY_STATE
    );

    signal current_state : state_type := RESET_LOW_STATE;

    type init_command_array_type is array (0 to 11) of
        std_logic_vector(7 downto 0);

    constant INIT_COMMANDS : init_command_array_type := (
        x"AE", -- Display OFF
        x"A0", -- ADC normal: columns increase from left to right
        x"C8", -- COM reverse: row 0 is at the top
        x"A2", -- 1/9 LCD bias
        x"2F", -- Enable booster, regulator and follower
        x"24", -- Internal resistor ratio recommended by the module manual
        x"81", -- Enter electronic-volume setting mode
        x"18", -- Initial contrast value; adjust after hardware testing
        x"40", -- Display start line 0
        x"A6", -- Normal display, not inverted
        x"A4", -- Display RAM contents, not all points ON
        x"AF"  -- Display ON
    );

    signal init_index : integer range 0 to 11 := 0;
    signal page_index : integer range 0 to 7 := 0;
    signal column_index : integer range 0 to 127 := 0;

    signal writer_start   : std_logic := '0';
    signal writer_is_data : std_logic := '0';
    signal writer_data    : std_logic_vector(7 downto 0) := (others => '0');
    signal writer_busy    : std_logic;
    signal writer_done    : std_logic;

begin

    render_page <= page_index;
    render_col  <= column_index;

    u_lcd_bus_writer : entity work.lcd_bus_writer
    port map(
        clk      => clk,
        rst      => rst,
        start    => writer_start,
        is_data  => writer_is_data,
        data_in  => writer_data,

        busy     => writer_busy,
        done     => writer_done,

        lcd_db   => lcd_db,
        lcd_a0   => lcd_a0,
        lcd_wr_n => lcd_wr_n,
        lcd_rd_n => lcd_rd_n,
        lcd_cs_n => lcd_cs_n
    );

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state   <= RESET_LOW_STATE;
                writer_start    <= '0';
                writer_is_data  <= '0';
                writer_data     <= (others => '0');
                init_done       <= '0';
                init_index      <= 0;
                page_index      <= 0;
                column_index    <= 0;
                lcd_rst_n       <= '0';

            else
                -- start只作为一个时钟周期的写请求脉冲使用。
                writer_start <= '0';

                case current_state is
                    when RESET_LOW_STATE =>
                        lcd_rst_n <= '0';
                        init_done <= '0';

                        if tick_1ms = '1' then
                            lcd_rst_n     <= '1';
                            current_state <= RESET_WAIT_STATE;
                        end if;

                    when RESET_WAIT_STATE =>
                        lcd_rst_n <= '1';

                        if tick_1ms = '1' then
                            current_state <= INIT_STATE;
                        end if;

                    when INIT_STATE =>
                        lcd_rst_n <= '1';
                        init_done <= '0';

                        if writer_busy = '0' then
                            writer_data    <= INIT_COMMANDS(init_index);
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= INIT_WAIT_STATE;
                        end if;

                    when INIT_WAIT_STATE =>
                        lcd_rst_n <= '1';

                        if writer_done = '1' then
                            if init_index = 11 then
                                init_done      <= '1';
                                page_index     <= 0;
                                column_index   <= 0;
                                current_state <= PAGE_CMD_STATE;
                            else
                                init_index     <= init_index + 1;
                                current_state  <= INIT_STATE;
                            end if;
                        end if;

                    when PAGE_CMD_STATE =>
                        if writer_busy = '0' then
                            writer_data    <= "10110" &
                                              std_logic_vector(to_unsigned(page_index, 3));
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= PAGE_CMD_WAIT_STATE;
                        end if;

                    when PAGE_CMD_WAIT_STATE =>
                        if writer_done = '1' then
                            current_state <= COL_HIGH_STATE;
                        end if;

                    when COL_HIGH_STATE =>
                        if writer_busy = '0' then
                            writer_data    <= x"10";
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= COL_HIGH_WAIT_STATE;
                        end if;

                    when COL_HIGH_WAIT_STATE =>
                        if writer_done = '1' then
                            current_state <= COL_LOW_STATE;
                        end if;

                    when COL_LOW_STATE =>
                        if writer_busy = '0' then
                            writer_data    <= x"00";
                            writer_is_data <= '0';
                            writer_start   <= '1';
                            current_state  <= COL_LOW_WAIT_STATE;
                        end if;

                    when COL_LOW_WAIT_STATE =>
                        if writer_done = '1' then
                            column_index   <= 0;
                            current_state  <= DATA_STATE;
                        end if;

                    when DATA_STATE =>
                        if writer_busy = '0' then
                            writer_data    <= pixel_byte;
                            writer_is_data <= '1';
                            writer_start   <= '1';
                            current_state  <= DATA_WAIT_STATE;
                        end if;

                    when DATA_WAIT_STATE =>
                        if writer_done = '1' then
                            if column_index = 127 then
                                column_index <= 0;

                                if page_index = 7 then
                                    page_index     <= 0;
                                    current_state <= READY_STATE;
                                else
                                    page_index     <= page_index + 1;
                                    current_state <= PAGE_CMD_STATE;
                                end if;
                            else
                                column_index   <= column_index + 1;
                                current_state  <= DATA_STATE;
                            end if;
                        end if;

                    when READY_STATE =>
                        lcd_rst_n <= '1';
                        init_done <= '1';

                        if tick_250ms = '1' then
                            page_index     <= 0;
                            column_index   <= 0;
                            current_state <= PAGE_CMD_STATE;
                        end if;

                    when others =>
                        current_state <= RESET_LOW_STATE;
                        lcd_rst_n     <= '0';
                        init_done     <= '0';
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
