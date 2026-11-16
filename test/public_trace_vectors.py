"""Fixed 4096-cycle public stimulus, including output reads throughout busy."""
import random
from format_config import W,F,MASK,SIGN,NORMAL
SEED=20261116
CYCLES=4096

def vectors():
    rng=random.Random(SEED);rows=[]
    def emit(rst=1,ena=1,ui=0,uio=0,tag='idle'):
        rows.append((rst,ena,ui,uio,tag))
    def selector(j):return ((j&1)<<2)|(((j>>1)&1)<<5)
    for _ in range(4):emit(rst=0,tag='initial reset')
    for _ in range(2):emit()
    panel=[((200,-100,0,1),0),((-SIGN,SIGN-1,MASK,0),255),((SIGN//2-1,-SIGN//2,MASK//2,SIGN),85)]
    for t in range(48):
        if t%8==0:
            for _ in range(3):emit(rst=0,tag='between-transaction reset')
            emit()
        if t<24:words,byte=panel[t%3]
        elif t==24:words,byte=(0,0,0,1),0
        else:
            words=(rng.randrange(-SIGN,SIGN),rng.randrange(-SIGN,SIGN),rng.randrange(MASK+1),0 if t%8==0 else rng.randrange(MASK+1))
            byte=rng.randrange(256)
        if t not in (28,29,30,31):
            for a,value in enumerate(words):
                for hi in (0,1):
                    emit(ui=((value&MASK)>>(8*hi))&255,uio=a|(hi<<2)|8,tag='partial-byte write')
                    emit(uio=selector(t+a+hi),tag='read during input preparation')
        else:
            for j in range(16):emit(uio=selector(t+j),tag='retain inputs before repeat start')
        if t<24:
            a=t//6;hi=(t//3)%2
            emit(ui=byte,uio=16|8|a|(hi<<2),tag='simultaneous write/start')
        elif t==24:emit(ui=0,uio=16|8|3,tag='old R/new R counterexample')
        else:emit(uio=16|selector(t),tag='repeat start' if t in (28,29,30,31) else 'ordinary start')
        abort=(2,F+4,2*F+5,3*F+5)[t%4] if t>=36 else None
        for j in range(NORMAL+9):
            ctl=selector(j+t)
            if j in (2,4) and t%3==0:ctl|=8|16|3
            rst=0 if abort is not None and abort<=j<abort+2 else 1
            emit(rst=rst,ui=255 if ctl&8 else 0,uio=ctl,
                tag='reset while processing' if not rst else 'busy/output/ready observation')
    while len(rows)<CYCLES:
        emit(rst=0 if rng.randrange(83)==0 else 1,ena=rng.randrange(2),ui=rng.randrange(256),uio=rng.randrange(48),tag='fixed random public history')
    assert len(rows)==CYCLES
    return rows
