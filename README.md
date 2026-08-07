# GSB Research Computing & AI Skills

> **Stanford GSB DARC · Research computing & AI skills for GSB researchers · 4 days · Hands-on**

A four-day hands-on course covering the command line, the Yens cluster, SLURM, GPU jobs, LLM APIs, and AI coding tools. The course runs as a game — complete rooms, earn skills, and take on optional challenges.

**🌐 Course website:** <https://gsbdarc.github.io/gsb-research-computing-ai-skills/>

> Forked this repo? Once you enable GitHub Pages on your fork, your own copy of the site lives at `https://YOUR-USERNAME.github.io/gsb-research-computing-ai-skills/` — that's the one that tracks your progress and leaderboard rank.

---

## What You'll Learn

| Day | Focus | Skills |
|-----|-------|--------|
| **Day 1** | Foundations | CLI · SSH · Yens file system · Git · Claude Code |
| **Day 2** | Python & AI tools | JupyterHub · Python envs & reproducible venvs · AI Playground · Secure key management · Pydantic · LLM-as-a-judge · AI agents & data privacy |
| **Day 3** | Cluster computing | SLURM · Resource estimation · Job lifecycle · Job monitoring |
| **Day 4** | Parallelization & local LLMs | Parallelization · Job arrays · Local LLMs on cluster hardware · GPU vs CPU · LLM failure modes & validation |

## Resource Profile

### extract_form_3_batch.py — 10 filings

- Yen node used: yen5
- Wall-clock time (real): 0:12.72 (~13 sec)
- CPU cores used: 1 (21% of one core — mostly waiting on network/API responses, not compute)
- RAM used (RES from htop, or % Mem from userload): ~120 MB peak RSS (0.00% Mem via userload) → round up to 1G when requesting resources
- Serial or parallel: Serial (filings processed one at a time in a loop)

### Capstone estimate — 100 filings (written before submission)

The batch remains serial and I/O-bound: each iteration downloads one filing,
waits for one blocking Stanford AI API response, validates it, and writes one
JSON result before starting the next iteration. Therefore wall-clock time
should scale roughly with the number of filings, while CPU and peak RAM should
stay about flat. The API response time can vary, so this is an estimate rather
than an exact 10x prediction.

- Wall-clock estimate: **about 2 minutes 10 seconds** (10 x ~13 seconds), with
  a **10-minute Slurm time limit** for API/network variability.
- CPU estimate/request: **1 CPU**, with utilization around **21% of one core**;
  CPU demand stays about flat because the loop waits on the network.
- RAM estimate/request: **about 120 MB peak RSS**, so **1G requested**; only
  the current filing and response are held, rather than all 100 filings.
- Scaling: **wall-clock time scales with filing count; CPU allocation and peak
  RAM stay approximately flat** for this sequential implementation.

### Capstone actual — job 424585 (100 filings)

The first submission (job 424572) reached filing 78 before an API HTTP 429
rate-limit response. I added a 2-second pause between API calls and made the
script resume existing output files, then reran it successfully. The second
run's log says **100 filings processed**, and all 100 targeted JSON outputs are
present.

- Elapsed: **2 minutes 21 seconds** (`sacct`), versus my **2:10 estimate**;
  I under-estimated wall time by **11 seconds** (about 8.5%).
- MaxRSS: **91,060 KB (~88.9 MiB)**, versus my **~120 MB estimate**; RAM was
  about **31 MB lower** than estimated (roughly 26% under).
- CPU: **1.939 seconds total CPU time** over 2:21 elapsed, confirming the job
  was I/O-bound. The script requested 1 CPU; Slurm's accounting shows 2
  allocated CPUs on `dev`, while actual CPU use remained tiny.
- The job requested 1G RAM and stayed far below it. It completed within the
  revised 15-minute time limit.

The result supports the scaling model: wall time grows with the number of
filings and API latency, while CPU and peak RAM remain nearly flat.

## Cluster Usage Snapshot — Finding

Exploring a `yenstop` snapshot of yen1 (`yenstop_exploration.ipynb`) turned up a good reminder of how noisy a shared node looks vs. how little of it is actual work: of 3,028 processes captured, only **3 were actually running** at that instant, and just **269 (9%)** were user processes at all — the rest was kernel threads and system daemons.

