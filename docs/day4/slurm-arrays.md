---
layout: default
title: "SLURM Job Arrays"
parent: "Day 4 — Parallelization & GPUs"
nav_order: 2
permalink: /day4/slurm-arrays/
---

# SLURM Job Arrays

<div data-room-id="d4-slurm-arrays"></div>

You've seen when a workload qualifies for parallelization and when it helps. Now let's get more hands on: *how* to implement it on the Yens. There are a few ways to run work in parallel on a cluster; for embarrassingly parallel jobs like ours, a standard tool is a **SLURM job array**.

---

## Recap: One Script, One Task

On Day 3 you didn't run your script directly on a login node — you handed it to **SLURM**, the cluster's scheduler, in an `sbatch` script. SLURM found a free slot on a compute node, ran your job there, and saved the output. That was one input, one job.

{: .demo }
> For example, consider the following:
>
> ```bash
> #!/bin/bash
> #SBATCH --job-name=hello
> #SBATCH --output=logs/hello_%j.out
> #SBATCH --error=logs/hello_%j.err
> #SBATCH --time=00:01:00
> #SBATCH --mem=1G
> #SBATCH --cpus-per-task=1
>
> echo "Hello, world!"
> ```
>
> If we submit this, we can inspect the log file to see that the compute node printed:
>
> ```
> Hello, world!
> ```

---

## One Script, Many (Similar) Tasks

Now suppose we want to run that script not once but many times. Each run is independent of the others, so rather than one core working through them in sequence, we want many running at once.

You *could* do that by hand, submitting the script once for each run — a separate `sbatch` call, job ID, and output file every time. That's fine for four but unmanageable for a hundred. SLURM has a purpose-built tool for exactly this pattern instead.

{: .demo }
> Now the same script as an array, with one directive added:
>
> ```bash
> #!/bin/bash
> #SBATCH --job-name=hello-array
> #SBATCH --output=logs/hello_%A_%a.out
> #SBATCH --error=logs/hello_%A_%a.err
> #SBATCH --time=00:01:00
> #SBATCH --mem=1G
> #SBATCH --cpus-per-task=1
> #SBATCH --array=1-4                     # the new line, which says: run this script 4 times
>
> echo "Hello, world! My task number is $SLURM_ARRAY_TASK_ID"
> ```
>
> After submitting this job array, we should be able to see the following in the different log files:
>
> ```
> Hello, world! My task number is 1
> Hello, world! My task number is 2
> Hello, world! My task number is 3
> Hello, world! My task number is 4
> ```

{: .note }
> **`%A` and `%a` in the log names.** On Day 3 you used `%j`, the job ID, so each run wrote its own log file. An array needs two numbers instead: `%A` is the ID of the array as a whole, and `%a` is the task's index within it. Together they give every task a file of its own — for example, `hello_402103_1.out`, `hello_402103_2.out`, and so on — rather than four tasks overwriting one another.

We can see that specifying your job as an **array** tells SLURM to launch your one script many times, each run as an independent **task**.

