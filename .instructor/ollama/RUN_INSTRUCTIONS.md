# Running the Day 4 GPU-vs-CPU demo

The demo behind the
["Running Local LLMs on Different Types of Hardware"](../../docs/day4/running-llms.md)
section: the same model answering the same query on a GPU and on a CPU, so the
room can hear the difference in how fast the words arrive.

## How the demo runs

```bash
# stand up both servers (independent jobs, either order)
bash .instructor/ollama/ensure_ollama_gpu.sh    # prints GPU server URL
bash .instructor/ollama/ensure_ollama_cpu.sh    # prints CPU server URL

# same query to each — the URL each script prints, /v1 included
python .instructor/ollama/query_server.py --url http://<gpu-host>:<port>/v1
python .instructor/ollama/query_server.py --url http://<cpu-host>:<port>/v1
```

Run from the repo root, on a Yen login node, with the course venv active
(`query_server.py` needs `openai`).

Each query prints the answer, then a timing line: `[3.2s, 31.4 tok/s]`.

**Read the tok/s, not the wall clock.** Wall clock confounds speed with answer
length. Both sides run the same model (`llama3.2:1b`), the same default query,
and the same 100-token cap, so they generate the same number of tokens and only
the time to do so differs — which is the whole point.

## Before class

- **Restore the reservation.** Both `ensure_ollama_*.sh` scripts are thin
  wrappers that hand off to `ensure_ollama_server.sh`, and that is where the
  settings live. It currently defaults `RESERVATION` to empty (line 131), so
  jobs go to the open GPU queue. Either change the default back to `class_day4`
  or pass `RESERVATION=class_day4` on the command line. It only affects the GPU
  server — the reservation holds GPU nodes, so the script deliberately drops it
  for the `GPUS=0` CPU job, which would otherwise never schedule.
- **Take the timings yourself.** The
  [2026-08-02 dry run](dry-run-2026-08-02.md) stood the CPU server up but never
  sent it a query, so the GPU-vs-CPU contrast is still unmeasured. Run both
  sides once so you know the numbers you are about to point at.
- **Allow time for the pull.** A cold start downloads the ~2 GB of weights, and
  the CPU server keeps a separate scratch tree, so it pulls its own copy.

Co-authored by Claude (Anthropic).
