# Repo TODOs

Cross-cutting items that span more than one day. Day-4-specific content gaps live in
`docs/day4/TODO.md`; this file is for things that touch several days or the site
machinery. Not part of the Jekyll build (it sits outside `docs/`).

Last updated 2026-08-01.

---

## Naming & consistency

### Standardise "SLURM" → "Slurm" on Days 1, 2, and 4
Main standardised the casing in `778fd2f` and converted Day 3 completely, but the
sweep never reached the other days. Current prose counts (excluding `SLURM_*`
environment variables, which stay upper-case):

| Day | `Slurm` | `SLURM` |
|-----|---------|---------|
| 1   | 0       | 7       |
| 2   | 0       | 1       |
| 3   | 65      | 0       |
| 4   | 0       | 51      |

Day 4 is the bulk of it, including the page title "SLURM Job Arrays" and the `<desc>`
alt-text inside the animated SVGs. Leave `SLURM_ARRAY_TASK_ID` and other env vars
alone.

### Day 4 capstone breaks the Days 1–3 convention
`docs/day4/putting-it-all-together.md` is `nav_order: 7` with `staying-in-touch.md` at
8, so the graded page isn't the day's last nav item — Days 1–3 all put the capstone
last. The nav title also doesn't say "Capstone" (Day 1: "Day 1 Challenge", Day 3:
"Day 3 Capstone"). The room id (`d4-capstone`) and key (`commit`) *do* follow Day 3.

---

## Content gaps

### Comprehension questions at the end of "When Parallelization Helps"
Add a question section closing that part of `docs/day4/parallelization.md`, giving the
audience concrete workloads to classify as parallelizable or not. The section teaches
the independent-vs-sequential distinction via the grilled-cheese figures but never
makes students apply it, and Day 4 has no `{: .important }` / `> **Task:**` device on
any concept page (Days 1–3 open every section with one).

Use Day 3's existing device — a stack of collapsed answers:
`<details markdown="1"><summary>❓ Question 1</summary>` … (see
`docs/day3/profiling.md:66` and `docs/day3/compute-environments.md:179`).

Candidate examples, mixing both answers and at least one that splits along a
non-obvious axis:

- Extract fields from 500 SEC filings, one API call each — **yes**, the day's own job
- Compute a running cumulative total over a time series — **no**, each step needs the previous
- Run the same regression on 50 country subsamples — **yes**
- Bootstrap 10,000 resamples — **yes**
- Download 200 files — **yes**, and I/O-bound rather than CPU-bound, so threads not cores
- Train one model by gradient descent over epochs — **no**, epochs are sequential
- Run an MCMC sampler — **not within a chain, yes across chains**; the nuance mirrors
  "steps within a sandwich" vs "sandwiches are independent"

### Surface the parallelization demo to students
`.instructor/parallelization_demos/` ships a README plus four `.slurm` scripts whose
own README says they map "1:1 to the diagrams in the Day 4 'Ways to Parallelize'
section" — but that section in `docs/day4/parallelization.md` has no student-facing
hook, so a runnable instructor demo is invisible to the class.

The site's one complete demo convention is Day 3's Compute Environments page, a
four-layer stack worth copying:

1. Index-table format label — `docs/day3/index.md:56`: `🥪💬 Demo + discussion`
2. `## Main quest — Class Participation` heading (participation noun, not an imperative)
3. `{: .important }` + `> **Task:** Take part in the class demo and discussion — …`
4. `<details><summary>❓ After the demo — discuss these</summary>` + a participation
   checkbox ("I participated in the class demo and discussion")

Day 4 also invented format tokens Days 1–3 don't use (standalone `🖊️ Concept`,
`🏛️ Community`), dropping the `💬` that carried the demo/discussion signal.

### Thread vs. process pool caveat on the parallelization page
`docs/day4/parallelization.md` implies cores are the lever for speeding up the
extraction loop, but Day 3 measured the job as I/O-bound: `docs/day3/profiling.md:308`
records `real 0m22.5s` against `user 0m1.9s` — roughly 20s spent waiting on the API.
So `--cpus-per-task=8` with a *process* pool buys almost nothing, while a *thread*
pool on one core helps a lot. Worth a short caveat so students don't request cores
that sit idle.

### Parallel-write pitfalls exercise
Students are taught to parallelize a loop but never what breaks when workers write to
shared state (interleaved output, lost writes, a shared counter that undercounts).
Deliberately left out of the "Ask Claude Code for help" callout rather than mentioned
in passing. `extract_form_3_batch.py` dodges the problem by writing one JSON per
filing — a good starting point for an exercise that has students break it, observe
the corruption, then fix it.

### Day 2's end-of-day sync ritual is dead
`docs/day2/boss-gate-2.md:105-115` still tells students to click a
**"📤 Sync to leaderboard"** button and upload `quest_log.json` through the GitHub web
UI. That button exists nowhere in the repo — it's the only match for the string. Day 4
was converted to the `./cast` ritual on 2026-08-01; Day 2 still needs the same
treatment.

### Instructor TODO shipped to students
`docs/day4/index.md:13` renders a bold red `TODO:` paragraph on the published Day 4
landing page. Days 1–3 index pages have nothing like it.

---

## Housekeeping

- `docs/day4/proposed_agenda.md` has dead links pointing at deleted archive files.
  It's `nav_exclude`/`search_exclude` but still reachable. Fix or delete.
- `node` isn't installed on the current dev machine, so
  `.instructor/gen_quest_keys.js` can't be run directly; `docs/_data/quest_keys.json`
  was last regenerated by a Python port of it. Re-run the real script when node is
  available to confirm byte-identical output.
