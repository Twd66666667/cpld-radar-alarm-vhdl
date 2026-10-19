"""Machine-check the key values in the generated Quartus VWF results."""

from pathlib import Path

from render_vwf_results import ROOT, parse_vwf, value_at, vector_steps


def high_pulses(segments):
    return sum(1 for _, _, value in segments if value == 1)


def vector_value(signals, base, width, time):
    return sum(value_at(signals[f"{base}[{bit}]"], time) << bit for bit in range(width))


def check_median():
    signals, _ = parse_vwf(ROOT / "simulation" / "median3" / "median3.vwf")
    assert high_pulses(signals["result_done"]) == 3
    assert vector_value(signals, "filtered_distance", 12, 16_000) == 100
    assert vector_value(signals, "filtered_distance", 12, 34_000) == 500
    assert value_at(signals["filtered_valid"], 52_000) == 0


def check_basic_flow():
    signals, _ = parse_vwf(ROOT / "simulation" / "basic_flow" / "basic_flow.vwf")
    assert high_pulses(signals["trig_out"]) == 3
    assert high_pulses(signals["ultra_done"]) == 3
    assert high_pulses(signals["result_done"]) == 1
    assert vector_value(signals, "distance_u12", 12, 5_000_000) == 184
    assert vector_value(signals, "alarm_u3", 3, 5_000_000) == 4
    assert value_at(signals["result_valid"], 5_000_000) == 1


def check_enhanced_scan():
    signals, duration = parse_vwf(ROOT / "simulation" / "enhanced_scan" / "enhanced_scan.vwf")
    _, angles = vector_steps(signals, "angle_u8", 8, duration)
    assert min(angles) == 0 and max(angles) == 180
    assert high_pulses(signals["cycle_start"]) == 77
    # Representative calibrated table points.
    samples = []
    for time in range(0, int(duration), 100_000):
        samples.append(
            (
                vector_value(signals, "angle_u8", 8, time),
                vector_value(signals, "pulse_us_u12", 12, time),
            )
        )
    assert (0, 480) in samples
    assert (90, 1380) in samples
    assert (180, 2340) in samples


def check_lcd_writer():
    signals, _ = parse_vwf(ROOT / "simulation" / "lcd_writer" / "lcd_writer.vwf")
    assert high_pulses(signals["done"]) == 2
    assert value_at(signals["lcd_a0"], 7_000) == 0
    assert value_at(signals["lcd_a0"], 15_000) == 1
    assert vector_value(signals, "lcd_db", 8, 7_000) == 0xAE
    assert vector_value(signals, "lcd_db", 8, 15_000) == 0xA5


def check_lcd_renderer():
    signals, _ = parse_vwf(ROOT / "simulation" / "lcd_renderer" / "lcd_renderer.vwf")
    expected = [0xFF, 0x40, 0xFF, 0x40, 0x38, 0xE0, 0xE0, 0x00]
    sample_times = [4_000, 8_000, 12_000, 16_000, 20_000, 24_000, 28_000, 32_000]
    actual = [vector_value(signals, "pixel_byte", 8, time) for time in sample_times]
    assert actual == expected, (actual, expected)


def check_enhanced_lcd():
    signals, _ = parse_vwf(ROOT / "simulation" / "enhanced_lcd" / "enhanced_lcd.vwf")
    assert value_at(signals["init_af_seen"], 100_000) == 1
    assert high_pulses(signals["point_match"]) == 3
    assert vector_value(signals, "data_count_u11", 11, 900_000_000) == 1027


if __name__ == "__main__":
    check_median()
    check_basic_flow()
    check_enhanced_scan()
    check_lcd_writer()
    check_lcd_renderer()
    check_enhanced_lcd()
    print("VWF_RESULT_CHECK=PASS (6 simulation groups)")
