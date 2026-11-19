"""Finite arithmetic and public protocol histories; UNIT_DELAY GL uses same observer."""
from pathlib import Path
import json,cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles,FallingEdge,Timer
from format_config import W,F,SCALE,MASK,SIGN,HIGH_MASK,HIGH_UNUSED,NORMAL,SHORTCUT,VERSION,FORMAT
from run_digit_serial import vectors,simple_reference

def signed(v):
    v &= MASK
    return v-(MASK+1) if v&SIGN else v

def reference(old,new=None):
    # Original nonblocking history: capture old delta/S, then use live P and X.
    new=old if new is None else new;z,x,p,r=old;_,xn,pn,_=new;s=p+r
    if s==0:g=0
    elif pn==s:g=SCALE
    else:
        rem=pn;g=0
        for _ in range(F):
            trial=rem*2;take=trial>=s
            rem=(trial-s if take else trial)&((1<<(W+1))-1)
            g=((g<<1)|int(take))&(SCALE-1)
    return ((xn+((g*(z-x))>>F))&MASK,(pn-((g*pn)>>F))&MASK,SHORTCUT if s==0 or pn==s else NORMAL)

def histories():
    return [((min(200,SIGN-1),max(-100,-SIGN),0,1),0),((-SIGN,SIGN-1,MASK,0),255),
        ((SIGN//2-1,-SIGN//2,MASK//2,SIGN),85)]

async def write_value(d,a,v,poison_upper=False):
    for hi in (0,1):
        await FallingEdge(d.clk);byte=((v&MASK)>>(hi*8))&255
        if hi and poison_upper:byte |= HIGH_UNUSED
        d.ui_in.value=byte;d.uio_in.value=a|(hi<<2)|8
        await FallingEdge(d.clk);d.uio_in.value=0

async def read_value(d,sel):
    value=0
    for hi in (0,1):
        d.uio_in.value=(sel<<5)|(hi<<2);await Timer(5,unit='ns');byte=int(d.uo_out.value)
        if hi:assert byte&HIGH_UNUSED==0
        value |= byte<<(8*hi)
    return value&MASK

async def reset(d):
    await FallingEdge(d.clk);d.rst_n.value=0;d.uio_in.value=0
    await ClockCycles(d.clk,3)
    await FallingEdge(d.clk);d.rst_n.value=1

async def execute(d,words,write=True,simul=None,inject=False,poison_upper=False):
    if write:
        for a,v in enumerate(words):await write_value(d,a,v,poison_upper)
    new=list(words);await FallingEdge(d.clk)
    if simul is None:d.uio_in.value=16
    else:
        a,hi,byte=simul;d.ui_in.value=byte;d.uio_in.value=16|8|a|(hi<<2);code=new[a]&MASK
        code=((code&255)|((byte&HIGH_MASK)<<8)) if hi else ((code&(MASK^255))|(byte&255))
        new[a]=signed(code) if a<2 else code
    await FallingEdge(d.clk);d.uio_in.value=0
    for cycles in range(1,NORMAL+12):
        if inject and cycles==2:d.ui_in.value=255;d.uio_in.value=31
        if inject and cycles==4:d.uio_in.value=0
        await ClockCycles(d.clk,1);await Timer(1,unit='ns')
        if int(d.uio_out.value)&128:break
    else:raise AssertionError('ready timeout')
    d.uio_in.value=0;ax,ap=await read_value(d,0),await read_value(d,1);ex,ep,arch=reference(words,new)
    if simul is None:assert (ex,ep)==simple_reference(words)
    assert (ax,ap)==(ex,ep),(words,new,ax,ap,ex,ep)
    assert cycles in (arch,arch+1),cycles
    assert int(d.uio_out.value)&64==0
    return dict(z=words[0],x=words[1],p=words[2],r=words[3],accepted_input_words=words,post_write_words=new,
        expected_x=ex,expected_p=ep,actual_x=ax,actual_p=ap,cycles=cycles,clock_period_ns=16.666,implementation_clock_period_ns=16.666666667,
        path='normal' if arch==NORMAL else 'shortcut',passed=True),new

@cocotb.test()
async def test_format(d):
    d.ena.value=1;d.ui_in.value=0;d.uio_in.value=0;d.rst_n.value=0
    cocotb.start_soon(Clock(d.clk,16666,unit='ps').start());await reset(d)
    assert int(d.uio_oe.value)==192
    out=Path('output');out.mkdir(exist_ok=True);records=[]
    for index,words in enumerate(vectors()):
        rec,_=await execute(d,words);rec['case_index']=index
        rec['suite']='common_Q3_5_grid65' if index<65 else 'legacy65_encoded_or_clipped' if F>=6 and index<130 else 'bounded_random_or_bit'
        records.append(rec)
        (out/'kalman_cases.json').write_text(json.dumps(dict(version=VERSION,format=FORMAT,fraction_bits=F,data_bits=W,
            sampling='ClockCycles(1), Timer(1ns), after start pulse end',case_count=len(records),cases=records),indent=2),encoding='utf-8')
    protocol=[]
    def save():
        (out/'protocol_cases.json').write_text(json.dumps(dict(version=VERSION,case_count=len(protocol),cases=protocol),indent=2),encoding='utf-8')
    for a in range(4):
        for hi in (0,1):
            for words,byte in histories():
                rec,_=await execute(d,words,simul=(a,hi,byte));rec.update(name='idle simultaneous write/start',address=a,upper=hi,byte=byte)
                protocol.append(rec);save()
    rec,_=await execute(d,(0,0,0,1),simul=(3,0,0));assert rec['cycles'] in (NORMAL,NORMAL+1)
    protocol.append(dict(name='old R captured while new R written',**rec));save()
    words=(3*SCALE//2,-SCALE,min(MASK,12*SCALE+SCALE//8),5*SCALE)
    rec,_=await execute(d,words,inject=True);protocol.append(dict(name='busy writes/start ignored',**rec));save()
    for _ in range(4):
        await ClockCycles(d.clk,1);await Timer(1,unit='ns');assert int(d.uio_out.value)&128
    protocol.append(dict(name='sticky ready',passed=True));save()
    rec,_=await execute(d,words,write=False);protocol.append(dict(name='repeat start retained X/P inputs',**rec));save()
    rec,_=await execute(d,(-SIGN,SIGN-1,MASK,MASK),poison_upper=True)
    protocol.append(dict(name='upper write mask and zeroed readback',**rec));save()
    for delay in (2,F+5,2*F+9):
        for a,v in enumerate(words):await write_value(d,a,v)
        await FallingEdge(d.clk);d.uio_in.value=16
        await FallingEdge(d.clk);d.uio_in.value=0
        await ClockCycles(d.clk,delay);await reset(d);await Timer(5,unit='ns')
        assert int(d.uio_out.value)==0
        assert await read_value(d,0)==0 and await read_value(d,1)==0
        protocol.append(dict(name='reset abort',delay=delay,passed=True));save()
    default=(3*SCALE//2,0,SCALE,5*SCALE)
    for a,v in enumerate(default[:3]):await write_value(d,a,v)
    rec,_=await execute(d,default,write=False);protocol.append(dict(name='default real R5 restored',**rec));save()
    assert len(protocol)==33

@cocotb.test()
async def test_public_storage_trace(d):
    from public_trace_vectors import vectors,CYCLES,SEED
    from cocotb.triggers import RisingEdge
    d.ena.value=1;d.ui_in.value=0;d.uio_in.value=0;d.rst_n.value=0
    cocotb.start_soon(Clock(d.clk,16666,unit='ps').start())
    expected=[int(x,16) for x in Path('public_trace_expected.hex').read_text(encoding='ascii').splitlines()]
    stimuli=vectors();assert len(expected)==len(stimuli)==CYCLES
    records=[];out=Path('output');out.mkdir(exist_ok=True)
    try:
        for i,(rst,ena,ui,uio,tag) in enumerate(stimuli):
            await FallingEdge(d.clk)
            d.rst_n.value=rst;d.ena.value=ena;d.ui_in.value=ui;d.uio_in.value=uio
            await RisingEdge(d.clk);await Timer(5,unit='ns')
            actual=(int(d.uo_out.value)<<16)|(int(d.uio_out.value)<<8)|int(d.uio_oe.value)
            records.append(dict(index=i,inputs=(rst,ena,ui,uio),tag=tag,expected=expected[i],actual=actual,passed=actual==expected[i]))
            assert actual==expected[i],(i,tag,hex(actual),hex(expected[i]))
    finally:
        (out/'public_trace_cases.json').write_text(json.dumps(dict(version=VERSION,cycles=len(records),seed=SEED,
            golden_commit='364c52d1b72f4f0ec7db6360e24cceffe370c8cf',
            sampling='5ns after rising edge; stimulus at prior falling edge; compare all three public output buses',
            cases=records),indent=2),encoding='utf-8')
