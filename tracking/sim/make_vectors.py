"""Build Quartus 9.1 VWF stimuli; Quartus remains the only simulator.

The DUT's tick_1ms input is pulsed every two clock cycles in these unit
vectors.  This preserves the required 500 enable pulses per step without
simulating half a million clock cycles for each target decision.
"""

from pathlib import Path


HERE = Path(__file__).resolve().parent
STEP_NS = 1_000_000
FIRST_RESULT_NS = 200_000
PULSE_NS = 1_000


def signal(name, direction, width=1, parent=""):
    kind = "BUS" if width > 1 else "SINGLE_BIT"
    lsb = 0 if width > 1 else -1
    return (
        f'SIGNAL("{name}")\n{{\n'
        f'\tVALUE_TYPE = NINE_LEVEL_BIT;\n'
        f'\tSIGNAL_TYPE = {kind};\n'
        f'\tWIDTH = {width};\n'
        f'\tLSB_INDEX = {lsb};\n'
        f'\tDIRECTION = {direction};\n'
        f'\tPARENT = "{parent}";\n'
        f'}}\n'
    )


def bus(name, direction, width):
    result = [signal(name, direction, width)]
    for bit in range(width - 1, -1, -1):
        result.append(signal(f"{name}[{bit}]", direction, parent=name))
    return result


def transitions(name, parts):
    body = "\n".join(f"\t\tLEVEL {level} FOR {float(length):.1f};" for level, length in parts)
    return f'TRANSITION_LIST("{name}")\n{{\n\tNODE\n\t{{\n\t\tREPEAT = 1;\n{body}\n\t}}\n}}\n'


def time_parts(events, duration, initial=0):
    edges = [(0, initial)] + events + [(duration, None)]
    result = []
    for (start, value), (end, _) in zip(edges, edges[1:]):
        if end > start:
            if result and result[-1][0] == value:
                result[-1] = (value, result[-1][1] + end - start)
            else:
                result.append((value, end - start))
    return result


