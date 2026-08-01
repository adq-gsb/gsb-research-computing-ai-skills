# Parallelization demos (instructor)

Four Slurm scripts mapping 1:1 to the diagrams in the Day 4
["Ways to Parallelize"](../../docs/day4/parallelization.md) section.
Each extracts SEC filings from `data/aws_links.csv` — the same source as the
Day 3 batch job — varying only *how* the work is spread.

| Script | On the page | Jobs | Cores/job | Parallelism |
|---|---|---|---|---|
| `1_one_job_one_core.slurm` | the baseline | 1 | 1 | none — serial `for` loop |
| `2_one_job_many_cores.slurm` | Approach 1 | 1 | 2 | within the job (`xargs -P` across reserved cores) |
| `3_many_jobs_one_core.slurm` | Approach 2 | 2 (array) | 1 | across jobs (each task works its slice serially) |
| `4_many_jobs_many_cores.slurm` | Approach 3 | 2 (array) | 2 | both at once |

The scripts illustrate the *shape* of each approach; the filing count is a
knob, not a fixed part of the demo.

Two helpers sit alongside them, both following the conventions of
`scripts/extract_form_3_batch.py`:

| Helper | Role |
|---|---|
| `make_url_list.py` | Pulls the first N `.txt` URLs out of `data/aws_links.csv` into a list file, one per line |
| `extract_one_url.py` | Fetches **one** filing by URL and extracts it — same schema, prompt, and model as the batch script, but one filing per invocation, which is what lets the work fan out |

`extract_one_url.py` skips a filing whose output already exists, so a rerun after
a partial failure only pays for what actually failed.

## Running

From the repo root on the Yens (a `.env` with the API key must be present,
and `logs/` must exist — Slurm won't create it):

```bash
mkdir -p logs
sbatch .instructor/parallelization_demos/1_one_job_one_core.slurm
```

All four demos process the same **20 filings**, so their timings are directly
comparable — set once as `NUM_FILINGS` in `make_url_list.py`. That is 20 paid API
calls per demo, so budget 80 for a full four-way comparison against a cleared
results directory.

Expect well under a minute for the serial baseline (Day 3 measured ~2.25s per
filing), and less for the rest.

Results land in `/scratch/shared/$USER/demo_results/`; delete that directory
between runs to make timing comparisons clean.

## Comparing time and resources

The scripts don't print resource usage themselves — that's Slurm accounting's
job, queried after a job finishes. `MaxRSS` is the peak RAM actually used
(compare against the `ReqMem` you asked for); `TotalCPU` vs. `Elapsed` shows
how well the reserved cores were kept busy:

```bash
sacct -j <jobid> --format=JobID,JobName,Elapsed,TotalCPU,AllocCPUS,ReqMem,MaxRSS,State
```

Or the one-screen efficiency summary (CPU efficiency and memory utilization,
per job or per array task):

```bash
seff <jobid>        # seff 12345678, or seff 12345678_1 for one array task
```

*Co-authored by Claude (Opus 4.8).*
