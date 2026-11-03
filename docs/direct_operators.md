# Version8: direct-operator scalar measurement update

Comparison baseline: version6, commit `3269b76ca0bca967606157de934c40d5d1ffa813`.
This branch intentionally replaces hand-scheduled iterative arithmetic with
Verilog `/` and `*`, allowing the synthesis flow to map the combinational logic.

## Preserved mathematics

```
S = P + R
D = signed(Z) - signed(X)
Kcode = floor(64*P/S) if S != 0 else 0
Xout = (X + floor(Kcode*D/64)) modulo 1024
Pout = (P - floor(Kcode*P/64)) modulo 1024
```

P/R: unsigned10; X/Z: signed10; S: unsigned11; D: signed11;
gain code: unsigned7. Numerator is explicitly widened to16 bits before division.
Each signed multiplication uses a nonnegative signed8 gain operand and a
signed11 multiplicand, producing a signed19 combinational product. Arithmetic
right shift by6 retains floor rounding for negative results. This 19-bit wire
is not the previous 19-bit iterative working register.

## Architecture and constraints

One combinational gain divider and two concurrent multiply descriptions.
No hand-scheduled sharing, iterative cores, gain register or pipeline cuts.
The input registers feed one combinational chain into the output registers.
A busy bit makes the accepted-start edge and output-capture edge distinct.
Architectural ready latency after accepted start:1 cycle, including former
shortcut inputs. Actual RTL and GL observer cycles must be measured separately.
Normal writes/starts, read mux, reset R=320, sticky ready and busy rejection
are preserved for the defined protocol: configure operands on separate edges
before asserting start. Simultaneous idle write/start is outside that protocol.

Unchanged src/config.json, pin interface, info.yaml, 20ns clock, 1x1 SKY130 tile,
75% density, 1.5ns max transition and30% slew repair margin. Do not relax the
clock, enlarge tile or add pipeline stages to make the experiment pass.

## Verification

Original65 directed/seeded vectors run in RTL and GL. Same independent1065
interface vectors (only expected schedule changes). Exhaust all1048576 valid
P/R pairs and all133120 gain/signed-operand pairs against integer models.
Additional public-port protocol checks cover reset abort, sticky ready,
busy write/start rejection and default R restoration.
Keep all failed workflow evidence. Functional GL uses UNIT_DELAY, not SDF.
Power is an EDA estimate without established workload activity backannotation.

## Hypotheses

Removing iterative state can reduce FF/control overhead; combinational
operators may increase area, path delay and power. Neither tile fit nor20ns
closure is assumed. Measure final physical results at the same stage/corners
as V6 and report missing metrics honestly if the original flow stops early.
