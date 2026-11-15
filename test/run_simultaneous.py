"""Public-port test for IDLE writes and start accepted on the same edge."""
from pathlib import Path
import argparse,json,shutil,subprocess

def expected(old,new):
    z,x,p,r=old;_,xn,pn,_=new;s=p+r
    if s==0:g=0
    elif pn==s:g=128
    else:
        rem=pn;g=0
        for _ in range(7):
            trial=rem*2;take=trial>=s
            rem=(trial-s if take else trial)&4095;g=((g<<1)|int(take))&127
    return ((xn+((g*(z-x))>>7))&2047,(pn-((g*pn)>>7))&2047,23 if s==0 or pn==s else 30)

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path);args=p.parse_args()
    repo=Path(__file__).resolve().parent.parent
    out=(args.output or repo/'test/sim_build/simultaneous').resolve();out.mkdir(parents=True,exist_ok=True)
    records=[];lines=[]
    for a in range(4):
        for hi in (0,1):
            for old,byte in [((200,-100,0,1),0),((-1024,1023,2047,0),255),((511,-512,1023,1024),85)]:
                new=list(old);v=new[a]&2047
                v=((v&255)|((byte&7)<<8)) if hi else ((v&1792)|byte)
                new[a]=v-2048 if a<2 and v&1024 else v
                ex,ep,cycles=expected(old,new)
                lines.append(' '.join(str(v) for v in (*old,a,hi,byte,ex,ep,cycles)))
                records.append(dict(old=old,new=new,address=a,upper=hi,byte=byte,expected_x=ex,expected_p=ep,cycles=cycles))
    old=(0,0,0,1);new=(0,0,0,0);ex,ep,cycles=expected(old,new)
    lines.append(f'0 0 0 1 3 0 0 {ex} {ep} {cycles}')
    records.append(dict(old=old,new=new,address=3,upper=0,byte=0,expected_x=ex,expected_p=ep,cycles=cycles))
    (out/'vectors.txt').write_text('\n'.join(lines)+'\n',encoding='ascii')
    tb=(repo/'test/tb_digit_serial.v').read_text(encoding='utf-8')
    tb=tb.replace('    integer fd, scan, case_index','    integer address,upper,byte_value;\n    integer fd, scan, case_index')
    tb=tb.replace('"%d %d %d %d %d %d\\n", z, x, p, r, expected_x, expected_p','"%d %d %d %d %d %d %d %d %d %d\\n", z, x, p, r, address, upper, byte_value, expected_x, expected_p, expected_cycles')
    tb=tb.replace('scan != 6','scan != 10')
    tb=tb.replace('            uio_in = 16;','            ui_in = byte_value;\n            uio_in = 16 | 8 | address | (upper << 2);')
    tb=tb.replace('            expected_cycles = ((p + r == 0) || (r == 0)) ? shortcut_cycles : normal_cycles;','')
    (out/'tb_simultaneous.v').write_text(tb,encoding='utf-8')
    c=subprocess.run([shutil.which('iverilog'),'-g2012','-s','tb_digit_serial','-o',str(out/'sim.vvp'),str(repo/'src/project.v'),str(out/'tb_simultaneous.v')],capture_output=True,text=True)
    (out/'compile.log').write_text(c.stdout+c.stderr,encoding='utf-8');c.check_returncode()
    r=subprocess.run([shutil.which('vvp'),'sim.vvp','+VECTORS=vectors.txt','+NORMAL_CYCLES=30','+SHORTCUT_CYCLES=23'],cwd=out,capture_output=True,text=True)
    (out/'simulation.log').write_text(r.stdout+r.stderr,encoding='utf-8')
    passed=r.returncode==0 and 'PASS:' in r.stdout
    result=dict(kind='public-port simultaneous-write-start histories',cases=len(records),passed=passed,records=records)
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(r.stdout+r.stderr,end='')
    if not passed:raise SystemExit(r.returncode or 1)

if __name__=='__main__':main()
