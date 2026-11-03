"""Run independent integer-reference interface tests with Icarus, without make.

Usage from the repository root:
    python test/run_digit_serial.py
To verify the original baseline using the exact same vectors and observer:
    python test/run_digit_serial.py --rtl ../kalman-baseline/src/project.v --baseline

Uses the original 15 directed + 50 random cases, followed by 1,000 extra
seeded random cases. Test output belongs in the already-ignored sim_build.
"""

import argparse
import json
import random
import shutil
import subprocess
from pathlib import Path


def vectors():
    cases = [
        (96, 0, 64, 320), (-96, 0, 64, 320),
        (0, 64, 64, 0), (32, -64, 32, 32),
        (511, -512, 1023, 0), (-512, 511, 1023, 0),
        (0, 0, 0, 1), (80, -80, 1, 1023),
        (127, -127, 1023, 1023), (-128, 127, 255, 255),
        (0, 0, 0, 0), (1, 0, 1, 0), (-1, 0, 1, 0),
        (511, 511, 0, 1023), (-512, -512, 0, 0),
    ]
    rng = random.Random(20261101)
    for _ in range(50):
        cases.append((rng.randrange(-512, 512), rng.randrange(-512, 512),
                      rng.randrange(1024), rng.randrange(1024)))
    rng = random.Random(20261102)
    for _ in range(1000):
        cases.append((rng.randrange(-512, 512), rng.randrange(-512, 512),
                      rng.randrange(1024), rng.randrange(1024)))
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rtl', type=Path)
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--output', type=Path,
                        help='Preserve raw local replay outside the source repository')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    rtl = (args.rtl or repo / 'src/project.v').resolve()
    iverilog = shutil.which('iverilog')
    if not iverilog:
        raise SystemExit('iverilog is not on PATH. Install Icarus Verilog first.')
    vvp = shutil.which('vvp') or str(Path(iverilog).with_name('vvp.exe'))
    label = 'baseline' if args.baseline else 'fused'
    out = (args.output or repo / 'test/sim_build/digit_serial' / label).resolve()
    out.mkdir(parents=True, exist_ok=True)
    cases = vectors()
    lines = []
    for z, x, p, r in cases:
        k = (p << 6) // (p + r) if p + r else 0
        expected_x = (x + ((k * (z - x)) >> 6)) & 1023
        expected_p = (p - ((k * p) >> 6)) & 1023
        lines.append(f'{z} {x} {p} {r} {expected_x} {expected_p}')
    (out / 'vectors.txt').write_text('\n'.join(lines) + '\n', encoding='ascii')
    normal, shortcut = (267, 189) if args.baseline else (27, 21)
    subprocess.run([iverilog, '-g2012', '-Wall', '-s', 'tb_digit_serial',
                    '-o', str(out / 'sim.vvp'), str(rtl),
                    str(repo / 'test/tb_digit_serial.v')], check=True)
    result = subprocess.run([vvp, 'sim.vvp', '+VECTORS=vectors.txt',
                             f'+NORMAL_CYCLES={normal}', f'+SHORTCUT_CYCLES={shortcut}'],
                            cwd=out, capture_output=True, text=True)
    log = result.stdout + result.stderr
    (out / 'simulation.log').write_text(log, encoding='utf-8')
    print(log, end='')
    if result.returncode or 'PASS:' not in result.stdout:
        raise SystemExit(result.returncode or 1)
    record = {'rtl': str(rtl), 'cases': len(cases), 'original_cases': 65,
              'additional_random_cases': 1000, 'clock_period_ns': 20,
              'normal_cycles': normal, 'shortcut_cycles': shortcut,
              'passed': True, 'simulator': iverilog,
              'observation': 'Start pulse end to ready, rising edge + 1 ns'}
    (out / 'result.json').write_text(json.dumps(record, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
