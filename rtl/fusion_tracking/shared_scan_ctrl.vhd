library ieee;
use ieee.std_logic_1164.all;

entity shared_scan_ctrl is
port (
    clk : in std_logic;
    rst : in std_logic;
    run_en : in std_logic;
    enhanced_mode : in std_logic;
    tick_1ms : in std_logic;
    tick_2s : in std_logic;
    scan_index : out integer range 0 to 36;
    basic_angle_deg : out integer range 0 to 180;
    cycle_start : out std_logic
);
end entity;

architecture rtl of shared_scan_ctrl is
    signal index_reg : integer range 0 to 36 := 0;
    signal period_count : integer range 0 to 649 := 0;
    signal direction_up : std_logic := '1';
    signal run_en_d : std_logic := '0';
    signal step_now : std_logic;
begin
    step_now <= tick_2s when enhanced_mode = '0' else
                '1' when tick_1ms = '1' and period_count = 649 else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                index_reg <= 0;
                period_count <= 0;
                direction_up <= '1';
                run_en_d <= '0';
                cycle_start <= '0';
            else
                run_en_d <= run_en;
                cycle_start <= '0';
                if run_en = '0' then
                    index_reg <= 0;
                    period_count <= 0;
                    direction_up <= '1';
                elsif run_en_d = '0' then
                    period_count <= 0;
                    cycle_start <= '1';
                else
                    if enhanced_mode = '1' and tick_1ms = '1' then
                        if period_count = 649 then period_count <= 0;
                        else period_count <= period_count + 1;
                        end if;
                    end if;
                    if step_now = '1' then
                        cycle_start <= '1';
                        if enhanced_mode = '0' then
                            if direction_up = '1' then
                                if index_reg = 36 then
                                    index_reg <= 27;
                                    direction_up <= '0';
                                else
                                    index_reg <= index_reg + 9;
                                end if;
                            else
                                if index_reg = 0 then
                                    index_reg <= 9;
                                    direction_up <= '1';
                                else
                                    index_reg <= index_reg - 9;
                                end if;
                            end if;
                        elsif direction_up = '1' then
                            if index_reg = 36 then
                                index_reg <= 35;
                                direction_up <= '0';
                            else
                                index_reg <= index_reg + 1;
                            end if;
                        else
                            if index_reg = 0 then
                                index_reg <= 1;
                                direction_up <= '1';
                            else
                                index_reg <= index_reg - 1;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    scan_index <= index_reg;
    with index_reg select basic_angle_deg <=
        0 when 0, 45 when 9, 90 when 18,
        135 when 27, 180 when 36, 0 when others;
end architecture;
