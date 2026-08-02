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

### Answer key for the "When Parallelization Helps" examples
**Done 2026-08-01:** the section now closes with three `<details>` examples posed for
class discussion, following `docs/day3/profiling.md:66`. They are Ben's own, and
deliberately data-work rather than statistics flavoured:

1. Sum an array of numbers — then the sum of a complicated function of each. Tests
   *granularity*: possible either way, worthwhile only in the second.
2. Checking key uniqueness in A before merging B onto it. Tests the *partitioning
   axis* — uniqueness is global, so it parallelizes only if rows sharing a key land
   together.
3. Scraping pages in parallel while appending to one shared `.csv`. Tests
   *parallel work with a serial write*.

**Still open:** the examples are posed with no answers. Day 3 pairs its question
stack with a single `✅ Check your answer` block (`profiling.md:303`) — worth adding
if these are ever read outside a live class, since the answers are non-obvious and
two of the three are "yes, but".

### Decide whether the Rule of Thumb keeps its forward-pointing sentence
`docs/day4/why-local-llms.md:143` ends the Rule of Thumb section with:

> You'll make this call in practice — and compare a model you run yourself against
> the Playground — in the sections that follow.

**Dropped 2026-08-02.** It was a forward reference of exactly the kind being
pruned elsewhere on Day 4. If something like it is ever restored, note it named
"the Playground" where the comparison is actually against the **AI API
Gateway** — separate Stanford services, as Day 2 was corrected to say.

**Still outstanding:** the capstone has the same slip —
`putting-it-all-together.md:27` says "the Playground (`gpt-4o-mini`)" for what is
an API Gateway call. That one is live and wants fixing.

### Which script Day 4's array exercise should build on
The three extraction scripts source their filings differently, and Day 4 has to
pick one:

| Script | Day | Where the filing comes from |
|---|---|---|
| `extract_form_3_one_file.py` | 2 | a hardcoded local path — `/zfs/data/NODR/EDGAR_HTTPS/…` (`:16`) |
| `extract_form_3_batch.py` | 3 | URLs from `data/aws_links.csv` (`:23`), fetched with `requests` |
| `extract_form_3_cli.py` | 4 | a local path passed as `sys.argv[1]` |

The Slurm-arrays exercise reads URLs out of `aws_links.csv`, so its copy-paste hint
currently points at the **Day 2** script — the right pedagogical reference, since
students wrote it and it handles exactly one filing — but has to say "with one
change: it fetches over the network rather than reading a fixed path off disk."
That caveat is a smell.

Two ways out:

1. **Point the hint at the Day 3 batch script instead.** It already fetches URLs, so
   the caveat disappears. Costs the "this is the code you already wrote" framing,
   and students have to mentally strip the loop.
2. **Move Day 2 onto `aws_links.csv` too**, so one sourcing paradigm runs from Day 2
   through Day 4 and the Day 4 hint needs no caveat at all. More work, and it
   changes a page that is otherwise settled — but it is the version where the week
   tells one story.

Worth checking either way: whether that `/zfs/data/NODR/EDGAR_HTTPS/…` path is even
readable by students on the Yens, or whether it is an instructor-only mount. If it
isn't readable, option 2 stops being optional.

**Resolved 2026-08-01.** The exercise used to invoke `scripts/extract_form_3_cli.py`
with a task ID while that script took two paths and read from disk — students built
one script and ran a different one. The page now names `scripts/extract_array.py`,
which they write themselves, and `extract_form_3_cli.py` is deleted: it existed only
for the array-exercise page, which is archived. The choice above still stands for the
*hint* in step 2, which points at the Day 2 one-file script.

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
**Partly done 2026-08-01.** `docs/day4/parallelization.md` now carries four `{: .demo }`
callouts — one framing the whole comparison, one per approach — and a `demo` callout
type was added to `docs/_config.yml` (grey-dk, the one unused palette colour). So the
demo is no longer invisible.

