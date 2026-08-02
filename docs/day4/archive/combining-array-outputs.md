---
layout: default
title: "Combining Array Outputs (archived)"
parent: "Day 4 — Parallelization & GPUs"
nav_exclude: true
search_exclude: true
permalink: /day4/archive/combining-array-outputs/
---

# Combining Array Outputs (archived)

**Archived — not part of the course flow.** Cut from the exercise on
[Slurm Job Arrays](../slurm-arrays/) on 2026-08-01. Kept for the race-condition
explanation, which is the clearest statement of why each task writes its own file.

---

Each task writes its *own* file, one per filing, and that separation is deliberate. The tasks run at the same time, so if they all tried to append to one shared output file, their writes would interleave and overwrite each other — a **"race condition"** (a bug whose outcome depends on the unpredictable order in which simultaneous operations happen to run), leaving you with a garbled, unusable file. Giving each task its own file sidesteps that entirely. Once the array finishes, you stitch those per-task files into a single dataset (such as one CSV) as a quick post-processing step — the [Optional practice](../../slurm-arrays/#optional-practice-combine-the-results-into-one-csv) on the Slurm-arrays page walks through it.
