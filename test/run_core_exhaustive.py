"""Exhaust all valid divider P/R pairs and multiplier gain/operand pairs."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    repo=Path(__file__).resolve().parent.parent
    out=(args.output or repo/'test/sim_build/core_exhaustive').resolve()
    if out.exists() and any(out.iterdir()):
        raise SystemExit('Output directory already contains evidence; choose a new attempt path.')
    out.mkdir(parents=True,exist_ok=True)
    start=time.monotonic()
    compiler=shutil.which('iverilog')
    runtime=shutil.which('vvp')
    if not compiler or not runtime:
        raise SystemExit('Install Icarus Verilog and place iverilog/vvp on PATH.')
    result=subprocess.run([compiler,'-g2012','-s','tb_core_exhaustive',
        '-o',str(out/'sim.vvp'),str(repo/'src/project.v'),
        str(repo/'test/tb_core_exhaustive.v')],capture_output=True,text=True)
    (out/'compile.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    result.check_returncode()
    result=subprocess.run([runtime,str(out/'sim.vvp')],capture_output=True,text=True)
    log=result.stdout+result.stderr
    (out/'simulation.log').write_text(log,encoding='utf-8')
    passed=result.returncode==0 and 'PASS: exhaustive' in log
    record={'passed':passed,'divider_vectors':1048576,'multiplier_vectors':133120,
            'elapsed_seconds':time.monotonic()-start,'stage':'local_RTL',
            'limitations':'Exhaustive arithmetic-domain simulation; not a formal proof of all interface histories.'}
    (out/'result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(log,end='')
    if not passed:raise SystemExit(result.returncode or 1)

if __name__=='__main__':main()
