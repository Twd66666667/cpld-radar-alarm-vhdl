# 雷达自动检测报警系统 in VHDL

基于 EPM1270T144C5 数字实验板的雷达探测与报警课程项目，使用 VHDL 和 Quartus II 9.1 开发。

## 当前进度

- 已建立 `radar_top` 顶层实体。
- 已完成 `timebase` 时基模块，可由1 MHz主时钟产生1 ms、250 ms、2 s节拍和2 Hz方波。
- 已完成 `system_ctrl` 启动状态机，实现关闭、自检、待机、运行四个状态。
- 已完成 `scan_ctrl` 扫描控制器，按 `0° → 45° → 90° → 135° → 180° → 135° → 90° → 45°` 循环输出角度。
- 已完成 `servo_pwm` 舵机驱动，将五个扫描角度转换为20 ms周期的SG90控制脉冲。
- 已完成 `ultrasonic` 测距时序模块，包括10 μs TRIG、ECHO双触发器同步、脉宽计数、等待超时和ECHO卡高保护。
- 顶层已连接时基、系统状态、扫描控制和舵机PWM；超声波模块将在测距调度器完成后接入。
- 舵机PWM和超声波三种场景均已通过Quartus II 9.1功能仿真。
- 实验板下载和实物验证待完成。

## 工程结构

```text
rtl/
  radar_top.vhd     顶层连接
  timebase.vhd      时基与闪烁信号
  system_ctrl.vhd   系统启动状态机
  scan_ctrl.vhd     往返角度序列
  servo_pwm.vhd     SG90舵机PWM
  ultrasonic.vhd    HC-SR04触发、回波计时和超时保护
tb/
  servo_pwm.vwf     Quartus舵机功能仿真输入波形
  ultrasonic.vwf    Quartus超声波功能仿真输入波形
  tb_servo_pwm.vhd  VHDL testbench，供外部仿真器使用
docs/images/
  servo_pwm_simulation.png
  ultrasonic_normal_simulation.png
  ultrasonic_three_cases_simulation.png
radar.qpf           Quartus工程
radar.qsf           器件、源文件及仿真设置
```

## SG90舵机PWM仿真

仿真使用1 MHz时钟和Quartus II 9.1功能仿真器。`enable`拉高后，依次输入0°、90°和180°；最后关闭使能，检查PWM是否停止。仿真器以0错误、0警告完成。

| 输入角度 | PWM周期 | 设计高电平宽度 | 仿真结果 |
|---:|---:|---:|---|
| 0° | 20 ms | 0.5 ms | 与设计一致 |
| 90° | 20 ms | 1.5 ms | 与设计一致 |
| 180° | 20 ms | 2.5 ms | 与设计一致 |
| 禁用 | — | 0 | 输出保持低电平 |

![SG90 PWM功能仿真](docs/images/servo_pwm_simulation.png)

实验报告可用结论：仿真结果表明，舵机驱动模块能够在1 MHz系统时钟下产生20 ms周期的PWM信号，并根据目标角度将高电平宽度分别调整为0.5 ms、1.5 ms和2.5 ms；关闭使能后输出保持低电平，模块功能符合SG90的控制时序要求。

## HC-SR04超声波时序仿真

仿真同样采用1 MHz时钟。每次 `start` 到来后，模块产生10 μs TRIG，随后等待并同步ECHO。`done`为单周期完成脉冲；正常测量后 `valid`保持为1，直到下一次 `start` 清除；异常测量保持无效。

| 场景 | 输入 | 结果 |
|---|---|---|
| 正常回波 | ECHO高电平约1096 μs | `echo_time_us=1096`，`done=1`，结果有效 |
| 无回波 | ECHO持续为0 | 等待约30 ms后结束，`done=1`，`valid=0`，结果为0 |
| ECHO卡高 | ECHO上升后不下降 | 测量约30 ms后结束，`done=1`，`valid=0`，结果为0 |

正常回波局部波形：

![HC-SR04正常回波仿真](docs/images/ultrasonic_normal_simulation.png)

三种场景整体波形：

![HC-SR04三种场景仿真](docs/images/ultrasonic_three_cases_simulation.png)

实验报告可用结论：功能仿真表明，超声波时序模块能够产生满足要求的TRIG脉冲，并正确测量同步后ECHO的高电平持续时间；当无回波或ECHO持续高电平时，模块均能在约30 ms后退出并给出无效结果，避免控制状态机永久阻塞。

## 开发约定

- 主时钟使用实验板的1 MHz时钟。
- 所有时序模块使用同一个主时钟，以单周期 `tick` 作为时钟使能。
- 每完成一个可以独立检查的模块后进行一次Git提交。
- `db`、编译报告和下载文件属于可再生文件，不提交到仓库。

