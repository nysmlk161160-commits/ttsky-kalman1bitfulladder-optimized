# Version4: 8-bit digit-serial multiplier and divider experiment

## Baseline and worktree

- Remote: https://github.com/nysmlk161160-commits/ttsky-kalman1bitfulladder-optimized.git
- Baseline commit: `32a97e39372584ac3512bd1a57f04678a1b1f099`
- Baseline checkout: `../kalman-baseline`, branch `main`, clean.
- Experiment checkout: this directory, branch `exp/muldiv-8bit`.
- The experiment is a standard Git worktree sharing the baseline repository's history and remote.
- This is version4. Version1 is the 1-bit baseline, version2 shares the top-level ALU, and version3 uses 4-bit cores. Version4 branches from version1.
- Publication status, commit SHA, workflow Run IDs and raw artifacts are recorded in the parent workspace's `results/version4/` and `results/LOGBOOK.md`.

## What 8-bit means

The arithmetic digit width changes from one bit to eight bits per addition cycle. External data widths and fixed-point precision stay the same: signed 10-bit state encoding, unsigned 10-bit P/R, signed 11-bit delta, unsigned 11-bit S, 7-bit gain with six fractional bits, and the original 19-bit product register.

Each core has its own 8-bit ripple-carry adder. The divider and multiplier are separate cores. The top-level controller continues sharing the multiplier between the X and P updates.

The internal accumulator is 12 bits. It therefore needs a low 8-bit digit and a high 4-bit digit, rather than a naive fixed 8-bit rotation. The high division digit zero-pads both operands before two's-complement subtraction, so the full adder carry correctly represents the valid high-nibble no-borrow flag. The multiplier sign-extends b into the original 12-bit arithmetic width and discards the high carry as before.

## Cycle accounting

| Normal-path component | 1-bit baseline | 8-bit experiment |
|---|---:|---:|
| Division | 6 × (1 + 12) = 78 | 6 × (1 + 2) = 18 |
| One multiplication | 7 × (12 + 1) = 91 | 7 × (2 + 1) = 21 |
| Top-level overhead | 7 | 7 |
| Complete update | 267 | 67 |
| Division-shortcut complete update | 189 | 49 |

At a simulated clock period of 20 ns, ordinary update times are 5.34 µs and 1.34 µs. These are RTL observations, excluding input loading and output readout. No post-layout frequency, area, power, gate-level or sign-off claim follows from these simulations.

## Local verification

Icarus Verilog 12.0 on the local computer ran the same 1,065 input vectors on both implementations. Both passed all integer-reference output assertions, interface-direction checks, timeout checks and exact start-to-ready cycle assertions.

- Original 15 directed and 50 random cases use seed `20261101`.
- Additional 1,000 random cases use seed `20261102`.
- Total distribution: 1,057 ordinary cases and 8 shortcut cases.
- Ordinary observed cycles: baseline 267, experiment 67.
- Shortcut observed cycles: baseline 189, experiment 49.
- Observer: rising clock edge plus 1 ns, counting after the Start pulse ends.
- The original Cocotb test vectors, reference model and assertions are preserved. Version4 additionally writes input/output/cycle records to `test/output/kalman_cases.json` for artifact collection. The test workflow also runs the 1,065-case regression and uploads its vectors, executable and result logs.
- Cocotb execution was not run locally because the local Python environments do not have Cocotb installed. The new independent Verilog observer and Python reference runner provide the local verification reported here. Cloud Cocotb and gate-level results must be read from the corresponding workflow runs.

From this checkout, run:

```powershell
python test/run_digit_serial.py --rtl ../kalman-baseline/src/project.v --baseline
python test/run_digit_serial.py
```

Icarus and vvp must be on PATH. Outputs and logs go into the already-ignored `test/sim_build/digit_serial/` directory. In the current Codex sandbox, the installed Icarus compiler exits abnormally, including on untouched baseline RTL. Running the same compiler with approved execution outside the sandbox succeeds. The reported results use that successful execution.

## Preserved comparison conditions

The top-level module is byte-equivalent in behavior after substituting the divider/multiplier module names. `src/config.json`, physical I/O and `test/tb.v` remain unchanged. `info.yaml` updates only the project title and description. Cocotb changes add result recording, the RTL workflow adds the independent regression and raw-output upload, and the GL job uploads its case records after the unchanged Tiny Tapeout GL action. The GDS build action and implementation settings remain unchanged. The implementation target remains a 1×1 tile with CLOCK_PERIOD=20 ns and PL_TARGET_DENSITY_PCT=75.

## Workspace organization

The user keeps `integrated circuit` as the Codex primary directory so code and all results remain accessible. Run Git commands explicitly in `kalman-muldiv-8bit`, on branch `exp/muldiv-8bit`. Store experiment evidence in the parent `results/version4/`. Do not add raw GDS logs or large waveforms to this source repository.

This is an existing worktree, so creating another one is unnecessary. A future worktree created from `kalman-baseline/main` starts from the 1-bit baseline unless another starting revision is explicitly selected.

Push version4 to the experiment branch in the same GitHub repository. Keep `main` as the baseline. Record Commit and Run IDs for the RTL/Cocotb and GDS/GL workflows, and compare results using the same stage, corner and constraint definitions.

Official UI references:

- https://learn.chatgpt.com/docs/projects
- https://learn.chatgpt.com/docs/environments/git-worktrees