def make_vector(path, samples):
    # samples are (distance_mm, valid), one result per 500 accelerated ticks.
    duration = (len(samples) + 1) * STEP_NS
    lines = [
        "HEADER\n{\n\tVERSION = 1;\n\tTIME_UNIT = ns;\n"
        f"\tDATA_OFFSET = 0.0;\n\tDATA_DURATION = {float(duration):.1f};\n"
        f"\tSIMULATION_TIME = {float(duration):.1f};\n"
        "\tGRID_PHASE = 0.0;\n\tGRID_PERIOD = 1000.0;\n"
        "\tGRID_DUTY_CYCLE = 50;\n}\n"
    ]
    for name in ("clk", "rst", "run_en", "tick_1ms", "result_done", "result_valid"):
        lines.append(signal(name, "INPUT"))
    lines.extend(bus("distance_mm", "INPUT", 12))
    lines.extend(bus("scan_index", "OUTPUT", 6))
    lines.extend(bus("target_index", "OUTPUT", 6))
    lines.append(signal("target_valid", "OUTPUT"))
    lines.extend(bus("mode_code", "OUTPUT", 2))
    lines.append(signal("cycle_start", "OUTPUT"))

    lines.append(
        'TRANSITION_LIST("clk")\n{\n\tNODE\n\t{\n\t\tREPEAT = 1;\n'
        f'\t\tNODE\n\t\t{{\n\t\t\tREPEAT = {duration // 1000};\n'
        '\t\t\tLEVEL 0 FOR 500.0;\n\t\t\tLEVEL 1 FOR 500.0;\n'
        '\t\t}\n\t}\n}\n'
    )
    lines.append(transitions("rst", [(1, 3_000), (0, duration - 3_000)]))
    lines.append(transitions("run_en", [(0, 3_000), (1, duration - 3_000)]))
    lines.append(
        'TRANSITION_LIST("tick_1ms")\n{\n\tNODE\n\t{\n'
        f'\t\tREPEAT = 1;\n\t\tNODE\n\t\t{{\n\t\t\tREPEAT = {duration // 2000};\n'
        '\t\t\tLEVEL 1 FOR 1000.0;\n\t\t\tLEVEL 0 FOR 1000.0;\n'
        '\t\t}\n\t}\n}\n'
    )

    done_events = []
    valid_events = []
    values = []
    for i, (distance, valid) in enumerate(samples):
        at = FIRST_RESULT_NS + i * STEP_NS
        done_events.extend([(at, 1), (at + PULSE_NS, 0)])
        valid_events.append((at - PULSE_NS, 1 if valid else 0))
        values.append((at - PULSE_NS, distance))
    lines.append(transitions("result_done", time_parts(done_events, duration)))
    lines.append(transitions("result_valid", time_parts(valid_events, duration)))
    for bit in range(11, -1, -1):
        bit_events = [(at, (value >> bit) & 1) for at, value in values]
        lines.append(transitions(f"distance_mm[{bit}]", time_parts(bit_events, duration)))

    for name in ("scan_index", "target_index", "mode_code"):
        width = 2 if name == "mode_code" else 6
        for bit in range(width - 1, -1, -1):
            lines.append(transitions(f"{name}[{bit}]", [("X", duration)]))
    for name in ("target_valid", "cycle_start"):
        lines.append(transitions(name, [("X", duration)]))

    shown = ["clk", "rst", "run_en", "tick_1ms", "result_done",
             "result_valid", "distance_mm", "scan_index", "target_index",
             "target_valid", "mode_code", "cycle_start"]
    widths = {"distance_mm": 12, "scan_index": 6,
              "target_index": 6, "mode_code": 2}
    tree_index = 0
    for name in shown:
        children = widths.get(name, 0)
        child_ids = ", ".join(str(n) for n in range(
            tree_index + 1, tree_index + children + 1))
        child_line = f"\tCHILDREN = {child_ids};\n" if children else ""
        lines.append(
            "DISPLAY_LINE\n{\n"
            f'\tCHANNEL = "{name}";\n\tEXPAND_STATUS = COLLAPSED;\n'
            f"\tRADIX = Unsigned;\n\tTREE_INDEX = {tree_index};\n"
            f"\tTREE_LEVEL = 0;\n{child_line}}}\n"
        )
        parent_index = tree_index
        tree_index += 1
        for bit in range(children - 1, -1, -1):
            lines.append(
                "DISPLAY_LINE\n{\n"
                f'\tCHANNEL = "{name}[{bit}]";\n'
                "\tEXPAND_STATUS = COLLAPSED;\n\tRADIX = Unsigned;\n"
                f"\tTREE_INDEX = {tree_index};\n\tTREE_LEVEL = 1;\n"
                f"\tPARENT = {parent_index};\n}}\n"
            )
            tree_index += 1
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def make_flow_vector(path):
    """Exercise the real tracker, servo/quiet scheduler, and median filter."""
    duration = 3_000_000
    lines = [
        "HEADER\n{\n\tVERSION = 1;\n\tTIME_UNIT = ns;\n"
        f"\tDATA_OFFSET = 0.0;\n\tDATA_DURATION = {float(duration):.1f};\n"
        f"\tSIMULATION_TIME = {float(duration):.1f};\n"
        "\tGRID_PHASE = 0.0;\n\tGRID_PERIOD = 1000.0;\n"
        "\tGRID_DUTY_CYCLE = 50;\n}\n"
    ]
    for name in ("clk", "rst", "run_en", "tick_1ms", "ultra_busy",
                 "ultra_done", "sample_valid"):
        lines.append(signal(name, "INPUT"))
    lines.extend(bus("sample_distance", "INPUT", 12))
    lines.extend(bus("scan_index", "OUTPUT", 6))
    lines.extend(bus("mode_code", "OUTPUT", 2))
    for name in ("cycle_start", "servo_quiet", "ultra_start",
                 "result_done", "result_valid"):
        lines.append(signal(name, "OUTPUT"))
    lines.extend(bus("filtered_distance", "OUTPUT", 12))

    lines.append(
        'TRANSITION_LIST("clk")\n{\n\tNODE\n\t{\n\t\tREPEAT = 1;\n'
        f'\t\tNODE\n\t\t{{\n\t\t\tREPEAT = {duration // 1000};\n'
        '\t\t\tLEVEL 0 FOR 500.0;\n\t\t\tLEVEL 1 FOR 500.0;\n'
        '\t\t}\n\t}\n}\n'
    )
    lines.append(transitions("rst", [(1, 3_000), (0, duration - 3_000)]))
    lines.append(transitions("run_en", [(0, 3_000), (1, duration - 3_000)]))
    lines.append(
        'TRANSITION_LIST("tick_1ms")\n{\n\tNODE\n\t{\n'
        f'\t\tREPEAT = 1;\n\t\tNODE\n\t\t{{\n\t\t\tREPEAT = {duration // 2000};\n'
        '\t\t\tLEVEL 1 FOR 1000.0;\n\t\t\tLEVEL 0 FOR 1000.0;\n'
        '\t\t}\n\t}\n}\n'
    )
    lines.append(transitions("ultra_busy", [(0, duration)]))
    lines.append(transitions("sample_valid", [(1, duration)]))

    # Three completed echoes per angle. The scheduler's 60-tick gaps are
    # 120 us in this accelerated waveform.  The first triple misses; the
    # second and third triples find and confirm a close target at 5 degrees.
    distances = ((150, 152, 149), (80, 200, 82), (90, 92, 91))
    done_events = []
    values = []
    for cycle, triple in enumerate(distances):
        for sample_index, distance in enumerate(triple):
            at = cycle * STEP_NS + (280_000, 420_000, 560_000)[sample_index]
            done_events.extend([(at, 1), (at + PULSE_NS, 0)])
            values.append((at - PULSE_NS, distance))
    lines.append(transitions("ultra_done", time_parts(done_events, duration)))
    for bit in range(11, -1, -1):
        events = [(at, (value >> bit) & 1) for at, value in values]
        lines.append(transitions(
            f"sample_distance[{bit}]", time_parts(events, duration)))

    widths = {"sample_distance": 12, "scan_index": 6,
              "mode_code": 2, "filtered_distance": 12}
    outputs = ("scan_index", "mode_code", "cycle_start", "servo_quiet",
               "ultra_start", "result_done", "result_valid",
               "filtered_distance")
    for name in outputs:
        if name in widths:
            for bit in range(widths[name] - 1, -1, -1):
                lines.append(transitions(f"{name}[{bit}]", [("X", duration)]))
        else:
            lines.append(transitions(name, [("X", duration)]))

    shown = ("clk", "rst", "run_en", "tick_1ms", "ultra_busy",
             "ultra_done", "sample_valid", "sample_distance") + outputs
    tree_index = 0
    for name in shown:
        children = widths.get(name, 0)
        child_ids = ", ".join(str(n) for n in range(
            tree_index + 1, tree_index + children + 1))
        child_line = f"\tCHILDREN = {child_ids};\n" if children else ""
        lines.append(
            "DISPLAY_LINE\n{\n"
            f'\tCHANNEL = "{name}";\n\tEXPAND_STATUS = COLLAPSED;\n'
            f"\tRADIX = Unsigned;\n\tTREE_INDEX = {tree_index};\n"
            f"\tTREE_LEVEL = 0;\n{child_line}}}\n"
        )
        parent_index = tree_index
        tree_index += 1
        for bit in range(children - 1, -1, -1):
            lines.append(
                "DISPLAY_LINE\n{\n"
                f'\tCHANNEL = "{name}[{bit}]";\n'
                "\tEXPAND_STATUS = COLLAPSED;\n\tRADIX = Unsigned;\n"
                f"\tTREE_INDEX = {tree_index};\n\tTREE_LEVEL = 1;\n"
                f"\tPARENT = {parent_index};\n}}\n"
            )
            tree_index += 1
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def make_servo_vector(path):
    """Use a real 1 MHz clock to measure five calibrated PWM anchors."""
    duration = 100_000_000
    lines = [
        "HEADER\n{\n\tVERSION = 1;\n\tTIME_UNIT = ns;\n"
        f"\tDATA_OFFSET = 0.0;\n\tDATA_DURATION = {float(duration):.1f};\n"
        f"\tSIMULATION_TIME = {float(duration):.1f};\n"
        "\tGRID_PHASE = 0.0;\n\tGRID_PERIOD = 1000.0;\n"
        "\tGRID_DUTY_CYCLE = 50;\n}\n"
    ]
    for name in ("clk", "rst", "enable"):
        lines.append(signal(name, "INPUT"))
    lines.extend(bus("scan_index", "INPUT", 6))
    lines.extend(bus("pulse_width_us", "OUTPUT", 12))
    lines.append(signal("pwm_out", "OUTPUT"))
    lines.append(
        'TRANSITION_LIST("clk")\n{\n\tNODE\n\t{\n\t\tREPEAT = 1;\n'
        f'\t\tNODE\n\t\t{{\n\t\t\tREPEAT = {duration // 1000};\n'
        '\t\t\tLEVEL 0 FOR 500.0;\n\t\t\tLEVEL 1 FOR 500.0;\n'
        '\t\t}\n\t}\n}\n'
    )
    lines.append(transitions("rst", [(1, 2_000), (0, duration - 2_000)]))
    lines.append(transitions("enable", [(0, 3_000), (1, duration - 3_000)]))
    positions = [(0, 0), (20_000_000, 9), (40_000_000, 18),
                 (60_000_000, 27), (80_000_000, 36)]
    for bit in range(5, -1, -1):
        events = [(at, (value >> bit) & 1) for at, value in positions]
        lines.append(transitions(
            f"scan_index[{bit}]", time_parts(events, duration)))
    for bit in range(11, -1, -1):
        lines.append(transitions(f"pulse_width_us[{bit}]", [("X", duration)]))
    lines.append(transitions("pwm_out", [("X", duration)]))

    widths = {"scan_index": 6, "pulse_width_us": 12}
    shown = ("clk", "rst", "enable", "scan_index", "pulse_width_us", "pwm_out")
    tree_index = 0
    for name in shown:
        children = widths.get(name, 0)
        child_ids = ", ".join(str(n) for n in range(
            tree_index + 1, tree_index + children + 1))
        child_line = f"\tCHILDREN = {child_ids};\n" if children else ""
        lines.append(
            "DISPLAY_LINE\n{\n"
            f'\tCHANNEL = "{name}";\n\tEXPAND_STATUS = COLLAPSED;\n'
            f"\tRADIX = Unsigned;\n\tTREE_INDEX = {tree_index};\n"
            f"\tTREE_LEVEL = 0;\n{child_line}}}\n"
        )
        parent_index = tree_index
        tree_index += 1
        for bit in range(children - 1, -1, -1):
            lines.append(
                "DISPLAY_LINE\n{\n"
                f'\tCHANNEL = "{name}[{bit}]";\n'
                "\tEXPAND_STATUS = COLLAPSED;\n\tRADIX = Unsigned;\n"
                f"\tTREE_INDEX = {tree_index};\n\tTREE_LEVEL = 1;\n"
                f"\tPARENT = {parent_index};\n}}\n"
            )
            tree_index += 1
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    # Search: invalid at 0, candidate at 5 degrees, confirm, then move left.
    # Recovery: target at 0 degrees is lost, skip illegal -10 degrees, find
    # an echo at +10 degrees and confirm it.
    make_vector(HERE / "target_tracker_lock.vwf", [
        (150, 1), (100, 1), (100, 1), (120, 1), (120, 1), (121, 1),
        (96, 1), (125, 1), (121, 1), (121, 0), (120, 1), (120, 1),
        (130, 1), (130, 1), (130, 1), (130, 1), (130, 1),
        (130, 1), (130, 1), (130, 1), (130, 1), (130, 1),
    ])
    # Search to 180 degrees; confirm an acquisition on the boundary.
    make_vector(HERE / "target_tracker_edge.vwf", [(150, 0)] * 36 + [
        (100, 1), (100, 1), (120, 1), (120, 1), (121, 1),
    ])
    make_flow_vector(HERE / "tracking_flow.vwf")
    make_servo_vector(HERE / "tracking_servo.vwf")
