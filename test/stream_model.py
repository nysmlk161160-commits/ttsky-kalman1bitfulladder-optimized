"""Independent integer specification and seeded public-interface workloads."""
import math
import random

def correction(z,x,p,r):
    gain=64*p//(p+r) if p+r else 0
    return x+gain*(z-x)//64,p-gain*p//64

def scenarios():
    rows=[]
    sx=sp=0
    def add(z,q,r,reset=False,mode=1,x=0,p=64,truth=None,busy=0):
        nonlocal sx,sp
        load=reset or not mode
        if load:sx,sp=x,p
        prior=min(1023,sp+q) if mode else sp
        nx,np=correction(z,sx,prior,r)
        rows.append({'reset':int(reset),'mode':mode,'q':q,'z':z,'load':int(load),
                     'x':sx,'p':sp,'r':r,'expected_x':nx,'expected_p':np,
                     'cycles':21 if r==0 else 27,'busy':busy,
                     'saturated':bool(mode and sp+q>1023),'truth':truth})
        if mode:sx,sp=nx,np
    # A fixed noisy bounded signal; no claim that it covers every real workload.
    rng=random.Random(20261103)
    for i in range(256):
        truth=1.5*math.sin(i/25)+(0.75 if i>=128 else 0)
        z=max(-512,min(511,round((truth+rng.gauss(0,0.5))*64)))
        add(z,1,16,reset=i==0,truth=truth,busy=i%17==0)
    directed=[(511,1023,1023,-512,1023),(-512,1023,0,511,1023),
              (64,0,0,0,0),(0,0,1,511,0),(511,0,1023,-512,1),
              (-512,1,1023,511,1023)]
    for z,q,r,x,p in directed:
        add(z,q,r,reset=True,x=x,p=p,busy=1)
        add(-z if z!=-512 else 511,q,r)
    # Exercise extended low/high writes and changing Q/R between samples.
    rng=random.Random(771103)
    for group in range(10):
        x=rng.randrange(-512,512);p=rng.randrange(1024)
        for i in range(32):
            add(rng.randrange(-512,512),rng.choice([0,1,64,255,256,1023]),
                rng.choice([0,1,16,255,256,1023]),reset=i==0,x=x,p=p,busy=i%7==0)
    # Switch modes without reset: a legacy update must not feed itself back.
    add(96,7,64,reset=True,x=-64,p=64)
    add(-96,7,64,mode=0,x=32,p=128)
    add(64,7,64,mode=1)
    return rows
