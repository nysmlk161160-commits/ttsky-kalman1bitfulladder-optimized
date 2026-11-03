# Coursework autonomous design space

The source PDF is `5B2_IDE-26_coursework.pdf` in the parent workspace. It asks
for efficient use of one approximately 160 x 100 um SKY130 tile, primarily
area optimisation, appropriate performance trade-offs, repeated RTL-to-GDS
experiments, a logbook, DRC/LVS and convincing functional verification.

The rubric weights are Knowledge 25%, Technicality 25%, Communication 20%,
Achievement 30%. More features alone are not a grading requirement.

## Isolation

This directory is an independent Git clone, with copied objects and no
alternates or shared worktree metadata. Only `exp/coursework-*` branches are
published. Existing main, version1-5 worktrees and their raw records stay
unchanged. The experimental workflows disable Pages/docs publication while
retaining RTL, GDS, precheck and gate-level checks. Large evidence stays in
`../results/versionN/`; only source, tests and concise documentation go to Git.

## Experiments and decision gates

1. **Version6, cycle fusion, baseline version5.** Compute the next divider
   trial combinationally, and combine a multiplier conditional add and shift
   at the register input. Retain arithmetic precision, rounding, interface,
   top FSM and all implementation constraints. Predicted normal latency is
   6 + 2*7 + 7 = 27 clocks, versus 47; shortcut latency is 21 versus 35.
   Remove 12 trial flip-flops and two phase bits. The shifts are fixed wiring;
   the potential costs are changed register endpoints, routing and timing.
2. **Optional recursive filtering, only as a separate next version.** Add
   explicit process-noise prediction and state feedback if measured tile
   headroom is adequate. Specify overflow, initialisation, mode control and
   backward compatibility first. Verify time-series error and protocol
   behaviour; compare area/latency against version6, not against an unrelated
   arithmetic implementation.
3. **Further area/power options.** Consider one shared adder, register width
   reduction and operand isolation only after inspecting synthesis and final
   reports. Sharing can increase MUX, fanout and route cost; reducing RTL
   operators is not proof of smaller physical area. Do not change precision
   or physical constraints silently. Keep failed attempts and exact sources.

## Evidence tied to the rubric

| Category | Evidence |
| --- | --- |
| Knowledge | Bit-width and signed arithmetic reasoning; timing/area trade-offs |
| Technicality | Reproducible Icarus tests, arithmetic exhaustiveness, CI, RTL/GL |
| Communication | Requirements map, version comparison, labelled case records |
| Achievement | One-tile fit, final cell area, cycles, corners, DRC/LVS/electrical checks |

## References and limits

- Yosys official resource-sharing documentation explains the trade between
  merged operators and input multiplexing:
  https://yosyshq.readthedocs.io/projects/yosys/en/0.45/cmd/opt_share.html
- LibreLane official reporting guide distinguishes setup/hold, max slew,
  fanout, capacitance, unconstrained paths and antenna checks:
  https://librelane.readthedocs.io/en/stable/getting_started/newcomers/index.html
- Tiny Tapeout official FAQ describes the fixed tile and available I/O:
  https://www.tinytapeout.com/faq/

Cycle-fusion predictions above are derived from this RTL, not promised by
these sources. Actual PPA must come from exact-head physical runs at the same
stage, clock, density and PVT corner. Unannotated EDA power is an estimate.
Positive setup/hold slack or green CI alone is not full sign-off.
