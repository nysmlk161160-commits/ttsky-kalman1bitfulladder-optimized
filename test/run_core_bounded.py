"""Boundary Cartesian panels plus exactly 1000 seeded random cases per core."""
from pathlib import Path
import argparse,json,random,shutil,subprocess
from format_config import W,SCALE,GAIN_F,GAIN_SCALE,MASK,VERSION,FORMAT

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path);a=p.parse_args();repo=Path(__file__).resolve().parent.parent
    out=(a.output or repo/'test/sim_build/core_bounded').resolve();out.mkdir(parents=True,exist_ok=True)
    boundary=sorted({v for v in (0,1,2,3,SCALE-1,SCALE,SCALE+1,255,256,(1<<(W-1))-1,1<<(W-1),MASK-1,MASK) if 0<=v<=MASK})
    div=[(p,r) for p in boundary for r in boundary];rng=random.Random(20261115)
    div += [(rng.randrange(MASK+1),rng.randrange(MASK+1)) for _ in range(1000)]
    operands=sorted({-(1<<W),-(1<<W)+1,-(1<<(W-1))-1,-(1<<(W-1)),-SCALE,-1,0,1,SCALE-1,(1<<(W-1))-1,1<<(W-1),(1<<W)-1})
    gains=sorted({0,1,2,3,GAIN_SCALE//2-1,GAIN_SCALE//2,GAIN_SCALE//2+1,GAIN_SCALE-2,GAIN_SCALE-1,GAIN_SCALE})
    mul=[(g,b) for g in gains for b in operands]
    mul += [(rng.randrange(GAIN_SCALE+1),rng.randrange(-(1<<W),1<<W)) for _ in range(1000)]
    (out/'divider_vectors.txt').write_text(''.join(f'{p} {r} {(p<<GAIN_F)//(p+r) if p+r else 0}\n' for p,r in div),encoding='ascii')
    (out/'multiplier_vectors.txt').write_text(''.join(f'{g} {b} {(g*b)>>GAIN_F}\n' for g,b in mul),encoding='ascii')
    c=subprocess.run([shutil.which('iverilog'),'-g2012','-Wall','-s','tb_core_bounded','-o',str(out/'sim.vvp'),str(repo/'src/project.v'),str(repo/'test/tb_core_bounded.v')],capture_output=True,text=True,timeout=30)
    (out/'compile.log').write_text(c.stdout+c.stderr,encoding='utf-8');c.check_returncode()
    r=subprocess.run([shutil.which('vvp'),'sim.vvp'],cwd=out,capture_output=True,text=True,timeout=60)
    (out/'simulation.log').write_text(r.stdout+r.stderr,encoding='utf-8');passed=r.returncode==0 and 'PASS:' in r.stdout
    (out/'result.json').write_text(json.dumps(dict(version=VERSION,format=FORMAT,passed=passed,kind='bounded boundary+1000random per core, not exhaustive',
        divider_vectors=len(div),multiplier_vectors=len(mul),seed=20261115),indent=2),encoding='utf-8')
    print(r.stdout+r.stderr,end='')
    if not passed:raise SystemExit(r.returncode or 1)
if __name__=='__main__':main()
