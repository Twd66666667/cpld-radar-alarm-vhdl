library ieee;
use ieee.std_logic_1164.all;

entity tb_measure_ctrl is
end entity tb_measure_ctrl;

architecture sim of tb_measure_ctrl is

    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal run_en       : std_logic := '0';

    signal tick_1ms     : std_logic := '0';
    signal tick_250ms   : std_logic := '0';
    signal tick_2s      : std_logic := '0';

    signal ultra_busy   : std_logic := '0';
    signal ultra_done   : std_logic := '0';

    signal ultra_start  : std_logic;
    signal servo_quiet  : std_logic;

begin

	 -- 1 MHz时钟：一个周期为1 us
    clk <= not clk after 500 ns;

    u_dut : entity work.measure_ctrl
    port map (
        clk         => clk,
        rst         => rst,
        tick_1ms    => tick_1ms,
        run_en      => run_en,
        tick_250ms  => tick_250ms,
        tick_2s     => tick_2s,
        ultra_busy  => ultra_busy,
        ultra_done  => ultra_done,
        ultra_start => ultra_start,
        servo_quiet => servo_quiet
    );
    
    stimulus : process

    -- 产生一个持续1个时钟周期的tick脉冲
    procedure pulse_tick(signal tick_signal : out std_logic) is
    begin
        wait until falling_edge(clk);
        tick_signal <= '1';

        wait until falling_edge(clk);
        tick_signal <= '0';
    end procedure;

begin

    -- 1. 系统复位
    rst         <= '1';
    run_en      <= '0';
    ultra_busy  <= '0';
    ultra_done  <= '0';

    wait for 3 us;

    -- 2. 解除复位，进入运行状态
    wait until falling_edge(clk);
    rst    <= '0';
    run_en <= '1';

    wait for 3 us;

    -- 3. 第一个250 ms节拍：舵机还应继续工作
    pulse_tick(tick_250ms);

    wait for 2 us;

    assert servo_quiet = '0'
        report "Error: servo stopped too early"
        severity error;

    -- 4. 第二个250 ms节拍：累计完成500 ms，
    -- 控制器进入静默状态
    pulse_tick(tick_250ms);

    wait for 2 us;

    assert servo_quiet = '1'
        report "Error: servo_quiet did not become 1"
        severity error;

    -- 5. 用50个tick_1ms模拟50 ms静默时间
    for i in 1 to 50 loop
        pulse_tick(tick_1ms);
    end loop;

    -- 6. 模拟三次超声波测量
    for sample_number in 1 to 3 loop

        -- 等待控制器发出测量启动脉冲
        wait until ultra_start = '1';

        assert servo_quiet = '1'
            report "Error: servo PWM enabled during measurement"
            severity error;

        -- 模拟超声波模块开始忙碌
        wait until falling_edge(clk);
        ultra_busy <= '1';

        wait for 5 us;

        -- 模拟本次测量完成，done保持一个时钟周期
        wait until falling_edge(clk);
        ultra_busy <= '0';
        ultra_done <= '1';

        wait until falling_edge(clk);
        ultra_done <= '0';

        -- 前两次测量结束后，提供60个1 ms节拍
        if sample_number < 3 then
            for i in 1 to 60 loop
                pulse_tick(tick_1ms);
            end loop;
        end if;

    end loop;

    -- 7. 三次测量全部完成，PWM应当恢复
    wait for 3 us;

    assert servo_quiet = '0'
        report "Error: servo_quiet did not return to 0"
        severity error;

    report "measure_ctrl quiet-window simulation passed"
        severity note;

    wait;

end process;

end architecture sim;