<svg viewBox="0 0 618 270" role="img" aria-labelledby="array-title array-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:616px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
  <title id="array-title">One array script fans out into many tasks</title>
  <desc id="array-desc">A single submission script with the directive array equals 1 to N fans out into N independent tasks, numbered 1, 2, 3 and so on up to N. What each task does is determined by your code together with its array task ID.</desc>
  <!-- fan-out connectors (drawn first, behind boxes) -->
  <line x1="188" y1="129" x2="330" y2="37"  stroke="#cbd3e0" stroke-width="1.5"/>
  <line x1="188" y1="129" x2="330" y2="89"  stroke="#cbd3e0" stroke-width="1.5"/>
  <line x1="188" y1="129" x2="330" y2="141" stroke="#cbd3e0" stroke-width="1.5"/>
  <line x1="188" y1="129" x2="330" y2="221" stroke="#cbd3e0" stroke-width="1.5"/>
  <rect x="24" y="103" width="164" height="52" rx="10" fill="#eef1f8" stroke="#cdd4e6" stroke-width="1.5"/>
  <text x="106" y="124" font-size="12.5" font-weight="700" fill="#2c3e50" text-anchor="middle">SLURM script</text>
  <text x="106" y="142" font-size="10.5" fill="#6a7280" text-anchor="middle" font-family="ui-monospace, SFMono-Regular, Menlo, monospace">--array=1–N</text>
  <rect x="330" y="15" width="264" height="44" rx="8" fill="#eef5ff" stroke="#bcd4f2" stroke-width="1.5"/>
  <text x="462" y="31" font-size="12" fill="#2c3e50" text-anchor="middle">task 1</text>
  <text x="462" y="46" font-size="8" fill="#6a7280" text-anchor="middle">determined by your code <tspan font-weight="700">and</tspan> SLURM_ARRAY_TASK_ID</text>
  <rect x="330" y="67" width="264" height="44" rx="8" fill="#eef5ff" stroke="#bcd4f2" stroke-width="1.5"/>
  <text x="462" y="83" font-size="12" fill="#2c3e50" text-anchor="middle">task 2</text>
  <text x="462" y="98" font-size="8" fill="#6a7280" text-anchor="middle">determined by your code <tspan font-weight="700">and</tspan> SLURM_ARRAY_TASK_ID</text>
  <rect x="330" y="119" width="264" height="44" rx="8" fill="#eef5ff" stroke="#bcd4f2" stroke-width="1.5"/>
  <text x="462" y="135" font-size="12" fill="#2c3e50" text-anchor="middle">task 3</text>
  <text x="462" y="150" font-size="8" fill="#6a7280" text-anchor="middle">determined by your code <tspan font-weight="700">and</tspan> SLURM_ARRAY_TASK_ID</text>
  <text x="462" y="188" font-size="16" fill="#9aa2b1" text-anchor="middle">⋮</text>
  <rect x="330" y="199" width="264" height="44" rx="8" fill="#eef5ff" stroke="#bcd4f2" stroke-width="1.5"/>
  <text x="462" y="215" font-size="12" fill="#2c3e50" text-anchor="middle">task N</text>
  <text x="462" y="230" font-size="8" fill="#6a7280" text-anchor="middle">determined by your code <tspan font-weight="700">and</tspan> SLURM_ARRAY_TASK_ID</text>
  <!-- caption -->
  <text x="309" y="263" font-size="12.5" fill="#6a7280" text-anchor="middle">One submission becomes N independent tasks, each with its own task ID.</text>
</svg>

The task number is what makes this general. Every task runs the identical script, and `SLURM_ARRAY_TASK_ID` is the only thing that differs between them — so wherever the work needs to vary, you derive it from that number: which file to read, which row of a list to process, which parameter value to try.

{: .warning }
> **Counting from 1.** `--array=1-N` numbers the tasks 1, 2, … N. Slurm doesn't insist on that: numbering from 0 instead, so the tasks run 0 through N − 1, is equally valid. But starting at 1 is the convention used here, and it matters as soon as the task ID indexes something. In some languages a list of N items, `items`, is indexed 0 through N − 1, so a 1-based task ID has to be shifted — `items[task_id - 1]` rather than `items[task_id]`. Get it wrong and nothing complains up front: the first item is silently skipped, and the last task runs off the end of the list.

---

## Exercise

Now over to you. Your job is the following: process and extract information from 100 SEC filings using a job array.

The task ID is just an integer — *you* decide what it points to. The usual pattern has these steps:

**1. List the filings, one file path per line.** Write the paths to a file such as `filings_list.txt`; the line number is what each task ID will refer to.

**2. Have each task grab its own line.** Use `SLURM_ARRAY_TASK_ID` to pull the matching line from that list:

```bash
# each line of filings_list.txt is the path to one filing;
# grab the line whose number matches this task's ID
FILING=$(sed -n "${SLURM_ARRAY_TASK_ID}p" filings_list.txt)
```

Now `$FILING` holds the path to a different filing in each task — task 1 gets the path on line 1, task 2 the path on line 2, and so on.

**3. Use a script that accepts the path as an argument.** The Day 3 `extract_form_3_one_file.py` hard-codes its `FILING_PATH`, so it can't be pointed at a different filing per task. We've provided `scripts/extract_form_3_cli.py` — the same extraction logic, with a few lines added so it reads the paths from the command line:

