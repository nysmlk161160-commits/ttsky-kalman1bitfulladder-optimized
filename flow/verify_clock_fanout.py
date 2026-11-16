"""Fail the completed build if clock topology or any final-corner fanout is wrong."""
from pathlib import Path
import json,re,sys

run=Path('runs/wokwi')
final=run/'final'
text=(final/'nl/tt_um_example.nl.v').read_text()
cells=[]
for m in re.finditer(r'^\s*(sky130_\w+)\s+(\\\S+|[\w.]+)\s*\((.*?)\);',text,re.M|re.S):
    cells.append((m[1],m[2],dict((p,n.strip()) for p,n in re.findall(r'\.(\w+)\s*\(([^)]+)\)',m[3]))))
root=next(c for c in cells if c[1]=='clkbuf_0_clk')
def inputs(net):return [name for typ,name,pins in cells if pins.get('A')==net]
assert sorted(inputs(root[2]['X']))==['clk_fanout_stage_0','clk_fanout_stage_1']
branches={name:inputs(pins['X']) for typ,name,pins in cells if name in ('clk_fanout_stage_0','clk_fanout_stage_1')}
assert len(branches)==2 and all(len(x)==8 for x in branches.values())
data_driver=next(c for c in cells if c[1]=='input4')
data_buffer=next(c for c in cells if c[1]=='input4_fanout_stage')
assert data_driver[2]['A']=='ui_in[2]'
assert data_buffer[0].startswith('sky130_fd_sc_hd__buf_')
assert data_buffer[2]['A']==data_driver[2]['X']
def data_loads(net):
    return [dict(cell=name,pin=p,master=typ) for typ,name,pins in cells
            for p,n in pins.items() if n==net and p not in ('X','Y','VPWR','VGND','VPB','VNB')]
data_branches={name:data_loads(pins['X']) for typ,name,pins in (data_driver,data_buffer)}
assert all(0<len(x)<=10 for x in data_branches.values()),data_branches
assert 'set_max_fanout 10.0000 [current_design]' in (final/'sdc/tt_um_example.sdc').read_text()
reports=sorted(run.glob('*-openroad-stapostpnr/*/checks.rpt'))
assert len(reports)==9, f'Expected nine final timing corners, got {len(reports)}'
records=[]
for p in reports:
    section=p.read_text().split('report_check_types -max_slew -max_cap -max_fanout -violators',1)[1].split('report_parasitic_annotation',1)[0]
    assert '(VIOLATED)' not in section, f'Electrical violation retained in {p}'
    records.append(dict(corner=p.parent.name,electrical_violations=0))
result=dict(passed=True,root_fanout=2,branch_fanouts=[len(branches[k]) for k in sorted(branches)],fanout_limit=10,input4_branch_fanouts={k:len(v) for k,v in data_branches.items()},input4_loads=data_branches,corners=records)
out=run/'fanout_acceptance.json';out.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
