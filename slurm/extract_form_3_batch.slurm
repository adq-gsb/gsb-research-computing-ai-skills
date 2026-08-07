#!/bin/bash
#SBATCH --job-name=adq_job
#SBATCH --partition=dev
#SBATCH --output=logs/extract_%j.out
#SBATCH --error=logs/extract_%j.err
# 100 sequential API calls: estimate ~2:10 wall time, with buffer.
#SBATCH --time=00:15:00
#SBATCH --mem=1G
#SBATCH --cpus-per-task=1
#SBATCH --mail-type=ALL
#SBATCH --mail-user=adq@stanford.edu
# Navigate to your project
cd $HOME/gsb-research-computing-ai-skills

# Activate your virtual environment
source .venv/bin/activate

python scripts/extract_form_3_batch.py