```python
import sys
from pathlib import Path

FILING_PATH = Path(sys.argv[1])     # 1st argument: the filing to process
OUTPUT_PATH = Path(sys.argv[2])     # 2nd argument: where to write the result
```

Now you can point it at any filing (the two paths are passed in order):

```bash
python scripts/extract_form_3_cli.py path/to/filing.txt results/filing.json
```

**4. Put it all in the array script,** which hands each task its own input and output paths:

```bash
#!/bin/bash
#SBATCH --job-name=extract_array
#SBATCH --output=logs/extract_%A_%a.out    # %A = array job ID, %a = task ID
#SBATCH --error=logs/extract_%A_%a.err
#SBATCH --time=00:15:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --array=1-100                        # one task per filing

source .venv/bin/activate

# this task's filing path = the matching line of the list
FILING=$(sed -n "${SLURM_ARRAY_TASK_ID}p" filings_list.txt)

# hand that path — and a per-task output file — to the script
python scripts/extract_form_3_cli.py "$FILING" "results/filing_${SLURM_ARRAY_TASK_ID}.json"
```

{: .note }
> **More filings than the scheduler allows?** SLURM caps how many tasks an array can have, so if you have more filings than that limit, you can't give each one its own task. The fix is to hand each task a *chunk* of filings: task *n* processes a fixed block of lines from the list, with a `for` loop working through that block in sequence. The array runs the chunks in parallel; the loop handles the filings within each chunk.

**5. Combine the outputs (optional).** Each task writes its *own* file (`results/filing_1.json`, `filing_2.json`, …), and that separation is deliberate. The tasks run at the same time, so if they all tried to append to one shared output file, their writes would interleave and overwrite each other — a **"race condition"** (a bug whose outcome depends on the unpredictable order in which simultaneous operations happen to run), leaving you with a garbled, unusable file. Giving each task its own file sidesteps that entirely. Once the array finishes, you stitch those per-task files into a single dataset (such as one CSV) as a quick post-processing step — the [exercise](../array-exercise/) walks through it.

---

## Why an Array Beats Submitting by Hand

- **SLURM schedules the tasks for you** across whatever cores are free — including the ["waves"](../parallelization/) that happen when there are more filings than cores.
- **The tasks are independent.** One task failing doesn't touch the others, and you can resubmit just the failures instead of rerunning everything.
- **There's one thing to track.** A single job ID (with per-task sub-IDs) to monitor with `squeue` or cancel with `scancel`.
- **The outputs are predictable.** `filing_${SLURM_ARRAY_TASK_ID}.json` gives you a tidy set of files, ready to combine into one CSV.

---

## Failure Resilience

Array jobs fail in pieces. A node reboots, a task hits its time limit, the API times out — and a handful of your 100 tasks come back empty. You don't want to redo the ones that already succeeded: that wastes compute, and with a paid API, money.

The fix is to make each task safe to run again. Before doing the work, a task checks whether its output already exists and skips if it does. Then, after a partial failure, you resubmit the *same* array: the finished tasks see their output and exit immediately, and only the missing ones do real work.

`scripts/extract_form_3_cli.py` includes exactly this check, right after it reads the output path:

```python
import sys
from pathlib import Path

OUTPUT_PATH = Path(sys.argv[2])

# already done? skip — makes the array safe to resubmit after a partial failure
if OUTPUT_PATH.exists():
    print(f"{OUTPUT_PATH} already exists — skipping")
    sys.exit(0)
```

---

<label class="quest-check"><input type="checkbox" data-room="d4-slurm-arrays" data-key="main"> I understand how a SLURM job array turns one script into many parallel tasks</label>

---

## What You Learned

- You can explain what a SLURM **job array** is: one script, submitted once, that SLURM runs as many independent tasks
- You know that `#SBATCH --array=1-N` creates the tasks and `SLURM_ARRAY_TASK_ID` distinguishes them
- You can map a task ID to a unit of work — e.g. selecting the matching line from a list of filings
- You know how to make a task safe to rerun — skip it if its output already exists — so a partially failed array only redoes the missing work
- You can say why an array beats submitting jobs by hand: scheduling, independence, tracking, and tidy outputs

The hands-on exercise, [Submitting an Array Job](../array-exercise/), puts this into practice.
