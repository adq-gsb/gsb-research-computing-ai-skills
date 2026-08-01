#!/bin/bash
# Baseline — "Ways to Parallelize": ONE JOB, ONE CORE.
# The serial baseline from Day 3: one Slurm job, one core, a for loop.
# The loop can't start filing 2 until filing 1 is done.
#
# Run from the repo root (needs .env for the API key):  sbatch .instructor/parallelization_demos/1_one_job_one_core.slurm
#SBATCH --job-name=demo-one-job-one-core
#SBATCH --output=logs/demo1_%j.out
#SBATCH --error=logs/demo1_%j.err
#SBATCH --time=00:10:00
#SBATCH --mem=2G
#SBATCH --cpus-per-task=1

cd $HOME/gsb-research-computing-ai-skills
source .venv/bin/activate

OUT=/scratch/shared/$USER/demo_results
LIST=/scratch/shared/$USER/demo_urls.txt
mkdir -p "$OUT"
python .instructor/parallelization_demos/make_url_list.py "$LIST"

# one core walks the filings in sequence
while read -r url; do
    python .instructor/parallelization_demos/extract_one_url.py "$url" "$OUT/$(basename "$url" .txt).json"
done < "$LIST"
