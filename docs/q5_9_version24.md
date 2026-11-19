# v24 Q5.9 at 50 MHz

The 14-bit input and output words for measurement and state use signed
two's complement with nine fractional bits. The range is −16 to
15.998046875 and the step is 0.001953125 in the host's chosen units.
The chip uses the same two-byte register transactions as v22.

P and R are unsigned 14-bit codes and must use a common covariance
scale. The default scale is 512 codes per covariance unit, with R reset
to 2560 for R = 5. To use another scale, the host writes both P and R
and interprets the output covariance in that scale.

The gain retains ten fractional bits and represents unity as 1024.
The shared work bank and digit-serial datapath retain the v22 widths
and schedules. Expected RTL correction latency is 39 cycles for the
normal path and 29 cycles for either divider shortcut, excluding host I/O.

The comparison baseline is v22 at 50 MHz. The target is to double the
state range while retaining the existing area and latency class. Use
the same SKY130A one-tile geometry, 20 ns period, 75% placement target,
1.5 ns slew constraint and fanout limit of ten. Run bounded numerical
and protocol regressions, a 4096-cycle golden comparison, synthesis,
physical implementation, gate simulation and precheck.
