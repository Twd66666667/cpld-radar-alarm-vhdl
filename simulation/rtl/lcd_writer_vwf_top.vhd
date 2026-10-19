library ieee;
use ieee.std_logic_1164.all;

entity lcd_writer_vwf_top is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        start        : in  std_logic;
        is_data      : in  std_logic;
        select_data  : in  std_logic;
        busy         : out std_logic;
        done         : out std_logic;
        lcd_db       : out std_logic_vector(7 downto 0);
        lcd_a0       : out std_logic;
        lcd_we_n     : out std_logic;
        lcd_rd_n     : out std_logic;
        lcd_cs_n     : out std_logic
    );
end entity lcd_writer_vwf_top;

architecture structural of lcd_writer_vwf_top is
    signal data_s : std_logic_vector(7 downto 0);
begin
    -- Command example AEh; display-data example A5h.
    data_s <= x"A5" when select_data = '1' else x"AE";

    u_dut : entity work.lcd_bus_writer
        port map (
            clk      => clk,
            rst      => rst,
            start    => start,
            is_data  => is_data,
            data_in  => data_s,
            busy     => busy,
            done     => done,
            lcd_db   => lcd_db,
            lcd_a0   => lcd_a0,
            lcd_wr_n => lcd_we_n,
            lcd_rd_n => lcd_rd_n,
            lcd_cs_n => lcd_cs_n
        );
end architecture structural;
