#!/bin/bash
#SBATCH --job-name=hello
#SBATCH --output=logs/hello_%j.out
#SBATCH --error=logs/hello_%j.err
#SBATCH --time=00:01:00
#SBATCH --mem=1G
#SBATCH --cpus-per-task=1

# One script, one task — the baseline for the array demo on SLURM Job Arrays.
# Stripped of real work so the only thing on show is the shape of a submission.
# Pairs with slurm/hello_array.slurm, which is this script plus one directive.
#
# Run from the repo root (logs/ must exist — SLURM won't create it):
#     mkdir -p logs
#     sbatch slurm/hello.slurm
#     cat logs/hello_<jobid>.out
echo "Hello, world!"
