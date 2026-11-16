"""Exactly 25 public-port simultaneous write/start histories."""
from pathlib import Path
import argparse,json,shutil,subprocess
from format_config import W,F,SCALE,MASK,SIGN,HIGH_MASK,NORMAL,SHORTCUT,VERSION,FORMAT

def expected(old,new):
    z,x,p,r=old;_,xn,pn,_=new;s=p+r
    if s==0:g=0
    elif pn==s:g=SCALE
    else:
        rem=pn;g=0
        for _ in range(F):
            trial=rem*2;take=trial>=s
            rem=(trial-s if take else trial)&((1<<(W+1))-1);g=((g<<1)|int(take))&(SCALE-1)
    return ((xn+((g*(z-x))>>F))&MASK,(pn-((g*pn)>>F))&MASK,SHORTCUT if s==0 or pn==s else NORMAL)

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path);args=p.parse_args();repo=Path(__file__).resolve().parent.parent
    out=(args.output or repo/'test/sim_build/simultaneous').resolve();out.mkdir(parents=True,exist_ok=True)
    records=[];lines=[]
    histories=[((min(200,SIGN-1),max(-100,-SIGN),0,1),0),((-SIGN,SIGN-1,MASK,0),255),((SIGN//2-1,-SIGN//2,MASK//2,SIGN),85)]
    for a in range(4):
        for hi in (0,1):
            for old,byte in histories:
                new=list(old);v=new[a]&MASK
                v=((v&255)|((byte&HIGH_MASK)<<8)) if hi else ((v&(MASK^255))|byte)
                new[a]=v-(MASK+1) if a<2 and v&SIGN else v
                ex,ep,cycles=expected(old,new)
                lines.append(' '.join(map(str,(*old,a,hi,byte,ex,ep,cycles))))
                records.append(dict(old=old,new=new,address=a,upper=hi,byte=byte,expected_x=ex,expected_p=ep,cycles=cycles))
    ex,ep,cycles=expected((0,0,0,1),(0,0,0,0));lines.append(f'0 0 0 1 3 0 0 {ex} {ep} {cycles}')
    records.append(dict(old=(0,0,0,1),new=(0,0,0,0),cycles=cycles));assert len(lines)==25
    (out/'vectors.txt').write_text('\n'.join(lines)+'\n',encoding='ascii')
    tb=(repo/'test/tb_digit_serial.v').read_text(encoding='utf-8')
    tb=tb.replace('    integer fd, scan, case_index','    integer address,upper,byte_value;\n    integer fd, scan, case_index')
    tb=tb.replace('"%d %d %d %d %d %d\\n", z, x, p, r, expected_x, expected_p','"%d %d %d %d %d %d %d %d %d %d\\n", z, x, p, r, address, upper, byte_value, expected_x, expected_p, expected_cycles')
    tb=tb.replace('scan != 6','scan != 10').replace('            uio_in = 16;','            ui_in = byte_value;\n            uio_in = 16 | 8 | address | (upper << 2);')
    tb=tb.replace('            expected_cycles = ((p + r == 0) || (r == 0)) ? shortcut_cycles : normal_cycles;','')
    (out/'tb_simultaneous.v').write_text(tb,encoding='utf-8')
    c=subprocess.run([shutil.which('iverilog'),'-g2012','-s','tb_digit_serial','-o',str(out/'sim.vvp'),str(repo/'src/project.v'),str(out/'tb_simultaneous.v')],capture_output=True,text=True,timeout=30)
    (out/'compile.log').write_text(c.stdout+c.stderr,encoding='utf-8');c.check_returncode()
    r=subprocess.run([shutil.which('vvp'),'sim.vvp','+VECTORS=vectors.txt',f'+NORMAL_CYCLES={NORMAL}',f'+SHORTCUT_CYCLES={SHORTCUT}'],cwd=out,capture_output=True,text=True,timeout=60)
    (out/'simulation.log').write_text(r.stdout+r.stderr,encoding='utf-8');passed=r.returncode==0 and 'PASS:' in r.stdout
    (out/'result.json').write_text(json.dumps(dict(version=VERSION,format=FORMAT,cases=25,passed=passed,records=records),indent=2),encoding='utf-8')
    print(r.stdout+r.stderr,end='')
    if not passed:raise SystemExit(r.returncode or 1)
if __name__=='__main__':main()
