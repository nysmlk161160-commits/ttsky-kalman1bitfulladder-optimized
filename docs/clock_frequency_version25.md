# v25 Q5.9 at 60 MHz

Compare with v24 Q5.9 at 50 MHz, commit
`fd7af9ba18f480fe8939d284a8891e6609447fbe`. The v24 slow-corner
post-route STA estimate is 62.99 MHz. This experiment validates a
60 MHz constraint against a separate physical implementation.

The new period is 16.666666667 ns. Simulations use a 16.666 ns period
at 1 ps resolution. The circuit RTL and golden vectors are identical
to v24. The same 1×1 SKY130A geometry, 75% placement target, 1.5 ns
slew constraint, limit of ten on fanout and existing repair are used.
The final SDC is checked for the requested clock. I/O timing budgets
defined relative to the clock are expected to scale with the period.

The expected core latency is 39/29 cycles, or about 0.650/0.483 µs
at the new target. Run the bounded 1,202-case numerical suite, 33
protocol scenarios, 4,096-cycle golden trace and bounded arithmetic
core tests. Confirm physical acceptance, gate simulation and precheck.

The first physical run produced GDS and closed setup/hold, but a routed
antenna diode raised the byte-select input buffer from ten to eleven
loads. The repair buffers the six readback mux select pins on one branch
and keeps the four write/control loads on the root. The fanout limit,
antenna repair, 60 MHz constraint and synthesizable RTL are identical.
