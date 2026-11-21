# version30 physical attempt 3: Q6.9 electrical repair

Keep Q6.9, 50 MHz, fanout 10, 1.5 ns transition, 75% placement target,
the original tile, gain precision, RTL and test sampling conventions.

The first routed attempt had three primary-input fanout violations caused by
antenna diode loads, and eleven slew plus one capacitance violation on _0248_.
Add one buf_4 branch on each of ui_in[0], ui_in[3] and ui_in[4], splitting eight
logical sinks into root5/branch4. Find _0248_'s driver by connectivity, assert
the expected ten-sink a21oi_2 mapping, and resize it to a21oi_4. The unchanged
parent step reconnects power, legalizes, and runs normal downstream repair.
Extend final acceptance with branch fanout and internal driver records; retain
every existing timing/electrical check. Run original RTL/GL, nine corners,
DRC/LVS and precheck. Compare both the first v30 and accepted v28 at like stages.

Attempt 2 removed all original electrical violations, but changed routing added
three antenna diodes to ui_in[5], raising its eight logical loads to eleven.
Attempt 3 extends the same root5/branch4 split to ui_in[1], ui_in[5] and ui_in[6].
Together with the existing ui_in[2] branch, all seven eight-load data inputs
have antenna headroom. ui_in[7] has only four logical loads. Preserve attempt 2
at commit 044c9c26e2f2f71707b2c254d47060f94401ed2a as failed evidence.

Keep first failed source, raw archives, full reports and metrics as immutable
evidence under the same version, retaining exact SHAs and Run IDs/attempts.
