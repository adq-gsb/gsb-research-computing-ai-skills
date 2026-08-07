#!/bin/bash
#SBATCH --job-name=extract-array
#SBATCH --partition=normal
# 992 filings / 2 filings per task = 496 tasks (< MaxArraySize=512).
# Each task skips JSON files already written, so rerunning is resumable.
#SBATCH --array=1-496
#SBATCH --output=logs/extract_array_%A_%a.out
#SBATCH --error=logs/extract_array_%A_%a.err
#SBATCH --time=00:10:00
#SBATCH --mem=1G
#SBATCH --cpus-per-task=1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=adq@stanford.edu

cd $HOME/gsb-research-computing-ai-skills
source .venv/bin/activate

python scripts/extract_array.py "$SLURM_ARRAY_TASK_ID"
