# v29 all grouped-carry arithmetic at 50 MHz

Compare directly with v28, commit
`44642cc96693eb0e2c7926e5aac3858b2dbf6377`. The arithmetic operators
in the design source use one parameterized grouped-carry implementation.
It produces the boundary carry from group generate and propagate terms,
and the intermediate bit carries from their group input.

The divider/multiplier still share one arithmetic unit. The update ALU
still handles X and P on successive schedule phases. The existing
denominator and residual computations retain dedicated adders. Counter
increments use one four-bit group apiece, with fixed addend and carry-in.
The unit-test divider and multiplier also use the grouped adder. The
independent golden RTL and expected values remain as the oracle.

Keep all interfaces, fixed-point scales, register packing, schedules,
20 ns SDC configuration and physical flow files identical to v28.
Run the bounded numerical, protocol and trace regressions, gate-level
simulation, nine-corner checks and Tiny Tapeout precheck. Compare
measured area, timing, cycle count and typical-corner power estimate.
