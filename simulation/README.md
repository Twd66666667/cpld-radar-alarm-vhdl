# VWF 分层仿真

本目录只保存仿真顶层、独立 Quartus 工程和已经运行得到的 VWF 波形。各工程引用正式 `rtl/` 文件，不修改基础版和提高版的烧录顶层。`db/`、`*.rpt` 等 Quartus 自动生成文件由 `.gitignore` 排除。

长时间节拍在联合仿真中作了压缩。例如 `tick_1ms` 仍然表示“一次 1 ms 使能事件”，但在 VWF 中不必真的等待 1 ms。这样验证的是状态转换次数、先后顺序和数据传递；舵机 PWM、超声波 TRIG 与 ECHO 仍由 1 MHz 时钟按真实微秒计数。

## 已完成结果

| 工程 | VWF | 主要结果 |
|---|---|---|
| `median3/median3_sim.qpf` | `median3.vwf` | `100, 900, 100` 输出中值 100 mm；两个有效值输出 500 mm；少于两个有效值时 `filtered_valid=0` |
| `basic_flow/basic_flow_sim.qpf` | `basic_flow.vwf` | 自检、待机、运行依次有效；两次稳定节拍后关闭舵机，静默 300 次 `tick_1ms`；连续产生三次 TRIG/ECHO；最终输出 184 mm、报警等级 4、16 位 LED 与蜂鸣器响应 |
| `enhanced_scan/enhanced_scan_sim.qpf` | `enhanced_scan.vwf` | 5°步进从 0°上升到 180°再反向返回；`cycle_start`、角度、扫描序号和 37 项校准脉宽同步变化 |
| `lcd_writer/lcd_writer_sim.qpf` | `lcd_writer.vwf` | 完成一次 `AEh` 指令写和一次 `A5h` 数据写；验证 A0、CS、WR、busy、done 的时序关系 |
| `lcd_renderer/lcd_renderer_sim.qpf` | `lcd_renderer.vwf` | 验证自检填充、水平线、90°竖线、45°斜线和三个方向的障碍标记；代表像素字节依次包含 `FFh`、`40h`、`38h`、`E0h` 和 `00h` |
| `enhanced_lcd/enhanced_lcd_sim.qpf` | `enhanced_lcd.vwf` | 真实提高版 LCD 控制器完成初始化和 1024 字节背景帧；90°、400 mm 结果写入页 4、列 63～65，三列数据均为 `03h` |

`enhanced_lcd` 使用 `EPM2210F324C3` 作为仿真工程器件，仅用于容纳额外的总线观察逻辑。被测对象仍是正式的 `enhanced_lcd_radar_ctrl.vhd`；正式提高版工程继续使用 `EPM1270T144C5`，该设置不代表烧录器件发生变化。

## 在 Quartus II 9.1 中查看

1. 打开对应目录中的 `.qpf`。
2. 双击同目录的 `.vwf`，现有文件已经包含输入和仿真输出。
3. 总线默认可在 Waveform Editor 中改为 `Unsigned Decimal` 或 `Hexadecimal`，便于读取距离、角度与 LCD 数据。
4. 如需重新运行，先执行 **Processing → Generate Functional Simulation Netlist**，再在 **Simulation Waveform Editor** 中执行功能仿真。

基础主流程图中建议重点保留 `self_test_en`、`standby_en`、`run_en`、`servo_enable`、`servo_quiet`、`trig_out`、`ultra_done`、`result_done`、`distance_u12` 和 `alarm_u3`。提高版 LCD 图中建议分别截取初始化/整帧写入的总览，以及 800 ms 附近 `point_match` 的局部波形。

基础版主流程的 Quartus 实际波形截图已保存为 [`docs/images/basic_flow_quartus_vwf.png`](../docs/images/basic_flow_quartus_vwf.png)，可直接用于实验报告。

三次测距滤波的 Quartus 实际波形截图已保存为 [`docs/images/median3_quartus_vwf.png`](../docs/images/median3_quartus_vwf.png)。图中验证了三个有效样本取中值、两个有效样本取平均值、少于两个有效样本时输出无效三种情况。

提高版 LCD 在报告中采用两张 Quartus 实际波形：[`docs/images/enhanced_lcd_init_quartus_vwf.png`](../docs/images/enhanced_lcd_init_quartus_vwf.png) 展示 12 条初始化指令及 `AFh` 完成标志；[`docs/images/enhanced_lcd_page_write_quartus_vwf.png`](../docs/images/enhanced_lcd_page_write_quartus_vwf.png) 展示第 0 页写完后切换到第 1 页、列地址重新从 0 开始以及数据计数跨页连续累加。当前报告仿真范围到此为止。