Among the real work, the two heaviest CPU users were tied at 96.9% (one full core each) — but their memory footprints were nowhere close: one process (`lenardst`, `python`) was holding **24.4 GB** resident (cross-checked against `mem_pct` = 2.4% of yen1's ~1 TB RAM), while the other (`angikar`, `python3`) used under **1 MB**, a ~25,000x difference despite identical CPU load. CPU-bound and memory-bound are independent axes — a process saturating a core tells you nothing about how much RAM it's holding, and vice versa. See `usage_plot.png` for the CPU-vs-memory scatter that makes the gap visible.

### Side quest — per-user usage vs. the whole node

Grouping the same yen1 snapshot by `user` and summing `cpu_pct`/`mem_pct` across each person's processes: 29 distinct users had at least one process running. The two heaviest, `angikar` and `lenardst`, each totaled **96.9%** CPU (one full core) — nobody was spread across multiple cores. Summed across *all* 269 user processes, total CPU demand was **224.9%** (~2.25 cores) and total memory demand was **3.6%** of RAM.

Against yen1's documented ~256 cores and ~1 TB of RAM, that's well under 1% of the node's total CPU capacity and under 4% of its RAM in use at that instant — the node was nowhere near full, even though two individual users were each pegging a full core. That's the per-user cap doing its job: it stops any one person from claiming the whole machine, not from stopping the machine from mostly sitting idle.

I couldn't pin down the exact numeric per-user cap for yen1 to compare against — the [Yen user limits page](https://rcpedia.stanford.edu/_policies/user_limits/) renders that table through a JavaScript-only Airtable embed that neither `curl` nor Claude's fetch tools can read (no browser tool was available in this session). Worth a manual look if you want the precise ceiling — the page states plainly that limits vary by node, which lines up with what we can observe directly: `yen5`, the node this session is running on, has only **32 physical cores** and **1.5 TB RAM** (via `lscpu`/`free -h`), quite different from yen1's ~256 cores — so a single fixed number wouldn't have applied across nodes anyway.

### Side quest — watching `top` live on yen5

Ran `top -b -n 1` twice, 3 seconds apart, on yen5 (this session's node) instead of the frozen yen1 CSV:

```
11:00:08 up 13 days, 20:10, 17 users, load average: 3.08, 2.75, 3.19
Tasks: 816 total, 1 running, 814 sleeping, 0 stopped, 1 zombie
%Cpu(s): 9.2 us, 6.8 sy, 0.0 ni, 83.9 id, ...
MiB Mem: 1546616 total, 284448 free, 22269 used, 1239898 buff/cache
```

Between the two snapshots the numbers visibly moved: `falcon-+` (a system daemon) jumped from 10.5% to 175% CPU (multi-threaded, so it can exceed one core), a `claude` process owned by another user went from not-in-top-5 to 115% CPU, and the load average and idle % shifted too — confirming this is a live, refreshing view rather than a photograph. Most of the 816 tasks sat `S` (sleeping); only 1–2 were `R` (actually running) at either instant, same pattern as the yen1 CSV. One of the processes in the table was this very Claude Code session (`claude`, owned by `adq`) — a reminder that the monitoring tool sees its own agent as just another row.

## Day 4 Challenge — all 992 filings

The input contains 992 SEC Form 3 `.txt` URLs (994 CSV rows including the header and the placeholder URL). Yens reports `MaxArraySize = 512`, so one filing per task cannot cover this workload. I considered three layouts:

- 512 tasks: 480 tasks process two filings and 32 process one. This offers the most task-level parallelism, but needs uneven assignment logic.
- 496 tasks: every task processes two filings. This is the chosen layout because it is simple, balanced, and 16 tasks below the cluster cap.
- 248 tasks: every task processes four filings. This reduces scheduler overhead, but makes each task slower and makes a single task failure affect more filings.

`slurm/extract_array.slurm` requests `--array=1-496`; `scripts/extract_array.py` maps each task to two URLs. It keeps the Gemini model as `gemini-2.5-flash` through the Stanford AI API Gateway, uses one CPU and 1G RAM per task, retries transient/API validation failures with backoff, and writes one JSON file per filing.

Job **424958** completed with **991 of 992** result files. The only failure was filing `0001104659-20-113183`: Gemini returned multiple insider names as a list even though the flat schema required a string. I added a validator that joins multiple names and reran only task 158 as job **425455**. The final count is **992 of 992**, with every input URL matched to a JSON result.

The output is resumable: before making a paid API call, a task checks whether that filing's JSON already exists. A rerun therefore skips completed filings and only spends work on missing outputs. The same approach also made the one-filing repair selective instead of restarting the full array.
