#!/bin/bash
# Approach 3 — "Ways to Parallelize": MANY JOBS, MANY CORES.
# Both at once: a job array (parallel across jobs) where each task also
# reserves 2 cores and fans its slice out across them with xargs -P
# (parallel within each job).
#
# Run from the repo root (needs .env for the API key):  sbatch .instructor/parallelization_demos/4_many_jobs_many_cores.slurm
#SBATCH --job-name=demo-many-jobs-many-cores
#SBATCH --output=logs/demo4_%A_%a.out
#SBATCH --error=logs/demo4_%A_%a.err
#SBATCH --time=00:10:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=2
#SBATCH --array=1-2

cd $HOME/gsb-research-computing-ai-skills
source .venv/bin/activate

export OUT=/scratch/shared/$USER/demo_results
LIST=/scratch/shared/$USER/demo_urls.txt
mkdir -p "$OUT"
python .instructor/parallelization_demos/make_url_list.py "$LIST"   # every task rebuilds the same list; harmless

# same chunking as demo 3: one contiguous slice of the list per array task
TOTAL=$(wc -l < "$LIST")
CHUNK=$(( (TOTAL + SLURM_ARRAY_TASK_COUNT - 1) / SLURM_ARRAY_TASK_COUNT ))
START=$(( (SLURM_ARRAY_TASK_ID - 1) * CHUNK + 1 ))
END=$(( START + CHUNK - 1 ))

# ...but within the slice, fan out across this task's reserved cores
sed -n "${START},${END}p" "$LIST" | xargs -P "$SLURM_CPUS_PER_TASK" -n1 \
    bash -c 'python .instructor/parallelization_demos/extract_one_url.py "$1" "$OUT/$(basename "$1" .txt).json"' _
