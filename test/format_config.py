# Numeric format constants; no algorithm or FSM changes.
W=11
F=6
SCALE=1<<F
MASK=(1<<W)-1
SIGN=1<<(W-1)
HIGH_MASK=(1<<(W-8))-1
HIGH_UNUSED=255^HIGH_MASK
NORMAL=3*F+9
SHORTCUT=2*F+9
VERSION='version14'
FORMAT='Q5.6'
