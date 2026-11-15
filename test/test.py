"""V9 diagnostic: functional signatures and baseline-compatible schedule.

Original 65 stimuli are retained, but expected data intentionally differ.
No result here is a Kalman numerical-accuracy claim.
"""
import json
from pathlib import Path
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, Timer
from run_diagnostic import vectors

async def write_value(dut, address, value):
    for upper in (0, 1):
        await FallingEdge(dut.clk)
        dut.ui_in.value = ((value & 1023) >> (8 * upper)) & 255
        dut.uio_in.value = address | (upper << 2) | 8
        await FallingEdge(dut.clk)
        dut.uio_in.value = 0

async def read_value(dut, select_p):
    word = 0
    for upper in (0, 1):
        dut.uio_in.value = (select_p << 5) | (upper << 2)
        await Timer(2, unit="ns")
        word |= int(dut.uo_out.value) << (8 * upper)
    return word & 1023

async def reset(dut):
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1

async def update(dut, z, x, p, r, inject_busy=False):
    for a,v in enumerate((z,x,p,r)): await write_value(dut,a,v)
    await FallingEdge(dut.clk)
    dut.uio_in.value = 16
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0
    for cycles in range(1, 60):
        if inject_busy and cycles == 2:
            dut.ui_in.value = 255
            dut.uio_in.value = 31  # Busy write to R and repeated start.
        if inject_busy and cycles == 4: dut.uio_in.value = 0
        await ClockCycles(dut.clk, 1)
        await Timer(1, unit="ns")
        if int(dut.uio_out.value) & 128: break
    else: raise AssertionError("Diagnostic timeout")
    dut.uio_in.value = 0
    actual_x,actual_p = await read_value(dut,0),await read_value(dut,1)
    expected_x,expected_p = (z ^ x) & 1023,(p ^ r) & 1023
    assert (actual_x,actual_p)==(expected_x,expected_p)
    assert not (int(dut.uio_out.value) & 64)
    assert cycles in ((21,22) if r==0 else (27,28)), cycles
    return dict(z=z,x=x,p=p,r=r,expected_x=expected_x,expected_p=expected_p,
                actual_x=actual_x,actual_p=actual_p,cycles=cycles,
                path="shortcut" if r==0 else "normal",passed=True)

@cocotb.test()
async def test_diagnostic(dut):
    dut.ena.value=1; dut.ui_in.value=0; dut.uio_in.value=0; dut.rst_n.value=0
    cocotb.start_soon(Clock(dut.clk,20,unit="ns").start())
    await reset(dut)
    assert int(dut.uio_oe.value)==192
    out=Path("output");out.mkdir(exist_ok=True)
    records=[]
    for index,row in enumerate(vectors()):
        record=await update(dut,*row)
        record['case_index']=index;records.append(record)
        (out/'diagnostic_cases.json').write_text(json.dumps(dict(
            version="version9",kind="XOR diagnostic, not Kalman",clock_period_ns=20,
            sampling="ClockCycles(1) then Timer(1ns), after start pulse end",
            case_count=len(records),cases=records),indent=2),encoding='utf-8')
    protocol=[]
    await update(dut,96,-64,777,320,True)
    protocol.append(dict(name="busy writes and repeated start ignored",passed=True))
    for _ in range(4):
        await ClockCycles(dut.clk,1);await Timer(1,unit="ns")
        assert int(dut.uio_out.value)&128
    protocol.append(dict(name="ready sticky",passed=True))
    # Start and abort while arithmetic timer is active.
    await FallingEdge(dut.clk);dut.uio_in.value=16
    await FallingEdge(dut.clk);dut.uio_in.value=0
    await ClockCycles(dut.clk,5)
    await reset(dut)
    await Timer(2,unit="ns")
    assert int(dut.uio_out.value)==0
    assert await read_value(dut,0)==0 and await read_value(dut,1)==0
    protocol.append(dict(name="reset abort and clears outputs/status",passed=True))
    # No register writes after reset: restored default R must appear in signature.
    await FallingEdge(dut.clk);dut.uio_in.value=16
    await FallingEdge(dut.clk);dut.uio_in.value=0
    for cycles in range(1,60):
        await ClockCycles(dut.clk,1);await Timer(1,unit="ns")
        if int(dut.uio_out.value)&128:break
    assert cycles in (27,28)
    assert await read_value(dut,0)==0 and await read_value(dut,1)==320
    protocol.append(dict(name="default R restored",passed=True))
    await update(dut,-512,511,1023,0)
    await update(dut,511,-512,0,1023)
    protocol.append(dict(name="back-to-back updates and both paths",passed=True))
    (out/'diagnostic_protocol.json').write_text(json.dumps(dict(
        scenarios=protocol,passed=True),indent=2),encoding='utf-8')
