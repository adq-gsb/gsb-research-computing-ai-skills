#!/bin/bash
#SBATCH --job-name=hello-array
#SBATCH --output=logs/hello_%A_%a.out
#SBATCH --error=logs/hello_%A_%a.err
#SBATCH --time=00:01:00
#SBATCH --mem=1G
#SBATCH --cpus-per-task=1
#SBATCH --array=1-4                     # the new line, which says: run this script 4 times

# slurm/hello.slurm with one directive added. That single line turns one
# submission into four independent tasks, identical except for the task ID
# each one is handed. See SLURM Job Arrays.
#
# %A is the array's job ID and %a the task's index, so every task writes its
# own log rather than four tasks overwriting one file.
#
# Run from the repo root (logs/ must exist — SLURM won't create it):
#     mkdir -p logs
#     sbatch slurm/hello_array.slurm
#     cat logs/hello_<arrayid>_*.out
echo "Hello, world! My task number is $SLURM_ARRAY_TASK_ID"
