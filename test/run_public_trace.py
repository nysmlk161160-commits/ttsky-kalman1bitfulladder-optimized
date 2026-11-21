"""Cycle-by-cycle golden/candidate comparison; no exhaustive input sweep."""
from pathlib import Path
import argparse,json,hashlib,shutil,subprocess,collections
from public_trace_vectors import vectors,CYCLES,SEED
from format_config import VERSION

TB=r'''`timescale 1ns/1ps
module tb_public_trace;
 reg clk=0; always #10 clk=~clk;
 reg rst_n=0,ena=1;reg [7:0] ui_in=0,uio_in=0;
 wire [7:0] guo,guio,goe,duo,duio,doe;
 golden_tt_um_example golden(ui_in,guo,uio_in,guio,goe,ena,clk,rst_n);
 tt_um_example dut(ui_in,duo,uio_in,duio,doe,ena,clk,rst_n);
 integer fd,scan,i=0,ri,ei,uii,uioi;
 initial begin
  fd=$fopen("stimulus.txt","r");if(!fd)$fatal(1,"missing stimulus");
  while(!$feof(fd))begin
   scan=$fscanf(fd,"%d %d %d %d\n",ri,ei,uii,uioi);if(scan!=4)$fatal(1,"bad stimulus");
   @(negedge clk);rst_n=ri;ena=ei;ui_in=uii;uio_in=uioi;
   @(posedge clk);#5;
   $display("TRACE %0d %06h %06h %0d",i,{guo,guio,goe},{duo,duio,doe},golden.state);
   if({guo,guio,goe}!=={duo,duio,doe})$fatal(1,"public port mismatch cycle %0d",i);
   if(rst_n)begin
    if(dut.shared_work.div_running && dut.shared_work.mul_running)$fatal(1,"overlapping work ownership");
    if(golden.state==2)begin
     if(dut.shared_work.denominator!==golden.s)$fatal(1,"S mismatch");
     if(dut.shared_work.remainder!==golden.divider.remainder)$fatal(1,"remainder mismatch");
    end
    if(golden.state==4 || golden.state==6)
     if(dut.shared_work.product!==golden.multiplier.product)$fatal(1,"product mismatch");
    if(golden.state>=2)
     if(dut.div_result!==golden.div_result)$fatal(1,"retained gain mismatch");
   end
   i=i+1;
  end
  $display("PASS: %0d public trace cycles",i);$finish;
 end
endmodule
'''

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path);p.add_argument('--generate-fixture',action='store_true');p.add_argument('--verify-fixture',action='store_true');a=p.parse_args()
    repo=Path(__file__).resolve().parent.parent;out=(a.output or repo/'test/sim_build/public_trace').resolve();out.mkdir(parents=True,exist_ok=True)
    rows=vectors();(out/'stimulus.txt').write_text(''.join(' '.join(map(str,r[:4]))+'\n' for r in rows),encoding='ascii')
    (out/'tb_public_trace.v').write_text(TB,encoding='utf-8')
    golden=(repo/'test/golden_q4_10.v').read_text(encoding='utf-8')
    old_reset="r <= 14'd5120;"
    assert golden.count(old_reset)==1
    golden_q59=out/'golden_q5_9.v'
    golden_q59.write_text(golden.replace(old_reset,"r <= 14'd2560;"),encoding='utf-8')
    c=subprocess.run([shutil.which('iverilog'),'-g2012','-s','tb_public_trace','-o',str(out/'sim.vvp'),str(repo/'src/project.v'),str(golden_q59),str(out/'tb_public_trace.v')],capture_output=True,text=True,timeout=30)
    (out/'compile.log').write_text(c.stdout+c.stderr,encoding='utf-8');c.check_returncode()
    r=subprocess.run([shutil.which('vvp'),'sim.vvp'],cwd=out,capture_output=True,text=True,timeout=60)
    (out/'simulation.log').write_text(r.stdout+r.stderr,encoding='utf-8')
    records=[];states=collections.Counter();selectors=collections.defaultdict(set)
    for line in r.stdout.splitlines():
        if not line.startswith('TRACE '):continue
        _,index,exp,actual,state=line.split();i=int(index);state=int(state)
        expected=int(exp,16);actual=int(actual,16);states[state]+=1;selectors[state].add(((rows[i][3]>>5)&1)*2+((rows[i][3]>>2)&1))
        records.append(dict(index=i,inputs=rows[i][:4],tag=rows[i][4],golden_state=state,expected=expected,actual=actual,passed=actual==expected))
    passed=r.returncode==0 and len(records)==CYCLES and all(x['passed'] for x in records)
    data=dict(version=VERSION,origin='RTL golden miter',golden_commit='364c52d1b72f4f0ec7db6360e24cceffe370c8cf',
        golden_adjustment='Encode the same default R=5 at 9 fractional bits; gain stays at 10 fractional bits.',
        cycles=len(records),passing=sum(x['passed'] for x in records),passed=passed,seed=SEED,
        state_coverage=dict(states),read_selectors_by_state={str(k):sorted(v) for k,v in selectors.items()},
        work_ownership_and_live_data_assertions=True,records=records)
    (out/'result.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
    if not passed:print(r.stdout[-3500:]+r.stderr);raise SystemExit(r.returncode or 1)
    assert set(states)==set(range(8))
    fixture=''.join(f"{x['expected']:06x}\n" for x in records)
    (out/'public_trace_expected.hex').write_text(fixture,encoding='ascii',newline='\n')
    target=repo/'test/public_trace_expected_q5_9.hex'
    if a.generate_fixture:
        assert not target.exists(),'Do not overwrite a golden fixture'
        target.write_text(fixture,encoding='ascii',newline='\n')
    if a.verify_fixture:assert target.read_text(encoding='ascii')==fixture
    print(json.dumps(dict(passed=True,cycles=CYCLES,all_states_covered=True,read_selectors_by_state=data['read_selectors_by_state'],fixture_sha256=hashlib.sha256(fixture.encode('ascii')).hexdigest())))
if __name__=='__main__':main()
