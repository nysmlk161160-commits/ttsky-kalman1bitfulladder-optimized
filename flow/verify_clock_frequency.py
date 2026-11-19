"""Verify the final implementation clock and all nine setup/hold corners."""
from pathlib import Path
import json,re
run=Path('runs/wokwi');final=run/'final'
cfg=json.loads(Path('src/config.json').read_text());target=cfg['CLOCK_PERIOD']
sdc=(final/'sdc/tt_um_example.sdc').read_text()
period=float(re.search(r'create_clock[^\n]*-period\s+([\d.]+)',sdc)[1])
assert abs(period-target)<0.0001,(period,target)
metrics=json.loads((final/'metrics.json').read_text())
corners=sorted(p.parent.name for p in run.glob('*-openroad-stapostpnr/*/checks.rpt'))
assert len(corners)==9
records=[]
for c in corners:
    record={'corner':c}
    for key in ['timing__setup_vio__count','timing__hold_vio__count','design__max_slew_violation__count','design__max_cap_violation__count','design__max_fanout_violation__count']:
        value=metrics[key+'__corner:'+c];assert value==0,(c,key,value);record[key]=value
    records.append(record)
out={'passed':True,'requested_period_ns':target,'final_sdc_period_ns':period,'corners':records}
(run/'clock_frequency_acceptance.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
