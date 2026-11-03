import json
import random
from pathlib import Path
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, Timer


async def write_value(dut, address, value):
    for upper in (0, 1):
        await FallingEdge(dut.clk)
        dut.ui_in.value = (value >> (8 * upper)) & 255
        dut.uio_in.value = address | (upper << 2) | (1 << 3)
        await FallingEdge(dut.clk)
        dut.uio_in.value = 0


async def read_value(dut, select_p):
    word = 0
    for upper in (0, 1):
        dut.uio_in.value = (select_p << 5) | (upper << 2)
        await Timer(1, unit="ns")
        word |= int(dut.uo_out.value) << (8 * upper)
    return word & 1023


@cocotb.test()
async def test_kalman_optimized(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    assert int(dut.uio_oe.value) == 0xC0
    cases = [
        (96, 0, 64, 320), (-96, 0, 64, 320),
        (0, 64, 64, 0), (32, -64, 32, 32),
        (511, -512, 1023, 0), (-512, 511, 1023, 0),
        (0, 0, 0, 1), (80, -80, 1, 1023),
        (127, -127, 1023, 1023), (-128, 127, 255, 255),
        (0, 0, 0, 0), (1, 0, 1, 0), (-1, 0, 1, 0),
        (511, 511, 0, 1023), (-512, -512, 0, 0),
    ]
    rng = random.Random(20261101)
    for _ in range(50):
        z = rng.randrange(-512, 512)
        x = rng.randrange(-512, 512)
        p = rng.randrange(1024)
        r = rng.randrange(1024)
        cases.append((z, x, p, r))

    output_dir = Path("output")
    output_dir.mkdir(exist_ok=True)
    case_records = []
    for case_index, (z, x, p, r) in enumerate(cases):
        await write_value(dut, 0, z & 1023)
        await write_value(dut, 1, x & 1023)
        await write_value(dut, 2, p)
        await write_value(dut, 3, r)

        await FallingEdge(dut.clk)
        dut.uio_in.value = 1 << 4
        await FallingEdge(dut.clk)
        dut.uio_in.value = 0
        for cycles in range(1, 341):
            await ClockCycles(dut.clk, 1)
            await Timer(1, unit="ns")
            if int(dut.uio_out.value) & 128:
                dut._log.info(
                    f"Kalman latency = {cycles} cycles, "
                    f"{cycles * 20} ns"
                )
                break
        else:
            assert False, f"Timeout for {(z, x, p, r)}"

        k = (p << 6) // (p + r) if p + r else 0
        expected_x = (x + ((k * (z - x)) >> 6)) & 1023
        expected_p = (p - ((k * p) >> 6)) & 1023
        actual_x = await read_value(dut, 0)
        actual_p = await read_value(dut, 1)
        case_records.append({
            "case_index": case_index, "z": z, "x": x, "p": p, "r": r,
            "gain_code": k, "expected_x": expected_x, "expected_p": expected_p,
            "actual_x": actual_x, "actual_p": actual_p,
            "cycles": cycles, "clock_period_ns": 20, "latency_ns": cycles * 20,
            "path": "shortcut" if (p + r == 0 or r == 0) else "normal",
            "passed": actual_x == expected_x and actual_p == expected_p,
        })
        (output_dir / "kalman_cases.json").write_text(json.dumps({
            "version": "version8", "seed": 20261101,
            "sampling": "ClockCycles(1), then Timer(1 ns), after Start pulse end",
            "case_count": len(case_records), "cases": case_records,
        }, indent=2), encoding="utf-8")
        assert actual_x == expected_x, (z, x, p, r, "x", actual_x, expected_x)
        assert actual_p == expected_p, (z, x, p, r, "p", actual_p, expected_p)


@cocotb.test()
async def test_direct_protocol(dut):
    """Public-port checks, also run against the cloud gate-level netlist."""
    records = []
    out = Path("output/protocol_cases.json")
    out.parent.mkdir(exist_ok=True)

    async def check_values(name, expected_x, expected_p):
        actual_x = await read_value(dut, 0)
        actual_p = await read_value(dut, 1)
        passed = (actual_x, actual_p) == (expected_x & 1023, expected_p & 1023)
        records.append({"name": name, "actual_x": actual_x, "actual_p": actual_p,
                        "expected_x": expected_x & 1023, "expected_p": expected_p & 1023,
                        "passed": passed})
        out.write_text(json.dumps({"version":"version8", "cases":records}, indent=2), encoding="utf-8")
        assert passed, records[-1]

    async def start_and_wait():
        await FallingEdge(dut.clk)
        dut.uio_in.value = 16
        await FallingEdge(dut.clk)
        dut.uio_in.value = 0
        for _ in range(10):
            await ClockCycles(dut.clk, 1)
            await Timer(1, unit="ns")
            if int(dut.uio_out.value) & 128:
                return
        assert False, "Protocol update timeout"

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    await ClockCycles(dut.clk, 4)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await check_values("reset clears outputs", 0, 0)

    z, x, p, r = 96, 0, 64, 320
    for address, value in enumerate((z, x, p, r)):
        await write_value(dut, address, value)
    k = (p << 6) // (p + r)
    ex, ep = x + ((k * (z-x)) >> 6), p - ((k*p) >> 6)
    await FallingEdge(dut.clk)
    dut.uio_in.value = 16
    await FallingEdge(dut.clk)
    # Attempt to overwrite R and restart while the previous update is busy.
    dut.ui_in.value = 255
    dut.uio_in.value = 27
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)
    await Timer(1, unit="ns")
    assert int(dut.uio_out.value) & 128
    assert not (int(dut.uio_out.value) & 64)
    await check_values("busy write/start ignored", ex, ep)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)
    await Timer(1, unit="ns")
    assert int(dut.uio_out.value) & 128
    await check_values("ready and outputs remain sticky", ex, ep)
    await start_and_wait()
    await check_values("busy write did not modify next R", ex, ep)

    await FallingEdge(dut.clk)
    dut.uio_in.value = 16
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    await Timer(1, unit="ns")
    assert not (int(dut.uio_out.value) & 192)
    await check_values("reset aborts update", 0, 0)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    # R is deliberately not written: reset must have restored R=320.
    for address, value in enumerate((z, x, p)):
        await write_value(dut, address, value)
    await start_and_wait()
    await check_values("reset restores default R", ex, ep)
    await start_and_wait()
    await check_values("repeated independent update", ex, ep)
