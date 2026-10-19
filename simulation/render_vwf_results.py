"""Render compact report figures from Quartus II 9.1 text VWF results.

The simulations themselves are still executed by quartus_sim.  This script
only reads the resulting transition lists and produces clean PNG summaries.
"""

from __future__ import annotations

import re
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[1]
IMAGE_DIR = ROOT / "docs" / "images"
IMAGE_DIR.mkdir(parents=True, exist_ok=True)


def parse_vwf(path: Path) -> tuple[dict[str, list[tuple[float, float, int]]], float]:
    lines = path.read_text(encoding="utf-8").splitlines()
    duration = 0.0
    for line in lines:
        match = re.search(r"DATA_DURATION\s*=\s*([0-9.]+)", line)
        if match:
            duration = float(match.group(1))
            break

    def parse_node(index: int) -> tuple[list[tuple[int, float]], int]:
        assert lines[index].strip() == "NODE"
        index += 1
        assert lines[index].strip() == "{"
        index += 1
        repeat = 1
        sequence: list[tuple[int, float]] = []
        while index < len(lines):
            text = lines[index].strip()
            repeat_match = re.match(r"REPEAT\s*=\s*(\d+);", text)
            level_match = re.match(r"LEVEL\s+([01])\s+FOR\s+([0-9.]+);", text)
            if repeat_match:
                repeat = int(repeat_match.group(1))
                index += 1
            elif level_match:
                sequence.append((int(level_match.group(1)), float(level_match.group(2))))
                index += 1
            elif text == "NODE":
                child, index = parse_node(index)
                sequence.extend(child)
            elif text == "}":
                return sequence * repeat, index + 1
            else:
                index += 1
        raise ValueError(f"Unterminated NODE in {path}")

    signals: dict[str, list[tuple[float, float, int]]] = {}
    index = 0
    while index < len(lines):
        match = re.match(r'TRANSITION_LIST\("(.+)"\)', lines[index].strip())
        if not match:
            index += 1
            continue
        name = match.group(1)
        while index < len(lines) and lines[index].strip() != "NODE":
            index += 1
        sequence, index = parse_node(index)
        time = 0.0
        segments: list[tuple[float, float, int]] = []
        for value, length in sequence:
            segments.append((time, time + length, value))
            time += length
        signals[name] = segments
    return signals, duration


def value_at(segments: list[tuple[float, float, int]], time: float) -> int:
    for start, end, value in segments:
        if start <= time < end or (time == end and end == segments[-1][1]):
            return value
    return segments[-1][2] if segments else 0


def vector_steps(
    signals: dict[str, list[tuple[float, float, int]]], base: str, width: int, duration: float
) -> tuple[list[float], list[int]]:
    boundaries = {0.0, duration}
    bits = []
    for bit in range(width):
        segments = signals[f"{base}[{bit}]"]
        bits.append(segments)
        boundaries.update(start for start, _, _ in segments)
        boundaries.update(end for _, end, _ in segments)
    times = sorted(boundaries)
    values = []
    for time in times:
        probe = min(time + 0.01, duration)
        value = sum(value_at(bits[bit], probe) << bit for bit in range(width))
        values.append(value)
    return times, values


def draw_digital(ax, segments, scale, label, color="#1565c0"):
    x = []
    y = []
    for start, end, value in segments:
        x.extend([start / scale, end / scale])
        y.extend([value, value])
    ax.plot(x, y, color=color, linewidth=1.4)
    ax.set_ylim(-0.2, 1.2)
    ax.set_yticks([0, 1])
    ax.set_ylabel(label, rotation=0, ha="right", va="center")
    ax.grid(axis="x", alpha=0.25)


def finish(fig, axes, title, xlabel, output):
    axes[-1].set_xlabel(xlabel)
    fig.suptitle(title, fontsize=14, fontweight="bold")
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    fig.savefig(IMAGE_DIR / output, dpi=180, bbox_inches="tight")
    plt.close(fig)


def render_median():
    signals, duration = parse_vwf(ROOT / "simulation" / "median3" / "median3.vwf")
    names = ["sample_done", "sample_valid", "result_done", "filtered_valid"]
    fig, axes = plt.subplots(5, 1, figsize=(12, 7), sharex=True)
    for ax, name in zip(axes, names):
        draw_digital(ax, signals[name], 1000.0, name)
    times, values = vector_steps(signals, "filtered_distance", 12, duration)
    axes[-1].step([t / 1000.0 for t in times], values, where="post", color="#c62828")
    axes[-1].set_ylabel("distance\n(mm)", rotation=0, ha="right", va="center")
    axes[-1].set_ylim(-50, 950)
    axes[-1].grid(axis="x", alpha=0.25)
    axes[-1].annotate("median = 100", (16, 100), xytext=(17, 300), arrowprops={"arrowstyle": "->"})
    axes[-1].annotate("mean = 500", (34, 500), xytext=(35, 700), arrowprops={"arrowstyle": "->"})
    finish(fig, axes, "Three-sample filter VWF result", "Time (us)", "median3_vwf_result.png")


