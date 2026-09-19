# CPLD Radar Alarm in VHDL

基于 EPM1270T144C5 数字实验板的雷达探测与报警课程项目，使用 VHDL 和 Quartus II 9.1 开发。

## 当前进度

- 已建立 `radar_top` 顶层实体。
- 已完成 `timebase` 时基模块，可由 1 MHz 主时钟产生 1 ms、250 ms、2 s 节拍和 2 Hz 方波。
- 已完成 `system_ctrl` 启动状态机，实现关闭、自检、待机、运行四个状态。
- 顶层已连接时基与状态控制器；自检状态下16个LED以2 Hz闪烁。
- 最新代码已通过 Quartus II 9.1 Analysis & Synthesis。
- 实验板下载与实际波形验证待完成。

## 工程结构

```text
rtl/
  radar_top.vhd     顶层连接
  timebase.vhd      时基与闪烁信号
  system_ctrl.vhd   系统启动状态机
radar.qpf           Quartus 工程
radar.qsf           器件、源文件及引脚设置
```

## 开发约定

- 主时钟使用实验板的 1 MHz 时钟。
- 所有时序模块使用同一个主时钟，以单周期 `tick` 作为时钟使能。
- 每完成一个可以独立检查的模块后进行一次 Git 提交。
- `db`、编译报告和下载文件属于可再生文件，不提交到仓库。

