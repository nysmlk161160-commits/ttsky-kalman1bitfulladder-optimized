# v26 Q5.9 at 50 MHz with one arithmetic-core adder

The comparison baseline is v24, commit
`fd7af9ba18f480fe8939d284a8891e6609447fbe`. The internal divider and
multiplier use one 16-bit ripple-carry adder. The active phase selects
the operands and carry-in. Keep the existing shared work bank, gain
precision, feedback/writes, top-level update ALU and 39/29-cycle schedule.
The standalone arithmetic modules still serve the unit benches.

Keep the v24 20 ns constraint, SKY130A one-tile geometry, 75% placement
target, slew and fanout limits, and tool revisions. Detect clock and known
public input fanout by connectivity because the new RTL can change ABC
instance numbering and placement. Compare synthesis and post-route metrics
separately. Final area can include changes caused by physical repair.

Replay the 1,202 bounded numerical cases, 33 protocol scenarios,
4,096-cycle golden trace and standalone core checks. Run the final
timing/electrical acceptance, gate-level tests and tapeout precheck.
