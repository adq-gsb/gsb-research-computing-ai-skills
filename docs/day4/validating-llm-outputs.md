---
layout: default
title: "Handling LLM Failure Modes"
parent: "Day 4 — Parallelization & Local LLMs"
nav_order: 6
permalink: /day4/validating-llm-outputs/
---

# Handling LLM Failure Modes

<div data-room-id="d4-failure-modes"></div>

LLMs are remarkable tools — but, as we've all found out by now, they are also **brittle**. Even the best models get things wrong, often confidently, and often enough to matter. Before you trust an LLM's output — especially at scale — you need a way to check it. The rest of this page discusses some of the failure modes to watch for, and how to build in checks to catch them before they reach your results.

---

## Common Failure Modes

Let's crowdsource your experiences with LLM failure modes. What are some different kinds you've experienced?

<details markdown="1">
<summary>Some we'll come back to (expand after discussion)</summary>

- **Hallucination** — the model produces false output, such as an invented citation, number, or quotation.

  {: .aside }
  > **Real-world case:** in 2024, Stanford misinformation expert Jeff Hancock submitted expert testimony citing journal articles that ChatGPT had invented, and the court [threw it out](https://minnesotareformer.com/2024/12/02/misinformation-expert-used-ai-to-draft-testimony-containing-misinformation-about-ai/). (Lawyers have been sanctioned for the same thing.)
  >
  > ![Minnesota Reformer headline: "Misinformation expert used AI to draft testimony containing misinformation about AI"]({{ site.baseurl }}/assets/images/hancock-ai-testimony-headline.png)
  >
  > *Source: [Minnesota Reformer](https://minnesotareformer.com/2024/12/02/misinformation-expert-used-ai-to-draft-testimony-containing-misinformation-about-ai/).*

- **Inconsistency** — ask the same question twice and you may get two different answers (model outputs are probabilistic). Downstream tasks often depend on the output having a consistent format or type, and that is not something you get for free.
- **A lack of guardrails** — this matters most for **agentic** LLMs (like Claude Code), which don't just answer but act on your system. An agent inherits the permissions you give it, so be deliberate about which ones you hand over: some actions can't be taken back, and — as you saw with `rm` on [Day 1](../../day1/command-spire/) — deleting or overwriting a file on the command line leaves nothing to recover.

  {: .aside }
  > **Real-world case:** in early 2026 a user asked Claude to organize a desktop, and it deleted a folder holding roughly 15 years of family photos — thousands of files — with irreversible terminal commands.
  >
  > ![Futurism headline: Blundering Husband Asks Claude AI to Organize Wife's PC, Accidentally Erases Her Cherished Family Photos]({{ site.baseurl }}/assets/images/claude-family-photos-headline.png)
  >
  > *Source: [Futurism](https://futurism.com/artificial-intelligence/claude-wife-photos).*

- **An imperfect substitute for your own thinking** — it can be easy to confuse rapid progress enabled by LLMs with true understanding.

  {: .aside }
  > AI researchers at Anthropic conducted a randomized experiment and found that developers who learned a new programming library with access to LLMs came out weaker at reading and debugging that code, and were no faster in executing tasks than the group without access to LLMs.
  >
  > *Source: [Shen & Tamkin, "How AI Impacts Skill Formation" (2026)](https://arxiv.org/abs/2601.20245).*

</details>

---

## Making LLM Pipelines More Robust

Because a model won't necessarily flag its own mistakes, you have to check for correctness yourself. A few complementary "techniques":

- **Trade cost off against accuracy.** Larger, more expensive models are generally more accurate, so if your budget allows, paying more per call is a simple step if accuracy is your primary concern. However, this is no substitute for the other approaches below.
- **Add format and sanity checks.** Cheap, automatic guards catch a surprising share of errors: validate structure and types with [Pydantic](../../day2/oracles-chamber/#step-6--validate-with-pydantic), as you did on Day 2, and check ranges and formats against real-world logic — a date that isn't a date, a negative probability, etc. Check the distribution of your outputs too: if you expect the data to be distributed a certain way and it isn't, that may be an indication something has gone wrong.
- **Compare across models.** Run the same inputs through two different models and look at where they *disagree*. Models may fail in different ways, and disagreement is a cheap flag for "this item is uncertain," pointing you to the cases worth reviewing.
- **Spot-check a sample against ground truth.** Have a notion of what the right answer is, then pull a random sample of outputs and check them against it by hand. Since your sample is random, if the outputs look reliable on the sample, it's more likely they're reasonable throughout.
- **Ground high-stakes fields.** For queries that really matter, have models quote the exact source text supporting each answer, so you — or a reviewer — can check it against the document.

---

## Exercise: Where Do Two Models Disagree?

You already have one set of extractions — the JSON files your array job wrote in [Slurm Job Arrays](../slurm-arrays/). Now produce a second set from a different model, and count how often the two agree.

**First, decide what "agreement" means.** Pick one field from your extractions to compare — `insider_name`, say — and decide what counts as the same answer. `Smith, John` and `John Smith` are the same person written two ways; whether your code should call that agreement is your call to make, and worth making before you see the numbers.

**Second, run the same filings through a second model.** Point the client at the other service and leave everything else alone — the prompt, the schema, the loop. Write the results to `results/model_b/` so you keep both sets.

{: .tip }
> **Swapping in a second model is a one-line change.** The Stanford AI API Gateway, a local model served by Ollama, and third-party APIs all speak the same OpenAI-compatible API — so running the same prompt through another model just means a different `base_url` (and `model`/`api_key`). The rest of your code is identical:
>
> ```python
> import os
> from openai import OpenAI
>
> # Model A — Stanford AI API Gateway
> playground = OpenAI(base_url="https://aiapi-prod.stanford.edu/v1", api_key=os.getenv("STANFORD_API_KEY"))
>
> # Model B — a local model served by Ollama on the Yens
> local = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")
>
> # Model C — a third-party provider (e.g. OpenAI); base_url defaults to the provider
> thirdparty = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
>
> # same call for each — only the client and model name change
> answer_a = playground.chat.completions.create(model="gpt-4o-mini", messages=messages)
> answer_b = local.chat.completions.create(model="llama3.2:1b", messages=messages)
> answer_c = thirdparty.chat.completions.create(model="gpt-5.6", messages=messages)
> ```

**Third, count.** Report two numbers: how many filings the two models agreed on, and how many they didn't.

**Fourth, read the disagreements.** Open the filings behind them and work out who was right — or whether both were wrong.

<details markdown="1">
<summary>💡 Hint — one way to compare</summary>

Load both sets, normalize before comparing, and keep the mismatches rather than just counting them:

```python
import json
from pathlib import Path

FIELD = "insider_name"

def normalize(value):
    """Fold away the differences you've decided not to care about."""
    return " ".join(str(value).lower().split())

agreements, disagreements = 0, []

for path_a in sorted(Path("results").glob("*.json")):      # your array job's output
    path_b = Path("results/model_b") / path_a.name         # the second model's
    if not path_b.is_file():
        continue
    a = json.loads(path_a.read_text())
    b = json.loads(path_b.read_text())
    if normalize(a[FIELD]) == normalize(b[FIELD]):
        agreements += 1
    else:
        disagreements.append((path_a.name, a[FIELD], b[FIELD]))

print(f"{agreements} agreed, {len(disagreements)} disagreed")
for name, left, right in disagreements:
    print(f"  {name}: {left!r} vs {right!r}")
```

</details>

The point isn't to decide which model is better. It's that **disagreement is a cheap flag for "look here"** — you get it without knowing the right answer for a single filing, and it costs one extra run rather than a human reading all twenty.

{: .note }
> The two models won't be evenly matched — a small local model and a frontier model are not peers, and most disagreements will be the smaller one slipping. That doesn't spoil the signal. You're not asking the second model to be right; you're asking it to be *different enough* that the hard cases stand out.

<label class="quest-check"><input type="checkbox" data-room="d4-failure-modes" data-key="exercise"> Exercise complete — I ran two models over the same filings, counted the disagreements, and read them</label>

---

## Failure Modes in Automated Pipelines

Validation catches wrong *outputs*. A different class of failure appears once you run LLMs *unattended* — in an automated pipeline or agent that reads, writes, and loops on your behalf, with no human watching each step. These need architectural guards, not validation.

### Irreversibility {#irreversibility}

The stakes rise sharply when an LLM's output drives an action — writing to a database, sending emails, deleting files. LLMs make mistakes, and mistakes that change state are the most expensive kind: you often can't undo them.

Recall from [Day 1](../../day1/command-spire/) that `rm` deletes permanently — no trash, no undo; an agent runs the same commands, just without a human pausing to reconsider. Agents run with *your* full permissions, so "clean up this folder" can reach anything you can.

**Guarding against it:** the reliable defense is "least privilege": giving the agent only the access it truly needs (read-only where possible; scoped, minimal credentials), and requiring confirmation for anything that changes state. Keep automated pipelines read-only where you can; for writes, log the intended action first, act second, and verify before committing — and build a **dry-run mode** that prints what *would* happen without doing it.

### Prompt Injection

Your input data isn't always trustworthy. A document you feed the model can contain adversarial text — for example, "Ignore all previous instructions and…" — that hijacks its behavior, making it do something other than the task you intended. Data scraped from the public web is especially risky.

**Guarding against it:** keeping your instructions in the system message and untrusted data in a separate user message helps — models are trained to prioritize system instructions — but it's a *partial* mitigation, not a hard boundary: to the model it's all just text, and a determined injection can still get through. So lean on the real backstops: validate the output before you rely on it, and apply least privilege (see [Irreversibility](#irreversibility) above) — assume the model can be manipulated, and make sure it simply *can't* take a harmful action.

### Runaway Loops

An automated pipeline that retries on failure with no cap can retry forever — until it times out or burns through your API budget. A step that calls itself with no stopping condition can fan out exponentially.

**Guarding against it:** cap everything — a `max_retries` on each retry loop, a spend/budget limit on the whole job, and a sanity timeout. Log each iteration, and if a job runs well past its expected time, kill it and investigate.

<label class="quest-check"><input type="checkbox" data-room="d4-failure-modes" data-key="main"> I can name the main LLM failure modes and how to guard against each</label>

---

## What You Learned

- Even frontier models are brittle and unevenly capable — you can't assume an output is correct, so you measure your own error rate rather than trust a benchmark headline
- Hallucination is the core correctness failure: the model isn't well calibrated, so a confident tone tells you nothing about whether an answer is right
- You can validate outputs at scale — spot-checking against the source, format/type sanity checks, grounding high-stakes fields, and comparing across models (a one-line `base_url` swap)
- You can name the failure modes that appear once LLMs run unattended — irreversibility, prompt injection, and runaway loops — and their architectural guards: least privilege, separating instructions from untrusted data, and caps/timeouts
