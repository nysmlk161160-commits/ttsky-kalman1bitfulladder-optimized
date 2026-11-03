# Version7: optional complete scalar recursion

Baseline: version6, `3269b76ca0bca967606157de934c40d5d1ffa813`.
Only add prediction/feedback and its protocol; arithmetic cores, top state
schedule, precision, clock and physical constraints remain the same.

## Mathematics and finite-range policy

For the random-walk scalar model A=H=1, with no control input:

```
X_prior = X_previous
P_prior = min(P_previous + Q, 1023)       # integer-code saturation
G       = floor(64*P_prior/(P_prior+R))  # 0 if denominator is 0
X_next  = X_prior + floor(G*(Z-X_prior)/64)
P_next  = P_prior - floor(G*P_prior/64)
```

X/Z are signed 10-bit codes with six fractional bits. P/Q/R are unsigned
10-bit codes with six fractional bits in their own variance units. G is an
unsigned seven-bit gain code with six fractional bits. Signed products round
toward minus infinity. Legacy output modulo behaviour is preserved. Valid
state updates lie between the prior and measurement, so fit the signed range.

P+Q saturates instead of wrapping to an accidentally confident small variance.
Saturation is a declared finite-range approximation, not an exact unbounded
Kalman covariance recursion. The ideal model is based on Welch and Bishop,
TR 95-041, equations 1.9-1.13:
https://www.cs.utexas.edu/~pstone/Courses/393Rfall15/readings/Welch%2BBishop-TR-95.pdf

## Interface and reset

All inputs/outputs retain the Tiny Tapeout pin allocation. A sample is still
externally triggered; this design does not include a sensor or sampling timer.

| Control | Meaning |
| --- | --- |
| write=1, start=0 | Legacy register write, address 0=Z, 1=X, 2=P, 3=R |
| write=0, start=1 | Accept one sample while IDLE |
| write=1, start=1, address=0 | Extended Q write; low8/high2 selected by upper |
| write=1, start=1, address=1, upper=0 | ui_in[0]: 1=recursive, 0=legacy |
| Other extended addresses | Reserved, ignored |

`write=uio_in[3]`, `start=uio_in[4]`, `upper=uio_in[2]`, address is [1:0].
Configure on separate clock edges before start. Busy writes and starts are
ignored. Asynchronous active-low reset aborts any update, clears Q and mode,
and restores legacy X/P/Z=0, R=320. Ready is sticky until the next sample.

For recursive use: reset; write initial X/P/R; configure Q and mode=1; then
write only the new Z and pulse start for each sample. R and Q can be changed
between samples. X/P are fed back after a completed correction. Disabling
recursive mode stops feedback and prediction; stored X/P can be reinitialised
using the legacy writes.

The normal/shortcut core schedule is 27/21 RTL clocks at 20 ns. This excludes
host transfers. Updating Z requires two word-part writes, versus six for
Z/X/P when feedback is performed by the host; R is assumed unchanged in both
cases. These are protocol transaction counts, not measured system throughput.

## Verification and evidence

- Original 65-vector Cocotb regression, and independent 1,065-vector legacy test.
- Exhaustive divider P/R domain: 1,048,576 cases. Multiplier gain 0..64 and
  signed operand -1024..1023: 133,120 cases. This is not a protocol formal proof.
- 591 recursive/protocol scenarios: 256 seeded noisy-signal samples, directed
  zero/extreme/saturation cases, random Q/R transitions and mode changes.
- Attempts to overwrite R, Q and mode while busy; sticky ready; reset abort;
  two repeated post-reset samples proving restoration of non-feedback mode.
- The same public-port feature scenarios run through Cocotb in RTL and GL.
- Raw waves, vectors, observed outputs, failure attempts, exact source and
  original cloud artifacts are kept in the parent `results/version7/`.

The synthetic workload uses seed 20261103, measurement sigma=0.5, R=0.25,
Q=1/64 and a bounded sinusoid with one step. Report its RMSE as a workload
result, not a universal filtering-accuracy guarantee. EDA power without
activity backannotation is an estimate. Inspect corners, DRC/LVS, slew,
fanout and capacitance individually before claiming physical sign-off.
