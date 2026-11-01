# Kalman correction accelerator (optimized serial arithmetic)

This project implements a Q4.6 Kalman correction with two one-bit serial arithmetic units.

- `K = floor(64 * P / (P + R))`, with K=0 for P+R=0
- `X_new = (X + floor(K*(Z-X)/64)) mod 1024`
- `P_new = (P - floor(K*P/64)) mod 1024`

Z and X are signed 10-bit two's-complement values. P and R are unsigned 10-bit values.

## Interface

- `ui_in[7:0]`: input data
- `uio_in[1:0]`: destination 0=Z, 1=X, 2=P, 3=R
- `uio_in[2]`: low 8 bits or high 2 bits of the written value; on read, selects low or high part
- `uio_in[3]`: write-enable (when idle)
- `uio_in[4]`: start computation
- `uio_in[5]`: output selection (0=X, 1=P)
- `uo_out[7:0]`: selected result byte (high part in [1:0])
- `uio_out[7]`: ready; `uio_out[6]`: busy

## Optimization

Compared with the original 1-bit architecture: removed duplicated multiplier result register, removed the live operand copy in the multiplier (top maintains stable inputs), wired divider output directly to multiplier instead of a duplicated gain register, shared one 10-bit add/subtract datapath in the top module, and removed duplicated divider result storage by adding a single equality-case bit.

This is an RTL candidate for a **1x1 tile / 20 ns target**. Physical PPA and silicon correctness are **not yet verified**: run RTL test, gate-level test and GDS/precheck before making claims.
