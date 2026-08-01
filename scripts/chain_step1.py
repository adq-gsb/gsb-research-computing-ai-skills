#!/usr/bin/env python3
"""Chain demo — step 1.

Crunch numbers for ~2 minutes, then write the result to the user's scratch
space so step 2 (a separate, dependent Slurm job) can pick it up.
"""
import math
import os
import time

SCRATCH = f"/scratch/users/{os.environ['USER']}/chain_demo"
os.makedirs(SCRATCH, exist_ok=True)
OUT = os.path.join(SCRATCH, "step1_result.txt")

DURATION = 120  # seconds of real work, so step 2 has to wait its turn

print(f"step 1: crunching numbers for ~{DURATION}s ...", flush=True)
start = time.time()
total = 0.0
n = 0
while time.time() - start < DURATION:
    total += math.sqrt((n % 1000) + 1)
    n += 1

with open(OUT, "w") as f:
    f.write(str(total))

print(f"step 1: did {n:,} operations, result = {total:.4f}")
print(f"step 1: wrote {OUT}")
