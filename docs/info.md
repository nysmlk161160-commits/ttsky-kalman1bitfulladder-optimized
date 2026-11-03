# Scalar Kalman filter with optional prediction and feedback

## How it works

The default mode performs a scalar measurement correction. Version7 adds an
opt-in random-walk prediction P_prior=min(P+Q,1023) and automatic X/P feedback.
Both use six fractional bits, exact declared truncation and the same fused
12-bit add/shift multiplier and restoring fractional divider.

Normal/shortcut core latency is 27/21 RTL clocks. Host transfers are excluded.
See [complete mathematical and interface specification](recursive_filter.md).

## How to test

Write Z/X/P/R through ui_in, using uio_in[1:0] as address, [2] as low/high
select and [3] as write-enable. Pulse [4] with write-enable clear to compute.
Read X_out/P_out by [5], using [2] to select low8/high2. uio_out[7] is sticky
ready and [6] is busy; direction mask is 0xc0.

For recursive mode, an IDLE write-enable+start cycle is configuration: address
0 writes Q low/high, address 1 low writes mode in ui_in[0]. Reset restores
legacy mode and Q=0. Busy writes are ignored. Configure first, then write only
Z and start each new sample. Extended writes never trigger computation.

## External hardware

A host providing the documented clock, reset, input transfers and output reads.
No sensor or external analogue interface is included.
