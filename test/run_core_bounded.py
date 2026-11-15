"""Bounded core checks: directed boundaries and fixed random inputs."""
from pathlib import Path
import argparse,json,random,shutil,subprocess
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path);a=p.parse_args()
 repo=Path(__file__).resolve().parent.parent
 out=(a.output or repo/'test/sim_build/core_bounded').resolve();out.mkdir(parents=True,exist_ok=True)
 boundary=[0,1,2,3,63,64,127,128,255,256,1023,1024,2046,2047]
 div=[(p,r) for p in boundary for r in boundary]
 rng=random.Random(20261115)
 div += [(rng.randrange(2048),rng.randrange(2048)) for _ in range(1000)]
 operands=[-2048,-2047,-1025,-1024,-128,-1,0,1,127,1023,1024,2047]
 mul=[(g,b) for g in range(129) for b in operands]
 mul += [(rng.randrange(129),rng.randrange(-2048,2048)) for _ in range(1000)]
 (out/'divider_vectors.txt').write_text(''.join(f'{p} {r} {(p<<7)//(p+r) if p+r else 0}\n' for p,r in div),encoding='ascii')
 (out/'multiplier_vectors.txt').write_text(''.join(f'{g} {b} {(g*b)>>7}\n' for g,b in mul),encoding='ascii')
 c=subprocess.run([shutil.which('iverilog'),'-g2012','-Wall','-s','tb_core_bounded','-o',str(out/'sim.vvp'),str(repo/'src/project.v'),str(repo/'test/tb_core_bounded.v')],capture_output=True,text=True)
 (out/'compile.log').write_text(c.stdout+c.stderr,encoding='utf-8');c.check_returncode()
 r=subprocess.run([shutil.which('vvp'),'sim.vvp'],cwd=out,capture_output=True,text=True,timeout=60)
 (out/'simulation.log').write_text(r.stdout+r.stderr,encoding='utf-8')
 passed=r.returncode==0 and 'PASS:' in r.stdout
 (out/'result.json').write_text(json.dumps(dict(passed=passed,kind='bounded directed+seeded random, not exhaustive',divider_vectors=len(div),multiplier_vectors=len(mul),seed=20261115),indent=2),encoding='utf-8')
 print(r.stdout+r.stderr,end='')
 if not passed:raise SystemExit(r.returncode or 1)
if __name__=='__main__':main()
