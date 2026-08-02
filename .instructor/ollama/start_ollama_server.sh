#!/bin/bash
# Start the shared Ollama server for the Day 4 demo, and make sure the model is
# cached. Normally run this on a GPU node — grab one first with, e.g.:
#
#     srun -p gpu -G 1 -C "GPU_MODEL:A40" -n 1 -t 4:00:00 --pty /bin/bash
#
# It also runs without a GPU, which is worth demonstrating: same server, same
# queries, answers arriving a word at a time. The script warns and continues.
#
# then, ideally inside `screen` so it survives a dropped connection:
#
#     screen -S ollama
#     bash .instructor/ollama/start_ollama_server.sh
#
# The script is idempotent: the container image and the model weights are only
# downloaded if they are missing, so a re-run after a scratch purge costs a
# slower start rather than manual repair.
#
# Follows https://rcpedia.stanford.edu/blog/2025/05/12/running-ollama-on-stanford-computing-clusters/
# with two deliberate deviations: per-user scratch is /scratch/users/ (the post
# still shows the old /scratch/shared/<user>/), and we serve Meta's open-weight
# Llama 3.2 rather than the post's deepseek-r1:7b — Llama is not a reasoning
# model, so it doesn't wrap replies in <think> blocks that break strict JSON
# parsing downstream.

set -euo pipefail

MODEL="${MODEL:-llama3.2:3b}"
SCRATCH_BASE="${SCRATCH_BASE:-/scratch/users/$USER}"
HELPER_DIR="${HELPER_DIR:-$HOME/ollama_helper}"   # holds ollama.sh and ollama.sif
LOG="${SCRATCH_BASE}/ollama/server.log"

export SCRATCH_BASE

# --- where are we running? -------------------------------------------------
# CPU is supported deliberately: llama3.2:3b is small enough to answer on CPU,
# just slowly, which is worth showing. But a CPU node is almost never what you
# want by accident, so say so loudly. (nvidia-smi can exist on a node with no
# GPU allocated to you, hence -L rather than a bare command -v.)
if nvidia-smi -L >/dev/null 2>&1 && [ -n "$(nvidia-smi -L 2>/dev/null)" ]; then
  echo "GPU detected:"
  nvidia-smi -L | sed 's/^/  /'
else
  cat >&2 <<'WARN'

  ⚠  No GPU visible — the model will run on CPU.

     Expect seconds per token rather than tokens per second, and expect
     Apptainer to print "Could not find any nv files on this host!" as it
     starts: that is the GPU passthrough finding nothing, not an error.

     For the real demo, get a GPU node first — see the header of this script.

WARN
fi

# --- one-time setup, skipped when already present --------------------------
if [ ! -d "$HELPER_DIR" ]; then
  echo "Cloning ollama_helper into $HELPER_DIR"
  git clone https://github.com/gsbdarc/ollama_helper.git "$HELPER_DIR"
fi
cd "$HELPER_DIR"

ml apptainer

if [ ! -f ollama.sif ]; then
  echo "Pulling the Ollama container image (slow the first time)"
  apptainer pull ollama.sif docker://ollama/ollama
fi

mkdir -p "${SCRATCH_BASE}/ollama"

# defines the `ollama` wrapper; it exports the function so subshells inherit it
source ollama.sh

# --- start the server ------------------------------------------------------
# Redirect to a log rather than the terminal: that way the requests are both
# watchable live and kept after the session. `ollama serve` otherwise blocks.
echo "Starting the server — logging to $LOG"
ollama serve > "$LOG" 2>&1 &
SERVER_PID=$!
trap 'echo; echo "Stopping the server."; kill "$SERVER_PID" 2>/dev/null || true' EXIT

# ollama.sh picks a port and records the coordinates *before* handing off to the
# container, so these files appear almost immediately — their existence says
# nothing about whether anything is listening yet.
for _ in $(seq 10); do
  [ -s "${SCRATCH_BASE}/ollama/port.txt" ] && break
  sleep 1
done
if [ ! -s "${SCRATCH_BASE}/ollama/port.txt" ]; then
  echo "ERROR: the server never recorded a port. See $LOG." >&2
  exit 1
fi

HOST=$(<"${SCRATCH_BASE}/ollama/host.txt")
PORT=$(<"${SCRATCH_BASE}/ollama/port.txt")

# So poll the endpoint itself. Ollama answers "Ollama is running" on / once it
# has bound. Five minutes is generous, but container start on a cold cache and
# a CPU-only load are both slow.
echo -n "Waiting for http://${HOST}:${PORT} to answer"
READY=""
for _ in $(seq 150); do
  if curl -sf --max-time 2 "http://${HOST}:${PORT}/" >/dev/null 2>&1; then
    READY=1; break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo; echo "ERROR: the server exited during startup. Last lines of $LOG:" >&2
    tail -20 "$LOG" >&2
    exit 1
  fi
  echo -n "."
  sleep 2
done
echo

if [ -z "$READY" ]; then
  echo "ERROR: the server did not answer within five minutes. See $LOG." >&2
  exit 1
fi

# --- cache the model -------------------------------------------------------
# A no-op once the weights are in ${SCRATCH_BASE}/ollama/models.
echo "Ensuring $MODEL is available"
ollama pull "$MODEL"

# --- what to put on the board ----------------------------------------------
cat <<EOF

────────────────────────────────────────────────────────────
  Server URL — write this on the board:

      http://${HOST}:${PORT}

  Students test it with:

      curl http://${HOST}:${PORT}/v1/chat/completions \\
        --json '{"model": "${MODEL}", "messages": [{"role": "user", "content": "hello"}]}'
────────────────────────────────────────────────────────────

Following the log. Ctrl-C stops the server.

EOF

# Keeps the script in the foreground, so the server is not orphaned, and shows
# each request as it arrives.
tail -f "$LOG"
