import json
import random
from pathlib import Path
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, Timer
from stream_model import scenarios


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
            "version": "version7", "seed": 20261101,
            "sampling": "ClockCycles(1), then Timer(1 ns), after Start pulse end",
            "case_count": len(case_records), "cases": case_records,
        }, indent=2), encoding="utf-8")
        assert actual_x == expected_x, (z, x, p, r, "x", actual_x, expected_x)
        assert actual_p == expected_p, (z, x, p, r, "p", actual_p, expected_p)


@cocotb.test()
async def test_recursive_protocol(dut):
    """Same public-port scenarios run in RTL and in the GDS gate-level job."""
    dut.ena.value=1
    dut.ui_in.value=0
    dut.uio_in.value=0
    dut.rst_n.value=0
    cocotb.start_soon(Clock(dut.clk,20,unit='ns').start())
    records=[]
    output=Path('output/recursive_cases.json')
    output.parent.mkdir(exist_ok=True)

    def save():
        output.write_text(json.dumps({'version':'version7','case_count':len(records),
            'sampling':'Start pulse end; rising edge + 1 ns',
            'reset_abort_checks':1,'cases':records},indent=2),encoding='utf-8')

    async def reset():
        await FallingEdge(dut.clk)
        dut.uio_in.value=0
        dut.rst_n.value=0
        await ClockCycles(dut.clk,3)
        await FallingEdge(dut.clk)
        dut.rst_n.value=1
        assert int(dut.uio_out.value)&0xc0==0
        assert int(dut.uio_oe.value)==0xc0

    async def extended(addr,value):
        for upper in (0,1):
            await FallingEdge(dut.clk)
            dut.ui_in.value=(value>>(8*upper))&255
            dut.uio_in.value=addr|(upper<<2)|24
            await FallingEdge(dut.clk)
            dut.uio_in.value=0

    async def update(row):
        await FallingEdge(dut.clk)
        dut.uio_in.value=16
        await FallingEdge(dut.clk)
        dut.uio_in.value=0
        for cycles in range(1,51):
            await ClockCycles(dut.clk,1)
            await Timer(1,unit='ns')
            if row.get('busy'):
                if cycles==2:
                    dut.ui_in.value=0;dut.uio_in.value=11
                elif cycles==3:dut.uio_in.value=0
                elif cycles==4:
                    dut.ui_in.value=255;dut.uio_in.value=24
                elif cycles==5:dut.uio_in.value=0
                elif cycles==6:
                    dut.ui_in.value=0;dut.uio_in.value=25
                elif cycles==7:dut.uio_in.value=0
            if int(dut.uio_out.value)&128:break
        else:
            save();assert False,'Recursive timeout'
        dut.uio_in.value=0
        ax=await read_value(dut,0);ap=await read_value(dut,1)
        passed=ax==(row['expected_x']&1023) and ap==row['expected_p']
        records.append({**row,'actual_x':ax,'actual_p':ap,'cycles':cycles,'passed':passed})
        if not passed:save()
        assert passed,records[-1]
        # UNIT_DELAY gate simulation can expose ready one observation later.
        assert cycles in (row['cycles'],row['cycles']+1),records[-1]
        await ClockCycles(dut.clk,2)
        await Timer(1,unit='ns')
        assert int(dut.uio_out.value)&0xc0==0x80

    last_q=last_r=last_mode=None
    for row in scenarios():
        if row['reset']:
            await reset()
            last_q=last_r=last_mode=None
        if row['load']:
            await write_value(dut,1,row['x']&1023)
            await write_value(dut,2,row['p'])
        if row['q']!=last_q:
            await extended(0,row['q']);last_q=row['q']
        if row['r']!=last_r:
            await write_value(dut,3,row['r']);last_r=row['r']
        if row['mode']!=last_mode:
            await extended(1,row['mode']);last_mode=row['mode']
        await write_value(dut,0,row['z']&1023)
        await update(row)
    # Reset must abort, clear Q, and restore non-feedback legacy behaviour.
    await FallingEdge(dut.clk);dut.uio_in.value=16
    await FallingEdge(dut.clk);dut.uio_in.value=0
    await ClockCycles(dut.clk,4)
    await reset()
    for addr,value in ((0,64),(1,0),(2,64),(3,64)):
        await write_value(dut,addr,value)
    for _ in range(2):
        await update({'expected_x':32,'expected_p':32,'cycles':27,
                      'mode':0,'kind':'legacy_after_abort_reset'})
    save()
