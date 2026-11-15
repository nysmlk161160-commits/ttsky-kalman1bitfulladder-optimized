"""Q4.7 numerical correctness and public-protocol history tests."""
import json
from pathlib import Path
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles,FallingEdge,Timer
from run_digit_serial import vectors

def signed11(x):
    x &= 2047
    return x-2048 if x&1024 else x

def reference(old,new=None):
    # Model the original accepted-start history: delta/S capture OLD inputs,
    # divider loads live P one edge later, final ALU reads live X/P.
    new=old if new is None else new
    z,x,p,r=old; zn,xn,pn,rn=new
    s=p+r; delta=z-x
    if s==0: gain=0
    elif pn==s: gain=128
    else:
        rem=pn;gain=0
        for _ in range(7):
            trial=rem*2;take=trial>=s
            rem=(trial-s if take else trial)&4095
            gain=((gain<<1)|int(take))&127
    return ((xn+((gain*delta)>>7))&2047,
            (pn-((gain*pn)>>7))&2047,
            23 if s==0 or pn==s else 30)

async def write_value(d,a,v,poison_upper=False):
    for hi in (0,1):
        await FallingEdge(d.clk)
        byte=((v&2047)>>(hi*8))&255
        if hi and poison_upper: byte |= 248
        d.ui_in.value=byte;d.uio_in.value=a|(hi<<2)|8
        await FallingEdge(d.clk);d.uio_in.value=0

async def read_value(d,sel):
    value=0
    for hi in (0,1):
        d.uio_in.value=(sel<<5)|(hi<<2)
        await Timer(5,unit="ns")
        byte=int(d.uo_out.value)
        if hi: assert byte&248==0
        value |= byte<<(8*hi)
    return value&2047

async def reset(d):
    await FallingEdge(d.clk);d.rst_n.value=0;d.uio_in.value=0
    await ClockCycles(d.clk,3)
    await FallingEdge(d.clk);d.rst_n.value=1

async def execute(d,words,write=True,simul=None,inject=False,poison_upper=False):
    if write:
        for a,v in enumerate(words):await write_value(d,a,v,poison_upper)
    new=list(words)
    await FallingEdge(d.clk)
    if simul is None: d.uio_in.value=16
    else:
        a,hi,byte=simul;d.ui_in.value=byte;d.uio_in.value=16|8|a|(hi<<2)
        code=new[a]&2047
        code=((code&255)|((byte&7)<<8)) if hi else ((code&1792)|(byte&255))
        new[a]=signed11(code) if a<2 else code
    await FallingEdge(d.clk);d.uio_in.value=0
    for cycles in range(1,70):
        if inject and cycles==2:d.ui_in.value=255;d.uio_in.value=31
        if inject and cycles==4:d.uio_in.value=0
        await ClockCycles(d.clk,1);await Timer(1,unit="ns")
        if int(d.uio_out.value)&128:break
    else:raise AssertionError("ready timeout")
    d.uio_in.value=0
    ax,ap=await read_value(d,0),await read_value(d,1)
    ex,ep,arch=reference(words,new)
    assert (ax,ap)==(ex,ep),(words,new,ax,ap,ex,ep)
    assert cycles in (arch,arch+1),cycles
    assert int(d.uio_out.value)&64==0
    return dict(z=words[0],x=words[1],p=words[2],r=words[3],
                accepted_input_words=words,post_write_words=new,
                expected_x=ex,expected_p=ep,actual_x=ax,actual_p=ap,
                cycles=cycles,clock_period_ns=20,path="normal" if arch==30 else "shortcut",
                passed=True),new

@cocotb.test()
async def test_q4_7(d):
    d.ena.value=1;d.ui_in.value=0;d.uio_in.value=0;d.rst_n.value=0
    cocotb.start_soon(Clock(d.clk,20,unit="ns").start())
    await reset(d);assert int(d.uio_oe.value)==192
    out=Path("output");out.mkdir(exist_ok=True)
    records=[]
    for index,words in enumerate(vectors()):
        rec,_=await execute(d,words);rec['case_index']=index
        rec['suite']="legacy65_same_real_inputs" if index<65 else "random1000" if index<1065 else "bit48"
        records.append(rec)
        (out/'kalman_cases.json').write_text(json.dumps(dict(version="version11",format="Q4.7/UQ4.7",fraction_bits=8,
            sampling="ClockCycles(1), then Timer(1ns), after start pulse end",case_count=len(records),cases=records),indent=2),encoding='utf-8')
    protocol=[]
    def save():
        (out/'protocol_cases.json').write_text(json.dumps(dict(version="version11",case_count=len(protocol),cases=protocol),indent=2),encoding='utf-8')
    # 24 histories explicitly cover writes and start accepted on one edge.
    for a in range(4):
        for hi in (0,1):
            for words,byte in [((200,-100,0,1),0),((-1024,1023,2047,0),255),((511,-512,1023,1024),85)]:
                rec,new=await execute(d,words,simul=(a,hi,byte))
                rec.update(name="idle simultaneous write/start",address=a,upper=hi,byte=byte)
                protocol.append(rec);save()
    # The original diagnostic follow-up counterexample is a mandatory case.
    rec,_=await execute(d,(0,0,0,1),simul=(3,0,0))
    assert rec['cycles'] in (30,31)
    protocol.append(dict(name="old R captured while new R written",**rec));save()
    rec,_=await execute(d,(192,-128,1554,640),inject=True)
    protocol.append(dict(name="busy write and repeated start ignored",**rec));save()
    for _ in range(4):
        await ClockCycles(d.clk,1);await Timer(1,unit="ns")
        assert int(d.uio_out.value)&128
    protocol.append(dict(name="sticky ready",passed=True));save()
    rec,_=await execute(d,(192,-128,1554,640),write=False)
    protocol.append(dict(name="repeat start retains original X/P inputs",**rec));save()
    rec,_=await execute(d,(-1024,1023,2047,2047),poison_upper=True)
    protocol.append(dict(name="upper write ignores ui_in bits7to4",**rec));save()
    for delay in (2,14,27):
        for a,v in enumerate((192,-128,1554,640)):await write_value(d,a,v)
        await FallingEdge(d.clk);d.uio_in.value=16
        await FallingEdge(d.clk);d.uio_in.value=0
        await ClockCycles(d.clk,delay)
        await reset(d);await Timer(5,unit="ns")
        assert int(d.uio_out.value)==0
        assert await read_value(d,0)==0 and await read_value(d,1)==0
        protocol.append(dict(name="reset abort",delay=delay,passed=True));save()
    # Restore R=640 means real variance5, not old integer code320.
    for a,v in enumerate((192,0,128)):await write_value(d,a,v)
    rec,_=await execute(d,(192,0,128,640),write=False)
    protocol.append(dict(name="default real R5 restored as code1280",**rec));save()
    assert len({c['cycles'] for c in records if c['path']=='normal'})==1
    assert len({c['cycles'] for c in records if c['path']=='shortcut'})==1
