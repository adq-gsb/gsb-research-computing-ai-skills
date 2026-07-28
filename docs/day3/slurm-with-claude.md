---
layout: default
title: "Writing a Slurm Job with Claude"
parent: "Day 3 — Cluster Computing"
nav_order: 8
permalink: /day3/slurm-with-claude/
---

# Writing a Slurm Job with Claude

<div data-room-id="d3-slurm-with-claude"></div>

---

You wrote a Slurm script **by hand** — and two kinds of knowledge went into it:

- **How the Yens work** — partitions, resource requests, `%j` log naming, email notifications. This is true for *every* job you'll ever run on the cluster.
- **How this project runs** — where the repo lives, the `.venv`, which script to run, where results go. This is specific to *this* pipeline.

You can hand each kind of knowledge to Claude Code as a **skill** — a set of standing instructions Claude pulls in automatically — so it writes Slurm scripts that follow the cluster's conventions *and* your project's setup, without you re-explaining every time. You'll have **Claude write the skill**, then **review the script it produces** (you're always the one who submits and checks the job).

## Two homes for a skill

On Day 1 you *installed* a skill (`github-for-research`). A skill can live in one of two places, and the choice is about **scope**:

- **Project skill** — `<your-repo>/.claude/skills/<name>/SKILL.md`. Committed to the repo, shared with anyone who clones it, and loaded only when you're working in *this* project. Best for **repo-specific** facts (paths, the venv, which script to run).
- **Global skill** — `~/.claude/skills/<name>/SKILL.md`. Lives in your home directory and loads in *every* project you work on — that's where the Day 1 skill lives. Best for **conventions that follow you** across projects (like how the Yens work).

You'll make one of each.

## Main quest

### 1. A project skill — how *this* repo runs

Ask Claude Code (inside your repo) to write a **project** skill:

> Create a Claude Code skill at `.claude/skills/form3-slurm/SKILL.md` describing how to run **this project's** batch jobs on the Yens: the repo lives at `~/gsb-research-computing-ai-skills`; the virtual environment is `.venv` (Slurm starts a fresh shell, so the job has to `cd` into the repo and `source .venv/bin/activate`); the batch script is `scripts/extract_form_3_batch.py` (it reads `data/aws_links.csv` and writes one JSON per filing to `results/`); logs go in `logs/`. Keep it to *this* project's specifics — no general Yen/Slurm advice.

Then put it to work:

> Using the form3-slurm skill, write a Slurm batch script for the 10-filing run and save it as `slurm/extract_form_3_batch_claude_project.slurm`.

**Compare** it to your hand-written `slurm/extract_form_3_batch.slurm`, then **submit it and review**:

- The **repo setup** (`cd`, `source .venv/bin/activate`, `python scripts/extract_form_3_batch.py`) should be spot-on — that came from your skill.
- The **conventions** — partition, `--time`/`--mem`/`--cpus-per-task`, email, log naming — are whatever Claude *guessed*, because the project skill says nothing about them. Note what it got wrong; that's what the next skill is for.

### 2. A global skill — how the *Yens* work

These conventions aren't specific to this repo — they apply to every job you'll ever run on the Yens. So they belong in a **global** skill. Ask Claude to write one:

> Create a Claude Code skill at `~/.claude/skills/yen-slurm/SKILL.md` for writing Slurm jobs on Stanford's Yen cluster — general conventions for any project: choose a partition (`normal` for production runs, `dev` for short debug jobs) and check current limits and QoS on RCpedia (https://rcpedia.stanford.edu/_user_guide/slurm/#current-partitions-and-their-limits and `sacctmgr show qos <partition>`); always add email notifications (`--mail-type=ALL`, `--mail-user=SUNetID@stanford.edu`); name logs `logs/<job-name>_%j.out` and `logs/<job-name>_%j.err`; set `--time`, `--mem`, and `--cpus-per-task` from measured numbers, not guesses. Keep it repo-agnostic — no specific project paths or script names.

Then put it to work:

> Using the yen-slurm skill, write a Slurm batch script for the 10-filing run and save it as `slurm/extract_form_3_batch_claude_global.slurm`.

**Compare** and **submit and review** again:

- The **conventions** — email, `logs/…_%j` naming, a sensible partition — should now be right, straight from the skill.
- But the global skill knows nothing about *this* repo, so Claude has to **inspect the repo (or ask you)** to find the path, venv, and script. That gap is exactly why the **project** skill exists.

**Takeaway:** the project skill knows *where things live here*; the global skill knows *how the Yens work*. Keep both — together Claude has everything it needs, and you review the result.

{: .note }
> **Where does `mkdir -p logs` go?** Not in the Slurm script. Slurm opens the `--output`/`--error` files the moment the job starts — *before* your script's commands run — so `logs/` has to exist already. Create it once, before you submit (`mkdir -p logs`); the script only needs the `--output=logs/<name>_%j.out` / `.err` naming. (So it's not something to "compare" between scripts — check the naming, not a `mkdir` line.)

{: .warning }
> **You're still the reviewer.** A skill makes Claude follow your conventions, but Claude can still invent partition names, time limits, or QoS caps that don't exist. Check its choices against RCpedia — the [current partitions and their limits](https://rcpedia.stanford.edu/_user_guide/slurm/#current-partitions-and-their-limits) page and `sacctmgr show qos <partition>` — and against your own profiling. The script you submit is yours.

{: .note }
> 🟢 **Green sticky** = I'm done and ready &nbsp;&nbsp; 🔴 **Red sticky** = I need help
>
> Put a sticky note on your laptop lid so instructors can see where you are.

<label class="quest-check"><input type="checkbox" data-room="d3-slurm-with-claude" data-key="main"> I had Claude write a project skill and a global Yen skill, used each to generate a batch Slurm, compared them to my hand-written script and ran them, and can explain project vs. global scope</label>
