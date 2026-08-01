# SLURM Skills — Reference Key

**Instructor use only.** Students have **Claude** write two skills on the Day 3 "Writing a SLURM Job with Claude" page and then review the scripts Claude produces. There's no single right answer — these are reference models. The teaching point is the **scope split**: a *project* skill holds repo-specific facts (committed in `.claude/skills/`), a *global* skill holds Yen conventions that apply everywhere (in `~/.claude/skills/`).

## 1. Project skill — `.claude/skills/form3-slurm/SKILL.md` (repo-specific)

```markdown
---
name: form3-slurm
description: How to run this repo's Form 3 extraction batch jobs on the Yens — paths, venv, and scripts. Use when writing a .slurm file for this project.
---

# Running this project's batch jobs

SLURM starts a fresh shell, so the job must set itself up:
- `cd ~/gsb-research-computing-ai-skills`
- `source .venv/bin/activate`

The batch script is `scripts/extract_form_3_batch.py` — it reads `data/aws_links.csv`
and writes one JSON per filing into `results/`. `NUM_FILINGS` (near the top of the
script) controls how many filings it processes.

Job logs go in `logs/` (see the yen-slurm skill for the naming convention).
```

Note: **no** partition/email/resource conventions here — those belong in the global skill.

## 2. Global skill — `~/.claude/skills/yen-slurm/SKILL.md` (repo-agnostic)

```markdown
---
name: yen-slurm
description: Conventions for writing SLURM batch scripts on Stanford's Yen cluster — partitions, resource requests, logging, and email. Use whenever creating or editing a .slurm file for the Yens.
---

# SLURM conventions on the Yens

## Partitions
- `normal` — production runs (default).
- `dev` — short debugging jobs only (tighter time limit, faster turnaround).
- Check current limits/QoS before requesting:
  https://rcpedia.stanford.edu/_user_guide/slurm/#current-partitions-and-their-limits
  and `sacctmgr show qos <partition>`. Pick the partition that minimizes queue time.

## Always include
- Email: `--mail-type=ALL` and `--mail-user=<SUNetID>@stanford.edu`.
- Log naming: `--output=logs/<job-name>_%j.out` and `--error=logs/<job-name>_%j.err`
  (`%j` = job ID, so runs don't overwrite each other).

## Resources
- Set `--time` / `--mem` / `--cpus-per-task` from measured numbers (profiling), not guesses.
```

Note: **no** repo paths or script names here — that's what makes it reusable across projects.

## `mkdir -p logs` — pre-submit, not a script line
SLURM opens the `--output`/`--error` files when the job starts, *before* the script body
runs, so `logs/` must already exist. It's a one-time setup step (`mkdir -p logs`) run
before `sbatch` — **not** a line inside the `.slurm` script, and therefore not something to
compare between scripts. Compare the `--output`/`--error` *naming* instead.

## What to look for
- **Project skill** captures repo specifics (path, `.venv`, `scripts/extract_form_3_batch.py`,
  `results/`, `logs/`) and **nothing** general.
- **Global skill** captures Yen conventions (partitions/QoS, email, `%j` logs, resources-from-
  measurement) and **no** repo paths.
- Students used each to generate a `.slurm`, compared to the hand-written
  `slurm/extract_form_3_batch.slurm`, and ran both — noticing the project-skill script nails
  the setup but guesses conventions, and the global-skill script nails conventions but has to
  discover the repo paths.
