#!/usr/bin/env python3
"""Chain demo — step 2.

Read step 1's result from scratch and do more math with it. This job only runs
if step 1 succeeded (submitted with --dependency=afterok:<step1-jobid>).
"""
import os

SCRATCH = f"/scratch/users/{os.environ['USER']}/chain_demo"
IN = os.path.join(SCRATCH, "step1_result.txt")
OUT = os.path.join(SCRATCH, "step2_result.txt")

with open(IN) as f:
    step1 = float(f.read())

result = step1 * 2 + 42  # more math, built directly from step 1's output

with open(OUT, "w") as f:
    f.write(str(result))

print(f"step 2: read step1_result = {step1:.4f}")
print(f"step 2: computed {result:.4f}, wrote {OUT}")
