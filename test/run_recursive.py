"""Verify recursive features through public ports and preserve observed samples."""
import argparse
import csv
import json
import math
from pathlib import Path
import shutil
import subprocess
from stream_model import scenarios

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    repo=Path(__file__).resolve().parent.parent
    out=(args.output or repo/'test/sim_build/recursive').resolve()
    if out.exists() and any(out.iterdir()):
        raise SystemExit('Output directory already contains evidence; choose a new attempt path.')
    out.mkdir(parents=True,exist_ok=True)
    rows=scenarios()
    keys=('reset','mode','q','z','load','x','p','r','expected_x','expected_p','cycles','busy')
    (out/'vectors.txt').write_text('\n'.join(' '.join(str(int(row[k])) for k in keys) for row in rows)+'\n',encoding='ascii')
    (out/'expected.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    result=subprocess.run([shutil.which('iverilog'),'-g2012','-s','tb_recursive',
        '-o',str(out/'sim.vvp'),str(repo/'src/project.v'),str(repo/'test/tb_recursive.v')],capture_output=True,text=True)
    (out/'compile.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    result.check_returncode()
    result=subprocess.run([shutil.which('vvp'),'sim.vvp','+VECTORS=vectors.txt'],cwd=out,capture_output=True,text=True)
    log=result.stdout+result.stderr
    (out/'simulation.log').write_text(log,encoding='utf-8');print(log,end='')
    passed=result.returncode==0 and 'PASS:' in log
    data=list(csv.DictReader((out/'observed.csv').open()))
    for row,actual in zip(rows,data):
        row.update(actual_x=int(actual['actual_x']),actual_p=int(actual['actual_p']),actual_cycles=int(actual['cycles']))
    signal=[r for r in rows if r['truth'] is not None and 'actual_x' in r]
    sign=lambda x:x-1024 if x>=512 else x
    rmse=lambda f:math.sqrt(sum(f(r)**2 for r in signal)/len(signal)) if signal else None
    record={'version':'version7','stage':'local_RTL','passed':passed,'sample_count':len(data),
        'saturation_cases':sum(r['saturated'] for r in rows),'busy_write_cases':sum(bool(r['busy']) for r in rows),
        'abort_reset_sequences':1,'post_reset_legacy_samples':2,'workload_samples':len(signal),
        'measurement_rmse':rmse(lambda r:r['z']/64-r['truth']),
        'filter_rmse':rmse(lambda r:sign(r['actual_x'])/64-r['truth']),
        'cases':rows,'limitations':'Seeded synthetic workload; no universal filtering accuracy claim.'}
    (out/'result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    if not passed:raise SystemExit(result.returncode or 1)

if __name__=='__main__':main()
