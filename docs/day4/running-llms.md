---
layout: default
title: "How to Run LLMs on the Yens"
parent: "Day 4 — Parallelization & Local LLMs"
nav_order: 5
permalink: /day4/running-llms/
---

# How to Run LLMs on the Yens

<div data-room-id="d4-running-llms"></div>

The last section covered *why* you'd run a model yourself. This is a high-level overview of *how*: loading an open model onto the cluster, starting a server that holds it, and running queries against that server — potentially on a GPU, which makes inference (the work of running the model to produce an answer) much faster.

{: .note }
> **Setting up your own local LLM server.** There aren't enough GPUs on the Yens for everyone to hold one at once, and setting a server up takes time — so we won't have you each do it today. If you want to do it yourself later, every step is documented in [Running Ollama on Stanford Computing Clusters](https://rcpedia.stanford.edu/blog/2025/05/12/running-ollama-on-stanford-computing-clusters/).

---

## The Three Steps, in Outline

At a high level, running a model on the cluster comes down to three things:

1. **Loading an open model onto the cluster.** Download the weights once and cache them on cluster storage, so nothing has to be fetched again on later runs.
2. **Starting a server that holds it.** Loading a model into memory takes time, so you pay that cost once and leave the process running, rather than reloading for every query.
3. **Running queries against that server.** From your own code, across the cluster's internal network — the request never leaves the Yens. The server does the work and sends back the answer.

**[Ollama](https://ollama.com/)** is the standard way to do all three, and what we use here. It downloads open-weight models, keeps one loaded in memory, and serves it behind an HTTP API.

---

## Exercise: Querying a Local LLM

{: .demo }
> We've already done the work for you of downloading a model — `llama3.2:3b`, Meta's **open-weight** Llama 3.2 at 3 billion parameters, freely downloadable by anyone — and setting up a server.
>
> We'll write the server's URL on the board in a second — paste it in place of `<server-url>` below, then run the command to submit a query of your choosing.
>
> ```bash
> curl <server-url>/v1/chat/completions \
>   -H 'Content-Type: application/json' \
>   -d '{"model": "llama3.2:3b", "messages": [{"role": "user", "content": "<your query>"}]}'
> ```
>
> While you do that, we'll watch them arrive — the server logs every request it receives.

<label class="quest-check"><input type="checkbox" data-room="d4-running-llms" data-key="query"> I submitted a query to the local LLM and got a response back</label>

---

## Why LLMs Need a GPU

Running an LLM is, under the hood, an enormous chain of **matrix multiplications** — the same arithmetic repeated across billions of numbers. A CPU does a few of these at a time, whereas a **GPU** (graphics processing unit) has thousands of small cores that do them all at once. Because those billions of multiplications don't depend on each other, spreading them across thousands of cores clears the whole batch far faster — so a model that crawls on a CPU runs at a usable speed on a GPU.

So: "running an LLM on the Yens" really means get your job onto a **GPU node**, where the model can actually run sufficiently quickly.

{: .note }
> The dependence of LLMs on GPUs has made them enormously valuable. Indeed, the surge in the share price of NVIDIA, the dominant GPU maker, tracks the AI boom:
>
> <svg viewBox="0 0 600 278" role="img" aria-labelledby="nvda-title nvda-desc" xmlns="http://www.w3.org/2000/svg" style="display:block;width:100%;max-width:600px;height:auto;margin:1.5rem auto" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif">
>   <title id="nvda-title">NVIDIA share price over time</title>
>   <desc id="nvda-desc">A line chart of NVIDIA's split-adjusted year-end share price from 2016 to 2024. It stays low — a few dollars — through 2019, rises through 2021, dips in 2022, then climbs steeply in 2023 and 2024 as demand for AI GPUs surges, reaching about $134 by the end of 2024.</desc>
>   <text x="300" y="20" font-size="13" font-weight="700" fill="#2c3e50" text-anchor="middle">NVIDIA's share price</text>
>   <!-- y gridlines -->
>   <line x1="50" y1="171" x2="585" y2="171" stroke="#eef1f8" stroke-width="1"/>
>   <line x1="50" y1="93"  x2="585" y2="93"  stroke="#eef1f8" stroke-width="1"/>
>   <!-- axes -->
>   <line x1="50" y1="30"  x2="50"  y2="250" stroke="#b8bfcc" stroke-width="1.5"/>
>   <line x1="50" y1="250" x2="585" y2="250" stroke="#b8bfcc" stroke-width="1.5"/>
>   <!-- y labels -->
>   <text x="44" y="254" font-size="10" fill="#6a7280" text-anchor="end">$0</text>
>   <text x="44" y="175" font-size="10" fill="#6a7280" text-anchor="end">$50</text>
>   <text x="44" y="97"  font-size="10" fill="#6a7280" text-anchor="end">$100</text>
>   <!-- price line -->
>   <polyline points="55,246 121,242 186,245 252,241 318,230 383,204 449,227 514,172 580,39" fill="none" stroke="#0072B2" stroke-width="2.5"/>
>   <circle cx="55"  cy="246" r="3" fill="#0072B2"/>
>   <circle cx="121" cy="242" r="3" fill="#0072B2"/>
>   <circle cx="186" cy="245" r="3" fill="#0072B2"/>
>   <circle cx="252" cy="241" r="3" fill="#0072B2"/>
>   <circle cx="318" cy="230" r="3" fill="#0072B2"/>
>   <circle cx="383" cy="204" r="3" fill="#0072B2"/>
>   <circle cx="449" cy="227" r="3" fill="#0072B2"/>
>   <circle cx="514" cy="172" r="3" fill="#0072B2"/>
>   <circle cx="580" cy="39"  r="4" fill="#0072B2"/>
>   <text x="578" y="33" font-size="10" font-weight="700" fill="#0072B2" text-anchor="end">~$134</text>
>   <!-- x labels -->
>   <text x="55"  y="266" font-size="10" fill="#6a7280" text-anchor="middle">2016</text>
>   <text x="121" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2017</text>
>   <text x="186" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2018</text>
>   <text x="252" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2019</text>
>   <text x="318" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2020</text>
>   <text x="383" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2021</text>
>   <text x="449" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2022</text>
>   <text x="514" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2023</text>
>   <text x="580" y="266" font-size="10" fill="#6a7280" text-anchor="middle">2024</text>
> </svg>

---

## Which Hardware You Need

The Yens have several GPU types. For our purposes they differ mainly in one thing: **VRAM** (the GPU's own memory), which sets a ceiling on how big a model you can load.

| GPU type | VRAM | Roughly good for |
|-----|------|------------------|
| A30 | 24 GB | small models, embeddings |
| A40 | 48 GB | mid-size models |
| H200 | 141 GB | large models |

A model's weights have to fit in VRAM, so VRAM — not disk or CPU RAM — is the binding constraint on which models you can run.

You request a GPU the same way you set any other resource in a Slurm script — a directive at the top:

```bash
#SBATCH --partition=gpu       # the GPU partition (confirm the name for your setup)
#SBATCH --gres=gpu:1          # request one GPU
```

Just like the `#SBATCH` directives you wrote on Day 3, this tells the scheduler what your job needs — here, one GPU. Match the partition name (and any specific-node targeting) to your cluster's current setup; ask an instructor if unsure.

{: .tip }
> **For interactive work** — exploring, pulling a model, quick tests — you don't need a batch script. Grab a GPU node directly with `srun --pty`, the same command you used for a CPU allocation on [Day 3](../../day3/ticket-rail/), plus the GPU flags:
>
> ```bash
> srun --partition=gpu --gres=gpu:1 --cpus-per-task=4 --mem=16G --time=01:00:00 --pty bash
> ```
>
> This drops you into a shell *on a GPU node* with one GPU reserved — run `nvidia-smi` to confirm. To pin a specific GPU type (e.g. the H200 for a large model), add `--constraint="GPU_MODEL:H200"`. Reach for an interactive session when you're exploring or testing; use a batch job (the Optional Practice below) for long or production runs that should queue unattended.
>
> **Release it when you're done.** Type `exit` the moment your experimentation is complete. An interactive allocation holds the GPU for the *full* `--time` you requested — even while it sits idle at your shell prompt — so no one else can use that GPU until you exit or the time limit runs out. GPUs are scarce shared resources; don't sit on one you've finished with.

<label class="quest-check"><input type="checkbox" data-room="d4-running-llms" data-key="main"> I can say what hardware a given model needs, and why VRAM is the binding constraint</label>

---

## Exercise: Query a Local Model

An Ollama server is already running on the Yens — your instructor will give you its address.

**Part 1 — Check you can reach it.** Substitute the URL you were given — it looks like `http://yen-gpu4:41234`:

```bash
curl <server-url>          # → Ollama is running
```

That request left your node, crossed to another machine on the Yens, and came back — without leaving the cluster. You are not on the machine holding the model, and you don't need to be — you don't need a GPU, the weights, or an account on that node. All you need is the address.

**Part 2 — Query it from Python.** The interface is **OpenAI-compatible**, so this is the *same* code you used for the Stanford AI API Gateway on Day 2 — only the `base_url` changes:

```python
from openai import OpenAI

client = OpenAI(
    base_url="<server-url>/v1",              # the model server on the Yens
    api_key="ollama",                          # ignored, but the client requires a value
)

response = client.chat.completions.create(
    model="llama3.2:3b",
    messages=[{"role": "user", "content": "In one sentence, what is an SEC Form 3 filing?"}],
)
print(response.choices[0].message.content)
```

Switching between a local model, the Stanford AI API Gateway, and a third-party API is a matter of changing `base_url` (and `model`/`api_key`) — the rest of your pipeline stays identical.

{: .note }
> The model runs entirely on the Yens — your prompts and data never leave the cluster. That's the privacy point from the last section, made real.

{: .warning }
> This only works while the server is running. It lives inside a Slurm job, so when that job ends the address stops answering — the model is not a permanent service on the cluster.

<label class="quest-check"><input type="checkbox" data-room="d4-running-llms" data-key="exercise"> Exercise complete — queried a model running on another node from my own</label>

---

## Optional Practice — Submit a GPU Job to the Partition

Finished early? Instead of working interactively, submit a **batch job** to the GPU partition and confirm it actually landed on a GPU.

Write `jobs/first_gpu_job.sh`:

```bash
#!/bin/bash
#SBATCH --job-name=first_gpu_job
#SBATCH --output=logs/gpu_job_%j.out
#SBATCH --error=logs/gpu_job_%j.err
#SBATCH --time=00:15:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1                     # request 1 GPU (any type is fine for this check)
#SBATCH --partition=gpu                 # GPU partition (confirm with instructor)

echo "Running on: $(hostname)"
echo "GPU info:"
nvidia-smi

source ~/gsb-research-computing-ai-skills/.venv/bin/activate
pip install torch --quiet   # if not already installed

python3 - <<'EOF'
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0)}")
print(f"VRAM total: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

# Simple GPU computation to confirm it's working
x = torch.randn(10000, 10000, device="cuda")
y = x @ x.T
print(f"Matrix multiply complete. Result shape: {y.shape}")
EOF
```

Submit it and watch the log once it runs:

```bash
sbatch jobs/first_gpu_job.sh
tail -f logs/gpu_job_JOBID.out
```

`nvidia-smi` should list a GPU, and the Python check should print `CUDA available: True` along with the GPU's name and VRAM.

{: .note }
> `torch`, or PyTorch, is one of the canonical deep-learning libraries that LLMs are architected in — which makes it a natural way to confirm the GPU is usable from Python. **CUDA** is NVIDIA's software layer that lets ordinary code run on its GPUs; `CUDA available: True` means PyTorch can actually reach the GPU.

<label class="quest-check"><input type="checkbox" data-room="d4-running-llms" data-key="side1"> Optional Practice complete — submitted a GPU job and confirmed it ran on a GPU</label>

---

## What You Learned

- You can explain why a GPU makes LLM inference fast: it is massively parallel matrix multiplication, which GPUs do far better than CPUs
- You know that **VRAM** sets the ceiling on the model size a given GPU can load, and how the Yen GPUs compare
- You can request a GPU in a Slurm job with `--partition=gpu` and `--gres=gpu:1`
- You queried a model running on the Yens from a node that wasn't hosting it — and you know switching
  between it, the Stanford AI API Gateway and a third-party API is just a change of `base_url`
- You know where the setup steps live if you want to serve a model yourself
