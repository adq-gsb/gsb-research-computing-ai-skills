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

## Blocked on external fix

### Extraction scripts moved off `gpt-4o-mini` — revert when the gateway is fixed
**Temporary workaround applied 2026-08-01.** All four extraction scripts now call
`gemini-2.5-flash-lite` (Day 2's model) instead of `gpt-4o-mini`:

- `.instructor/parallelization_demos/extract_one_url.py`
- `scripts/extract_form_3_batch.py`
- `scripts/extract_form_3_one_file.py`
- `scripts/extract_form_3_cli.py`

**Why.** The Stanford gateway rejects `gpt-4o-mini` for our key with a 401
`key_model_access_denied`, so every filing fails (observed on Slurm job `402079`:
20/20 calls rejected). The [rates page](https://uit.stanford.edu/service/ai-api-gateway/rates)
*does* list GPT-4o-mini as an available, priced model, so this is a per-key
entitlement gap rather than a retired model. `client.models.list()` against the key
returns 27 models including a malformed **`gpt-4.omini`** — almost certainly
`gpt-4o-mini` registered with a typo on the gateway side, and plausibly the whole
cause. The string appears nowhere in this repo; it comes back from the gateway.

**Action:** ask the gateway admins whether `gpt-4.omini` is that typo and can be
corrected. If they fix it, revert the four `model=` lines. Both the working model
name and the fallback are recorded here so the revert is mechanical.

**Prompt change that came with it.** `gemini-2.5-flash-lite` returns the result
wrapped in a JSON array on roughly 60% of filings (measured 3/5), which fails
`Form3Filing.model_validate_json`. All four system prompts gained a line:

> Return a SINGLE JSON object, not a list. Do not wrap it in an array.

That took it to 5/5 valid on the same filings. The line is harmless for
`gpt-4o-mini`, so it can stay after the revert.

**Left inconsistent on purpose.** Two doc pages still name `gpt-4o-mini` in prose —
`docs/day4/putting-it-all-together.md:27` and `docs/day4/validating-llm-outputs.md:76`
— on the assumption this is short-lived. If the gateway fix drags, update them or
the pages will contradict the code students run.

**Not yet checked:** whether the *shared course key* at
`/scratch/shared/gsb-research-computing-ai-skills/.env` has the same gap. If it does,
Day 3's exercises break for the whole cohort, not just this account. Run
`client.models.list()` against it to confirm.

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

### Load-imbalance exercise from the archived "When One Filing Runs Long"
That section was cut from `docs/day4/parallelization.md` on 2026-08-01 as orthogonal
to the page's argument, and moved to
`docs/day4/archive/when-one-filing-runs-long.md` (nav- and search-excluded). It is a
good basis for an exercise rather than exposition: it takes eight filings, makes
filing 3 run 3× long, and shows that a shared pool of cores rebalances around it
while fixed per-job chunks cannot — plus the "longest processing time first"
heuristic and its one-third-of-optimal bound.

Real filings do vary this way, so the exercise has a natural hook: have students
process a batch where one filing is much denser than the rest, compare wall-clock
under Approach 1 vs Approach 2, and explain the gap. The archived page has the
finished animated figures already.

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

### Physical vs. virtual (hyperthreaded) CPUs go unexplained
No student-facing prose anywhere distinguishes physical cores from logical CPUs. The
only occurrences are a JavaScript variable comment
(`docs/day3/compute-environments.md:240`, "256 logical cores") and two script comments
about `OPENBLAS_NUM_THREADS`. The nearest note, `docs/day3/profiling.md:208`, covers
*cores vs. processes* — a different distinction.

The Day 4 demo callout now makes this visible, so it needs explaining. On yen20:

| Fact | Value |
|------|-------|
| `ThreadsPerCore` | 2 |
| `CPUTot` / physical cores | 512 / 256 |
| `SelectTypeParameters` | `CR_CORE_MEMORY` — Slurm allocates whole **cores** |
| `OverSubscribe` | `NO` — the sibling thread isn't given to anyone else |

So `--cpus-per-task=1` reserves one whole physical core and `sacct` reports
`ReqCPUS=1, AllocCPUS=2` (observed on jobs `402034`, `402076`, `402079`). Nothing is
misconfigured or wasted — `AllocCPUS` counts logical CPUs while `--cpus-per-task`
requests cores — but a student dividing `TotalCPU` by `AllocCPUS` gets a utilization
figure **2× too low**. Job `402079`: 17.3s over 38s is ~46% against `ReqCPUS`, but
reads ~23% against `AllocCPUS`.

Already done as a stopgap: the callout at `docs/day4/parallelization.md:173` uses
`sacct -X`, shows both `ReqCPUS` and `AllocCPUS`, and says which to divide by. That
puts the two numbers side by side, which is the natural hook for a fuller treatment —
the kitchen metaphor extends cleanly (one burner that can hold two pans is still one
burner's worth of heat).

Related: the thread-vs-process-pool caveat below is the same argument from the
software side. A student who reads `--cpus-per-task=8` as eight independent workers is
wrong twice over. Worth writing the two together.

Not checked: whether `--hint=nomultithread` changes what `AllocCPUS` reports on this
cluster. Expected to be a no-op for allocation under `CR_CORE` (it affects task
binding), but unverified — a ~10-second job settles it before any of this reaches
students.

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

### `filing_date` comes back in inconsistent formats
The extraction prompt names the field but never specifies a format:

> `filing_date`: The filing date (prefer signatureDate or FILED AS OF DATE).

So the model is free to echo whatever the filing used. Observed across three
filings on 2026-08-01: `2022-04-07`, `20210830`, `20210122` — ISO and compact in the
same batch. `Form3Filing` types the field as a bare `str`, so pydantic accepts all of
them and nothing downstream notices. Any analysis that sorts or filters by date gets
silently wrong answers.

Two fixes, worth doing together:

1. **Pin the format in the prompt** — "Return `filing_date` as `YYYY-MM-DD`."
2. **Enforce it in the schema** — `datetime.date`, or a `str` with a pattern
   constraint, so a violation fails loudly instead of being written to disk.

Applies to all four extraction scripts, which share the prompt and the schema.

**Scope caveat:** observed only under `gemini-2.5-flash-lite` (the current model). It
is *not* known whether `gpt-4o-mini` behaved the same way, since the key can no longer
reach it to test. The cause looks model-independent — an underspecified prompt — but
that is reasoning, not measurement.

Good teaching hook rather than just a bug fix: `docs/day4/validating-llm-outputs.md`
already teaches format/type sanity checks, and this is a real instance from the
course's own pipeline.

---

## Housekeeping

- `docs/day4/proposed_agenda.md` has dead links pointing at deleted archive files.
  It's `nav_exclude`/`search_exclude` but still reachable. Fix or delete.
- `node` isn't installed on the current dev machine, so
  `.instructor/gen_quest_keys.js` can't be run directly; `docs/_data/quest_keys.json`
  was last regenerated by a Python port of it. Re-run the real script when node is
  available to confirm byte-identical output.
