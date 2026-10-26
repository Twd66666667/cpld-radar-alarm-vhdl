# 雷达自动检测、报警与目标跟踪系统

本项目使用 VHDL 和 Quartus II 9.1，在 EPM1270T144C5 数字实验板上实现舵机扫描、HC-SR04 超声波测距、数码管显示、点阵雷达图、LCD 雷达图、声光报警和近距离目标跟踪。

## 最终主工程

最终版本为三模式融合工程：[`fusion_tracking/radar_fusion_tracking.qpf`](fusion_tracking/radar_fusion_tracking.qpf)。顶层实体是 `radar_fusion_tracking_top`，继续开发、完整编译和上板演示均以该工程为准。

| SW7 | SW6 | SW5 | 工作模式 |
|---|---|---|---|
| 0 | 任意 | 任意 | 整机关闭 |
| 1 | 0 | 任意 | 基础模式：45°步进、数码管、LED、双色点阵和蜂鸣器 |
| 1 | 1 | 0 | 提高模式：5°扫描、数码管、LED和半圆LCD雷达图 |
| 1 | 1 | 1 | 跟踪模式：全局搜索、近距离锁定、局部跟随和丢失恢复 |

建议先关闭 SW7，设置 SW6、SW5 后再打开 SW7。运行中改变模式会触发一次系统复位，重新完成自检和待机，避免旧角度或旧距离进入新模式。

最终工程已经通过 Quartus II 9.1 完整编译并生成本地 POF：

- 目标器件：EPM1270T144C5；
- 主时钟：1 MHz；
- 逻辑单元：1268/1270；
- 引脚：76/116；
- 最高时钟频率报告：36.60 MHz；
- 时序失败路径：0；
- 编译结果：0 错误、0 警告。

最终版本已完成上板烧录。三种模式能够在同一工程内正常切换，舵机、超声波、数码管、LED、点阵、蜂鸣器和LCD的实际表现符合设计。最终工程只剩2个逻辑单元，不再适合继续加入较大的硬件模块。

## 系统架构

```text
radar_fusion_tracking_top
├─ compact_timebase                 统一产生1 ms、250 ms、2 s、2 Hz和2 kHz节拍
├─ system_ctrl                      关闭、自检、待机、运行状态机
├─ fusion_tracking_ctrl             三模式扫描、跟踪和换角控制
│  └─ tracking_servo_map            37个校准角度及脉宽查表
├─ enhanced_servo_pwm               20 ms周期舵机PWM
├─ compact_measure_ctrl             驱动、静默、三次测量和样本间隔调度
├─ compact_ultrasonic               TRIG、ECHO计时和超时保护
├─ distance_calc                    回波时间换算为毫米距离
├─ streaming_median3                三次结果的中值/平均滤波
├─ compact_distance_bcd             距离数字拆分
├─ enhanced_seg_display_ctrl        八位数码管动态显示
│  └─ seg7_decoder                  七段译码
├─ fusion_levels / fusion_alarm     距离分级、LED报警等级
├─ fusion_matrix                    基础模式双色点阵
├─ compact_buzzer_ctrl              基础模式蜂鸣节奏
└─ compact_lcd_radar_ctrl           提高/跟踪模式半圆LCD雷达图
   └─ lcd_bus_writer                LCD并行总线写时序
```

主数据流如下：

```text
模式与扫描/跟踪控制
        ↓
角度查表 → 舵机PWM → 关闭PWM并静默
        ↓
三次超声波测量 → 距离换算 → 中值/平均滤波
        ↓
数码管 / LED / 点阵 / 蜂鸣器 / LCD
        └────────────────→ 跟踪控制器反馈
```

扫描控制器决定“测哪个角度”，测量控制器决定“什么时候可以测”。舵机动作和超声波测距在时间上分开，避免PWM和舵机电流扰动影响回波采集。换角后旧距离会立即失效，只有新角度的三次测量完成后才恢复显示、报警或跟踪判断。

## 三种模式

基础模式按 `0° → 45° → 90° → 135° → 180° → 135° → 90° → 45°` 往返，每个角度约保持2秒。舵机驱动500 ms、静默300 ms后测量三次。数码管显示角度和距离，点阵保存五个方向的距离等级，LED与蜂鸣器按距离报警，LCD清屏。

提高模式以5°为一步在0°～180°之间往返，每步650 ms。舵机驱动80 ms、静默50 ms后测量三次。LCD显示半圆轮廓、扫描方向和障碍点，数码管显示精确毫米距离，LED显示当前距离等级，点阵和蜂鸣器关闭。

跟踪模式先以5°步进全局搜索。100 mm内连续两次命中后锁定，在中心、左5°和右5°之间测量并移动；锁定后使用120 mm保持阈值，目标丢失时逐步扩大搜索范围，仍未找到则恢复全局扫描。跟踪模式复用提高模式的舵机静默、三次测量、数码管、LED和LCD链路。

## 已校准参数

舵机使用37项脉宽查表。五个主要锚点为：

| 角度 | 0° | 45° | 90° | 135° | 180° |
|---|---:|---:|---:|---:|---:|
| 高电平宽度 | 480 µs | 880 µs | 1380 µs | 1880 µs | 2340 µs |

距离换算为 `echo/8 + echo/32 + echo/64 + 13 mm`，有效范围20～4000 mm。`+13 mm`来自246、354、600和1200 mm参考距离的实物校准，主要工作范围和报警分界集中在800 mm以内。

三次测量全部有效时取中值，两次有效时取平均值，少于两次时本轮结果无效。TRIG保持20 µs，等待回波和ECHO高电平均有30 ms超时保护。

## 工程目录

| 路径 | 作用 |
|---|---|
| `fusion_tracking/` | 最终三模式融合工程，默认编译与烧录入口 |
| `rtl/fusion_tracking/` | 最终版专用的压缩控制、测量、滤波、显示和顶层源码 |
| `fusion/` | 历史双模式融合版，保留作资源优化和VWF对照 |
| `tracking/` | 历史独立跟踪版，保留作跟踪逻辑和VWF对照 |
| `enhanced/` | 历史独立提高版 |
| 根目录 `radar.qpf` | 历史独立基础版 |
| `rtl/` | 各版本共用及历史VHDL模块 |
| `simulation/`、`fusion/sim/`、`tracking/sim/` | 已完成的Quartus VWF分层仿真工程 |
| `docs/` | 硬件测试记录和仿真截图 |

各历史工程仍能独立打开，不移动目录、不修改相对源文件路径。Quartus生成的数据库、报告、POF和临时文件由 `.gitignore` 排除；最终 POF 在本地完整编译后生成于 `fusion_tracking/`。

## 编译与验证

1. 使用 Quartus II 9.1 打开 [`radar_fusion_tracking.qpf`](fusion_tracking/radar_fusion_tracking.qpf)。
2. 确认顶层为 `radar_fusion_tracking_top`，器件为 `EPM1270T144C5`。
3. 执行完整编译，生成 `radar_fusion_tracking.pof` 后烧录。
4. 按基础、提高、跟踪的顺序上板检查，并在切换模式前关闭SW7。

本项目的仿真操作统一使用 Quartus VWF。历史模块和独立工程的仿真记录见 [`simulation/README.md`](simulation/README.md)，最终三模式融合版本身没有另做一套顶层VWF；最终结论来自完整编译、时序报告和实际烧录测试。

详细资源优化与最终版内部约定见 [`fusion_tracking/README.md`](fusion_tracking/README.md)，实物现象和校准过程见 [`docs/hardware_test_log.md`](docs/hardware_test_log.md)。
