"""Verify the implemented clock and all post-route timing/electrical corners."""
from pathlib import Path
import json
import re

run = Path('runs/wokwi')
final = run / 'final'
text = (final / 'nl/tt_um_example.nl.v').read_text()
cells = {}
for match in re.finditer(r'^\s*(sky130_\w+)\s+(\\\S+|[\w.]+)\s*\((.*?)\);', text, re.M | re.S):
    pins = {p: n.strip() for p, n in re.findall(r'\.(\w+)\s*\(([^)]+)\)', match[3])}
    cells[match[2]] = (match[1], pins)


def input_loads(net):
    return [
        (name, pin) for name, (_, pins) in cells.items() for pin, wire in pins.items()
        if wire == net and pin not in ('X', 'Y', 'Q', 'Q_N', 'VPWR', 'VGND', 'VPB', 'VNB')
    ]


limit = 10
root = cells['clkbuf_0_clk'][1]
assert root['A'] == 'clk'
root_loads = input_loads(root['X'])
assert 0 < len(root_loads) <= limit, root_loads
branches = [name for name in sorted(cells) if name.startswith('clk_fanout_stage_')]
for name in branches:
    assert (name, 'A') in root_loads, name
branch_fanouts = [len(input_loads(cells[name][1]['X'])) for name in branches]
assert all(0 < n <= limit for n in branch_fanouts), branch_fanouts


def data_fanouts(port, branch):
    if branch not in cells:
        return {}
    master, pins = cells[branch]
    assert master.startswith('sky130_fd_sc_hd__buf_'), branch
    driver = next(name for name, (_, p) in cells.items()
                  if p.get('X') == pins['A'] and p.get('A') == port)
    fanouts = {name: len(input_loads(cells[name][1]['X'])) for name in (driver, branch)}
    assert all(0 < n <= limit for n in fanouts.values()), fanouts
    return fanouts


sdc = (final / 'sdc/tt_um_example.sdc').read_text()
period = float(re.search(r'create_clock[^\n]*-period\s+([\d.]+)', sdc)[1])
expected_period = json.loads(Path('src/config.json').read_text())['CLOCK_PERIOD']
assert abs(period - expected_period) < 0.0001, (period, expected_period)
assert 'set_max_fanout 10.0000 [current_design]' in sdc
metrics = json.loads((final / 'metrics.json').read_text())
reports = sorted(run.glob('*-openroad-stapostpnr/*/checks.rpt'))
assert len(reports) == 9, len(reports)
checks = ('timing__setup_vio__count', 'timing__hold_vio__count',
          'design__max_slew_violation__count', 'design__max_cap_violation__count',
          'design__max_fanout_violation__count')
corners = []
for report in reports:
    corner = report.parent.name
    row = {key: metrics[key + '__corner:' + corner] for key in checks}
    assert all(value == 0 for value in row.values()), (corner, row)
    electrical = report.read_text().split(
        'report_check_types -max_slew -max_cap -max_fanout -violators', 1
    )[1].split('report_parasitic_annotation', 1)[0]
    assert '(VIOLATED)' not in electrical, report
    corners.append(dict(corner=corner, **row))

ui_data_fanouts = {
    f'ui_in[{bit}]': data_fanouts(f'ui_in[{bit}]', f'input{bit + 2}_fanout_stage')
    for bit in range(6)
}
assert all(ui_data_fanouts.values()), ui_data_fanouts

result = dict(
    passed=True, root_fanout=len(root_loads), branch_fanouts=branch_fanouts,
    fanout_limit=limit, final_sdc_period_ns=period,
    input4_branch_fanouts=ui_data_fanouts['ui_in[2]'],
    input7_branch_fanouts=ui_data_fanouts['ui_in[5]'],
    ui_data_branch_fanouts=ui_data_fanouts,
    input12_branch_fanouts=data_fanouts('uio_in[2]', 'input12_fanout_stage'),
    corners=corners,
)
(run / 'fanout_acceptance.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
