"""Finite public-interface vectors and independent Python arithmetic reference."""
from pathlib import Path
import argparse,json,random,shutil,subprocess
from format_config import W,F,SCALE,MASK,SIGN,NORMAL,SHORTCUT,VERSION,FORMAT

def legacy65():
    rows=[(96,0,64,320),(-96,0,64,320),(0,64,64,0),(32,-64,32,32),
        (511,-512,1023,0),(-512,511,1023,0),(0,0,0,1),(80,-80,1,1023),
        (127,-127,1023,1023),(-128,127,255,255),(0,0,0,0),(1,0,1,0),
        (-1,0,1,0),(511,511,0,1023),(-512,-512,0,0)]
    rng=random.Random(20261101)
    rows += [(rng.randrange(-512,512),rng.randrange(-512,512),rng.randrange(1024),rng.randrange(1024)) for _ in range(50)]
    return rows

def common65():
    # Common Q4.5 input grid: nearest/ties-even then clamp once at Q4.5.
    # All formats receive identical real values, including endpoint clipping.
    def q(v,j):return max(-256 if j<2 else 0,min(255 if j<2 else 511,round(v/2)))
    return [tuple(q(v,j)*(1<<(F-5)) for j,v in enumerate(row)) for row in legacy65()]

def vectors():
    rows=common65()
    if F>=6:rows += [tuple(v*(1<<(F-6)) for v in row) for row in legacy65()]
    rng=random.Random(20261102)
    rows += [(rng.randrange(-SIGN,SIGN),rng.randrange(-SIGN,SIGN),rng.randrange(MASK+1),rng.randrange(MASK+1)) for _ in range(1000)]
    for address in range(4):
        for bit in range(W):
            row=[0,0,0,0];row[address]=-SIGN if address<2 and bit==W-1 else 1<<bit
            rows.append(tuple(row))
    return rows

def simple_reference(words):
    z,x,p,r=words;k=(p<<F)//(p+r) if p+r else 0
    return ((x+((k*(z-x))>>F))&MASK,(p-((k*p)>>F))&MASK)

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path);p.add_argument('--rtl',type=Path);a=p.parse_args()
    repo=Path(__file__).resolve().parent.parent;rtl=(a.rtl or repo/'src/project.v').resolve()
    out=(a.output or repo/'test/sim_build/digit_serial'/FORMAT.lower().replace('.','_')).resolve();out.mkdir(parents=True,exist_ok=True)
    cases=vectors();(out/'vectors.txt').write_text(''.join(' '.join(map(str,(*row,*simple_reference(row))))+'\n' for row in cases),encoding='ascii')
    c=subprocess.run([shutil.which('iverilog'),'-g2012','-Wall','-s','tb_digit_serial','-o',str(out/'sim.vvp'),str(rtl),str(repo/'test/tb_digit_serial.v')],capture_output=True,text=True,timeout=30)
    (out/'compile.log').write_text(c.stdout+c.stderr,encoding='utf-8');c.check_returncode()
    r=subprocess.run([shutil.which('vvp'),'sim.vvp','+VECTORS=vectors.txt',f'+NORMAL_CYCLES={NORMAL}',f'+SHORTCUT_CYCLES={SHORTCUT}'],cwd=out,capture_output=True,text=True,timeout=60)
    (out/'simulation.log').write_text(r.stdout+r.stderr,encoding='utf-8')
    passed=r.returncode==0 and 'PASS:' in r.stdout
    (out/'result.json').write_text(json.dumps(dict(version=VERSION,format=FORMAT,cases=len(cases),common_Q4_5_grid_cases=65,
        legacy65_same_real_cases=65 if F>=6 else 0,additional_random_cases=1000,bit_cases=4*W,normal_cycles=NORMAL,
        shortcut_cycles=SHORTCUT,passed=passed,kind='bounded interface replay, not exhaustive'),indent=2),encoding='utf-8')
    print(r.stdout+r.stderr,end='')
    if not passed:raise SystemExit(r.returncode or 1)
if __name__=='__main__':main()
