# Independent coursework experiment clone

- This is an independent clone; do not modify sibling worktrees, their main,
  previous source snapshots or version1-5 evidence.
- Use only `exp/coursework-*` branches. Never merge to main without an explicit
  user request. Experimental CI must not publish Pages or replace existing docs.
- Review `docs/coursework_design_space.md` and `docs/recursive_filter.md` before
  further architecture changes. The coursework rubric values area/PPA,
  rigorous reasoning, verification, and clear reproducible communication.
- Save raw experiment evidence under `../results/versionN/`, outside Git.
  New architecture changes use the next unused version; reruns retain distinct
  Run IDs/attempts under the same version. Keep failure evidence before fixes.
- Before pushing, record change/reason/baseline/test strategy and unchanged
  implementation conditions. After pushing, preserve exact SHA, source ZIP,
  workflow Run IDs, original artifact/log ZIPs and SHA256 manifests.
- Keep final-stage PPA and PVT comparisons consistent. Do not call EDA power
  workload-measured, or claim sign-off from positive setup/hold alone.
- Legacy regression: `python -B test/run_digit_serial.py --output PATH`.
- Arithmetic regression: `python -B test/run_core_exhaustive.py --output PATH`.
- Recursive/protocol regression: `python -B test/run_recursive.py --output PATH`.
  Use an unused output directory in the appropriate version's raw/local folder.
