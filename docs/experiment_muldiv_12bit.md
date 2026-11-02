# Version5: single-digit 12-bit multiply/divide adders

Comparison parent: version4, commit `823f0956a81536022dd8c28b16ee7b600fdb3350`.
Branch: `exp/muldiv-12bit`. Both multiplier and divider change to 12-bit adders, as explicitly requested.

The experiment retains the multiplier's separate add and arithmetic-shift cycles and the divider's separate initialization and subtract cycles. It does not combine phases or introduce another resource-sharing optimization. The top-level controller, data formats, Gain scaling, 19-bit product, external interface and physical implementation config remain unchanged.

Completing the accumulator in one add removes the multiplier's cross-digit carry storage and replaces its three-stage digit index with a two-phase control bit. The divider no longer needs an eight-bit saved partial difference, cross-digit carry or digit selection. These removals follow directly from using a single full-width arithmetic digit.

Expected core cycles, to be verified:

| Component | version4 (8-bit) | version5 (12-bit) |
|---|---:|---:|
| Division | 6×(1+2) = 18 | 6×(1+1) = 12 |
| One multiplication | 7×(2+1) = 21 | 7×(1+1) = 14 |
| Complete normal update | 67 | 47 |
| Complete shortcut update | 49 | 35 |

The independent test retains all 1,065 input vectors and integer-reference outputs, changing only the expected architecture cycles to 47/35 and the output directory label. The original 65-case Cocotb test changes only its version label. Workflows change only the evidence labels and regression-output path, keeping the same actions and execution procedure.

Implementation settings are byte-identical to version4 `src/config.json`: a 1×1 tile, 20 ns target, placement density 75%, max-transition 1.5 ns and design-repair slew setting 30%. Project title/description identify version5, while pin mapping and clock metadata are preserved.

Local and cloud results, exact commit, Run IDs, raw test/code/physical artifacts, nine-corner STA, timing constraints and comparisons are archived in the parent `results/version5/` and `results/LOGBOOK.md`. Clock period, RTL/GL update latency, critical physical path delay and STA minimum period are separate measurements and must not be conflated. GL uses the inherited simplified UNIT_DELAY model, not post-layout SDF annotation.
