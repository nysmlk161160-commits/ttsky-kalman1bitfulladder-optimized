# v27 Q5.9 at 50 MHz with an aligned work bank and grouped carry

Compare against v26 at commit `9240e61833173031e8b770dc3b8e59b65a74caac`.
The original inputs to the shared adder have a phase select in front of
a 16-bit ripple chain. At the slow corner, the v26 critical path
starts at the multiplier-run flag and goes through selection, carry
and work-bank writeback logic.

Store the divider remainder in work[26:12] and the denominator in
{work[29:27], work[11:0]}. The product representation stays in work[25:0]
with a wire for the duplicated sign bit. In both phases adder A[14:1]
now comes straight from work[25:12]. A[15] selects the upper remainder
or product sign, and A[0] is qualified by the multiply phase.

Use four groups of four bits for carry generation in the one shared
16-bit adder. Preserve the Q5.9 I/O, gain scale, shared 30-bit work bank,
top-level update ALU and 39/29-cycle interface schedule. Keep v26's
50 MHz period and physical constraints. The goal is a lower mapped MUX
count and better worst setup while retaining clean hold and electrical
checks. Compare final area to measure the cost of grouped carry.

Use the same bounded numerical/protocol cases, cycle-trace comparison,
gate-level tests and tapeout precheck as v26.

Run 44877685726 closed at 50 MHz with 148 MUXes and +0.969 ns
worst setup slack. Its new critical path had seven fanout buffers with
9.291 ns of combined cell delay. The physical follow-up reparents three
cascaded noninverting data branches onto their original drivers in
parallel. The same RTL, clocks, electrical limits and acceptance checks
apply to both implementations.