def render_basic_flow():
    signals, duration = parse_vwf(ROOT / "simulation" / "basic_flow" / "basic_flow.vwf")
    names = [
        "self_test_en", "standby_en", "run_en", "servo_enable", "servo_quiet",
        "trig_out", "echo_in_mon", "ultra_done", "result_done", "result_valid",
    ]
    fig, axes = plt.subplots(11, 1, figsize=(13, 11), sharex=True)
    for ax, name in zip(axes, names):
        draw_digital(ax, signals[name], 1_000_000.0, name)
    times, values = vector_steps(signals, "distance_u12", 12, duration)
    axes[-1].step([t / 1_000_000.0 for t in times], values, where="post", color="#c62828")
    axes[-1].set_ylabel("distance\n(mm)", rotation=0, ha="right", va="center")
    axes[-1].set_ylim(-10, 220)
    axes[-1].grid(axis="x", alpha=0.25)
    result_time = next(t for t, value in zip(times, values) if value == 184) / 1_000_000.0
    axes[-1].annotate(
        "184 mm",
        (result_time, 184),
        xytext=(result_time - 0.65, 110),
        arrowprops={"arrowstyle": "->"},
    )
    finish(fig, axes, "Basic radar integrated flow (compressed tick enables)", "Time (ms)", "basic_flow_vwf_result.png")


def render_enhanced_scan():
    signals, duration = parse_vwf(ROOT / "simulation" / "enhanced_scan" / "enhanced_scan.vwf")
    angle_t, angle_v = vector_steps(signals, "angle_u8", 8, duration)
    pulse_t, pulse_v = vector_steps(signals, "pulse_us_u12", 12, duration)
    fig, axes = plt.subplots(3, 1, figsize=(13, 7), sharex=True)
    axes[0].step([t / 1_000_000.0 for t in angle_t], angle_v, where="post", color="#1565c0")
    axes[0].set_ylabel("angle\n(deg)", rotation=0, ha="right", va="center")
    axes[0].set_ylim(-5, 190)
    axes[0].grid(axis="x", alpha=0.25)
    axes[1].step([t / 1_000_000.0 for t in pulse_t], pulse_v, where="post", color="#ef6c00")
    axes[1].set_ylabel("pulse\n(us)", rotation=0, ha="right", va="center")
    axes[1].set_ylim(400, 2450)
    axes[1].grid(axis="x", alpha=0.25)
    draw_digital(axes[2], signals["cycle_start"], 1_000_000.0, "cycle_start")
    finish(fig, axes, "Enhanced 5-degree bidirectional scan VWF result", "Time (ms)", "enhanced_scan_vwf_result.png")


def render_lcd_writer():
    signals, _ = parse_vwf(ROOT / "simulation" / "lcd_writer" / "lcd_writer.vwf")
    names = ["start", "busy", "lcd_cs_n", "lcd_we_n", "lcd_a0", "done"]
    fig, axes = plt.subplots(len(names), 1, figsize=(12, 7), sharex=True)
    for ax, name in zip(axes, names):
        draw_digital(ax, signals[name], 1000.0, name)
    axes[-1].annotate("command AEh", (6.5, 0), xytext=(4, 0.7), arrowprops={"arrowstyle": "->"})
    axes[-1].annotate("data A5h", (14.5, 0), xytext=(16, 0.7), arrowprops={"arrowstyle": "->"})
    finish(fig, axes, "LCD single-byte bus writer VWF result", "Time (us)", "lcd_writer_vwf_result.png")


def render_lcd_renderer():
    signals, duration = parse_vwf(ROOT / "simulation" / "lcd_renderer" / "lcd_renderer.vwf")
    case_t, case_v = vector_steps(signals, "case_u4", 4, duration)
    pixel_t, pixel_v = vector_steps(signals, "pixel_byte", 8, duration)
    fig, axes = plt.subplots(2, 1, figsize=(12, 5), sharex=True)
    axes[0].step([t / 1000.0 for t in case_t], case_v, where="post", color="#1565c0")
    axes[0].set_ylabel("case", rotation=0, ha="right", va="center")
    axes[0].set_yticks(range(8))
    axes[0].grid(axis="x", alpha=0.25)
    axes[1].step([t / 1000.0 for t in pixel_t], pixel_v, where="post", color="#6a1b9a")
    axes[1].set_ylabel("pixel byte", rotation=0, ha="right", va="center")
    axes[1].set_yticks([0x00, 0x38, 0x40, 0xE0, 0xFF], ["00", "38", "40", "E0", "FF"])
    axes[1].grid(axis="x", alpha=0.25)
    finish(fig, axes, "Basic LCD renderer representative pixels", "Time (us)", "lcd_renderer_vwf_result.png")


def render_enhanced_lcd():
    signals, duration = parse_vwf(ROOT / "simulation" / "enhanced_lcd" / "enhanced_lcd.vwf")
    count_t, count_v = vector_steps(signals, "data_count_u11", 11, duration)
    fig, axes = plt.subplots(4, 1, figsize=(13, 7), sharex=True)
    draw_digital(axes[0], signals["init_af_seen"], 1_000_000.0, "init_AF")
    axes[1].step([t / 1_000_000.0 for t in count_t], count_v, where="post", color="#1565c0")
    axes[1].set_ylabel("LCD data\ncount", rotation=0, ha="right", va="center")
    axes[1].set_ylim(-20, 1100)
    axes[1].grid(axis="x", alpha=0.25)
    draw_digital(axes[2], signals["result_done"], 1_000_000.0, "result_done")
    draw_digital(axes[3], signals["point_match"], 1_000_000.0, "point_match")
    axes[3].set_xlim(0, 850)
    finish(fig, axes, "Enhanced LCD: initialization, frame and target point", "Time (ms)", "enhanced_lcd_vwf_result.png")


if __name__ == "__main__":
    render_median()
    render_basic_flow()
    render_enhanced_scan()
    render_lcd_writer()
    render_lcd_renderer()
    render_enhanced_lcd()
    print(f"Rendered VWF summaries to {IMAGE_DIR}")
