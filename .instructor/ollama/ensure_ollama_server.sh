#!/bin/bash
# Make sure a shared Ollama server is up, and print its URL. Run this at the
# start of Day 4 — or, better, the evening before, so a busy GPU queue is a
# problem you discover with time to spare rather than in front of the room.
#
#     bash .instructor/ollama/ensure_ollama_server.sh
#
# Idempotent and safe to re-run: if a healthy server is already answering it
# prints the URL and exits without submitting anything. Otherwise it submits
# start_ollama_server.sh to the GPU partition and waits for it to answer.
#
# Unlike start_ollama_server.sh, this does not need an interactive session or
# `screen` — the server runs as a batch job, so it survives a dropped
# connection and a closed laptop.
#
# Environment overrides:
#   WALLTIME=4:00:00      how long the server should live; see the note below
#   CONSTRAINT=...        which cards are eligible; see the default below
#   MODEL=llama3.2:3b     passed through to the server script
#
# Co-authored by Claude (Anthropic).

set -euo pipefail

SCRATCH_BASE="${SCRATCH_BASE:-/scratch/users/$USER}"
COORD_DIR="${SCRATCH_BASE}/ollama"

# An inherited SCRATCH_BASE beats the default above, and this is easy to hit by
# accident: DARC's own guide still says `export SCRATCH_BASE=/scratch/shared/$USER`
# (rcpedia, May 2025), which is the *superseded* per-user path — DARC confirmed
# 2026-08-02 that per-user scratch moved to /scratch/users/<user>/. Both
# directories still exist, so the old one fails silently rather than loudly:
# the server starts fine, just with weights and coordinates in the wrong place.
#
# /scratch/users/$USER is mode 700, so students cannot read host.txt/port.txt.
# That is the intended arrangement — read the URL out to the room.
#
# Note /scratch/shared/<project>/ paths (e.g. the course datasets) are a
# different thing entirely and are unaffected; only the per-user path moved.
echo "SCRATCH_BASE=$SCRATCH_BASE"
case "$SCRATCH_BASE" in
  */scratch/shared/*)
    cat >&2 <<WARN

  ⚠  That is the superseded per-user scratch path. Per-user scratch is now
     /scratch/users/\$USER — DARC's rcpedia guide has not been updated.
     Continuing, but weights and host.txt/port.txt will land in the old place.
     To use the current path:  unset SCRATCH_BASE

WARN
    ;;
esac
JOB_NAME="${JOB_NAME:-ollama-server}"

# Partition and GPU count are overridable so the same script can stand up the
# CPU contrast server alongside the GPU one — same image, same model, same
# queries, answers arriving a word at a time. To run both at once:
#
#     bash ensure_ollama_server.sh                      # the GPU server
#     SCRATCH_BASE=/scratch/users/$USER/cpu \
#     JOB_NAME=ollama-cpu PARTITION=normal GPUS=0 \
#       bash ensure_ollama_server.sh                    # the CPU one
#
# The separate SCRATCH_BASE is not optional. ollama.sh keeps port.txt, host.txt
# and models under a single ${SCRATCH_BASE}/ollama, so two servers sharing one
# would overwrite each other's coordinates and you would lose track of the first.
# The cost is that the second tree re-downloads the ~2 GB of weights.
#
# --nv stays hardcoded in ollama.sh even with GPUS=0; on a CPU node Apptainer
# prints "Could not find any nv files on this host!" and continues (verified on
# yen20, 2026-08-02), so no patch to the helper is needed.
PARTITION="${PARTITION:-gpu}"
GPUS="${GPUS:-1}"

# Day 4 is ~3 hours (docs/day4/index.md), so 4 gives an hour of slack for a late
# start or an overrun. The GPU is held for the *whole* walltime whether or not
# anyone is querying, so don't inflate this "just in case" — there are 14 GPUs on
# the cluster. If you pre-submit the evening before to dodge a morning queue, it
# has to span the gap *and* the session (e.g. WALLTIME=15:00:00 for a 9pm
# submission), which is still inside the gpu partition's 1-day cap.
WALLTIME="${WALLTIME:-4:00:00}"
# Stay off yen-gpu4. It holds the only two H200s (141 GiB each) — the scarcest
# hardware on the cluster and what colleagues with genuinely large models need.
# llama3.2:3b is ~2 GB quantised and fits comfortably on an A30, so pinning the
# demo to the big card would be pure waste. This still leaves 12 of the 14 GPUs
# eligible, so it costs little queue time. Set CONSTRAINT= to allow any node.
CONSTRAINT="${CONSTRAINT-GPU_MODEL:A30|GPU_MODEL:A40}"
MODEL="${MODEL:-llama3.2:3b}"
WAIT_SECONDS="${WAIT_SECONDS:-1800}"   # covers a cold image+model pull, and queueing

SERVER_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/start_ollama_server.sh"

# --- is something already serving? -----------------------------------------
# Health-probe rather than trust the coordinate files: they are written at
# startup and never cleaned up, so after a job ends they still name a host and
# port with nothing behind them. Only a reply from the endpoint counts.
#
# And probe for the *model*, not the port. start_ollama_server.sh runs
# `ollama pull` only after the server has bound, so there is a window — minutes
# wide on a cold cache — in which GET / cheerfully answers "Ollama is running"
# while every real query returns `model 'llama3.2:3b' not found`. Announcing the
# URL during that window is the worst possible time to be wrong about it: the
# whole class queries at once and every one of them gets an error.
current_url() {
  [ -s "${COORD_DIR}/host.txt" ] && [ -s "${COORD_DIR}/port.txt" ] || return 1
  local host port
  host=$(<"${COORD_DIR}/host.txt")
  port=$(<"${COORD_DIR}/port.txt")
  curl -sf --max-time 5 "http://${host}:${port}/api/tags" 2>/dev/null \
    | grep -q "\"${MODEL}\"" || return 1
  printf 'http://%s:%s\n' "$host" "$port"
}

if url=$(current_url); then
  echo "A server is already up: $url"
  exit 0
fi

# --- is one already on its way? --------------------------------------------
# Re-running this while a job is queued or still pulling the container would
# otherwise burn a second GPU for a server nobody needs.
existing=$(squeue -u "$USER" -n "$JOB_NAME" -h -o %i 2>/dev/null | head -1 || true)

if [ -n "$existing" ]; then
  echo "Job $existing is already starting a server; waiting for it."
  jobid="$existing"
else
  mkdir -p "$COORD_DIR"     # sbatch needs the --output directory to exist
  # Clear stale coordinates so the wait below cannot be fooled by a port that
  # some unrelated process has since taken over on the old host.
  rm -f "${COORD_DIR}/host.txt" "${COORD_DIR}/port.txt"

  submit=(sbatch --parsable
          --job-name="$JOB_NAME"
          --partition="$PARTITION"
          --ntasks=1
          --time="$WALLTIME"
          --output="${COORD_DIR}/slurm-%j.out")
  # The GPU-model constraint only means anything when we are asking for a GPU;
  # applying it to a `normal` node would make the job unschedulable outright.
  if [ "$GPUS" -gt 0 ]; then
    submit+=(--gpus="$GPUS")
    [ -n "$CONSTRAINT" ] && submit+=(--constraint="$CONSTRAINT")
  fi

  # `bash -l` so the module system (and therefore `ml apptainer`) is defined.
  jobid=$(MODEL="$MODEL" "${submit[@]}" --wrap="MODEL='$MODEL' bash -l '$SERVER_SCRIPT'")
  echo "Submitted job $jobid to the $PARTITION partition (walltime $WALLTIME, GPUs: $GPUS)."
fi

# --- wait for it to answer --------------------------------------------------
echo -n "Waiting for the server to come up"
deadline=$((SECONDS + WAIT_SECONDS))
while [ "$SECONDS" -lt "$deadline" ]; do
  if url=$(current_url); then
    echo
    cat <<EOF

────────────────────────────────────────────────────────────
  Server URL — write this on the board:

      $url

  Students' first step is the reach check on running-llms.md:

      curl $url          # → Ollama is running

  then the same address as base_url="$url/v1" from Python.

  Job $jobid — logs in ${COORD_DIR}/
  Stop it with: scancel $jobid
────────────────────────────────────────────────────────────
EOF
    exit 0
  fi

  state=$(squeue -j "$jobid" -h -o %T 2>/dev/null || true)
  if [ -z "$state" ]; then
    echo
    echo "ERROR: job $jobid left the queue without serving. Last lines of its log:" >&2
    tail -20 "${COORD_DIR}/slurm-${jobid}.out" 2>/dev/null >&2 || echo "  (no log found)" >&2
    exit 1
  fi

  echo -n "."
  sleep 10
done

echo
echo "ERROR: no reply within $((WAIT_SECONDS / 60)) minutes. Job $jobid is $(squeue -j "$jobid" -h -o %T 2>/dev/null || echo gone)." >&2
echo "Check ${COORD_DIR}/slurm-${jobid}.out and ${COORD_DIR}/server.log." >&2
exit 1
