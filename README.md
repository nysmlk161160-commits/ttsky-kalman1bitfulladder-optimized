# Scalar Kalman ASIC: independent coursework experiments

This clone contains version6 fused arithmetic and version7 optional recursive
filtering on dedicated `exp/coursework-*` branches. Existing baseline and
version1-5 working directories are not modified.

The target is one SKY130 Tiny Tapeout tile, 20 ns clock and 75% target density.
Version7 keeps default legacy correction behaviour and adds configurable
process noise Q, covariance prediction with explicit saturation, and state
feedback for the scalar random-walk model. Each sample remains externally
triggered. This is a fixed-point approximation, not a sensor or fabricated-chip
measurement.

- [Coursework rubric and optimisation rationale](docs/coursework_design_space.md)
- [Version7 equations, interface, rounding and verification](docs/recursive_filter.md)
- [Tiny Tapeout project information](docs/info.md)

## Reproduce RTL checks

Install Icarus Verilog. From this repository root, choose new output folders:

```sh
python -B test/run_digit_serial.py --output ../results/version7/raw/local/legacy_NEW
python -B test/run_core_exhaustive.py --output ../results/version7/raw/local/cores_NEW
python -B test/run_recursive.py --output ../results/version7/raw/local/stream_NEW
```

CI additionally runs Cocotb RTL and gate-level public-interface tests, builds
GDS and runs precheck. Pages/docs deployment is disabled for these branches.
Original logs, artifacts, exact source snapshots, measured PPA and SHA256
manifests are archived outside Git in the workspace `results/versionN/`.

Passing arithmetic simulation is not full physical sign-off. Use exact-SHA
workflow reports to assess corners, DRC/LVS, slew, fanout and capacitance.
Unannotated EDA power is an estimate. Silicon correctness is not claimed.