**Still open:** the rest of Day 3's four-layer convention. Day 4's index table has no
`💬` or demo label on any row (`docs/day4/index.md:37-44`, which invented standalone
`🖊️ Concept` and `🏛️ Community` tokens Days 1–3 don't use), and there is no
participation checkbox — Day 3's `d3-compute-environments.main` reads "I participated
in the class demo and discussion", the site's only attendance-based key. Adding one
means a new key in the `DAYS` registry and regenerating `docs/_data/quest_keys.json`.
Day 4 is still the thinnest day at 9 of 76 keys.

Day 3's Compute Environments page remains the site's one complete demo convention,
a four-layer stack:

1. Index-table format label — `docs/day3/index.md:56`: `🥪💬 Demo + discussion`
2. `## Main quest — Class Participation` heading (participation noun, not an imperative)
3. `{: .important }` + `> **Task:** Take part in the class demo and discussion — …`
4. `<details><summary>❓ After the demo — discuss these</summary>` + a participation
   checkbox ("I participated in the class demo and discussion")

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

That stopgap has been reverted (2026-08-01). The callout at
`docs/day4/parallelization.md:173` briefly showed both `ReqCPUS` and `AllocCPUS` with
a sentence explaining the doubling, but it was cut as too much detail for a page that
never introduces hyperthreading. The callout now asks only for `ReqCPUS`, so students
divide by the right number and never see the discrepancy.

That keeps the page honest but leaves the concept unexplained, and anyone who runs
`sacct` with their own format string will still hit it. The kitchen metaphor extends
cleanly when someone writes the fuller treatment — one burner that can hold two pans
is still one burner's worth of heat.

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

**Status changed 2026-08-01.** The concept now enters the page as Example 3 in the
"When Parallelization Helps" question stack — scraping many pages in parallel while
appending to one shared `.csv` — posed as a class discussion prompt, so an instructor
introduces it aloud. It is deliberately *not* explained in prose anywhere. So this
exercise is now a follow-up to that discussion rather than students' first exposure.

The resolution is already the pattern they implement in `array-exercise.md`: one
output file per task, combined afterwards by `merge_results.py` (Part 4).
`extract_form_3_cli.py` writes one JSON per filing for the same reason. A good
exercise breaks that deliberately — append to a shared file from an array — has them
observe the corruption, then fix it.

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

### Decide where demo scripts belong — `.instructor/` may be the wrong home
Open question, raised 2026-08-01. Demo material currently lives in `.instructor/`:
the four `parallelization_demos/*.slurm` plus their two helpers. Two things make
that placement doubtful.

**`.instructor/` is tracked and students fork the repo.** Everything in it —
including `KEYS.md`, `capstone.key.md`, `boss-gate-1.key.md` — ships in every
student fork already. So the directory name signals "instructor-only" without
delivering it. Worth confirming whether that is intended for the answer keys too;
if not, it is a bigger problem than script placement.

**Student-facing pages may end up referencing the path.** A demo callout on
`docs/day4/slurm-arrays.md` briefly told the reader to run
`python .instructor/hello_name.py` before that example was simplified away. Any
page that points into `.instructor/` shows the student a path in a directory
that reads as off-limits, with no way to tell whether they are meant to run it.

Options, roughly:

1. **Leave it.** Simplest, but the naming keeps misleading and pages keep pointing
   into it.
2. **Move anything a student might run into `scripts/` and `slurm/`**, alongside
   `extract_form_3_cli.py` and the existing `.slurm` files, and keep `.instructor/`
   for answer keys and teaching plans only. Most consistent with how the rest of
   the repo is laid out.
3. **A third top-level directory** — `demos/` — for material that is instructor-led
   but not secret. Clearest signal, one more place to look.

Deciding this also settles whether the demos should be reproducible by students
after class, which is really the underlying question.

---

## Housekeeping

- `docs/day4/proposed_agenda.md` has dead links pointing at deleted archive files.
  It's `nav_exclude`/`search_exclude` but still reachable. Fix or delete.
- `node` isn't installed on the current dev machine, so
  `.instructor/gen_quest_keys.js` can't be run directly; `docs/_data/quest_keys.json`
  was last regenerated by a Python port of it. Re-run the real script when node is
  available to confirm byte-identical output.
