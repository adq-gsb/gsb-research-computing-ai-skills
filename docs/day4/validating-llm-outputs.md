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
<summary>Some important categories (expand after discussion)</summary>

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

## Exercise: Putting This Into Practice

We saw above that comparing outputs between models is a basic robustness check. Now your job is to reprocess SEC filings, building on your existing scripts. This time, though, we want you to extract the outputs using multiple models and compare the outputs.

**1. Call both models inside the loop.** Start from the batch script you ran on Day 3, `scripts/extract_form_3_batch.py`, which already loops over filings from `data/aws_links.csv`. For each filing, make the same call twice — once per model — and save the answers side by side, in a dataframe or similar. Everything else stays as it was: the prompt, the schema, the loop.

{: .tip }
> **Swapping in a second model is a one-line change.** The Stanford AI API Gateway serves many models behind one endpoint, so the same client reaches both — only the `model` argument changes:
>
> ```python
> import os
> from openai import OpenAI
>
> client = OpenAI(
>     base_url="https://aiapi-prod.stanford.edu/v1",
>     api_key=os.getenv("STANFORD_API_KEY"),
> )
>
> MODEL_A = "gemini-2.5-flash-lite"     # the model your Day 3 script used
> MODEL_B = ...                         # pick a second one — `client.models.list()`
>                                       # shows what your key can reach, as on Day 2
>
> # same call for each — only the model name changes
> answer_a = client.chat.completions.create(model=MODEL_A, messages=messages)
> answer_b = client.chat.completions.create(model=MODEL_B, messages=messages)
> ```
>
> And if you had a local LLM server running, you could of course compare against a local model too — that's a second client pointed at the server's own `base_url`, as on [the previous page](../running-llms/).

**2. Decide what "agreement" means.** Now that you have both sets of outputs in front of you, decide what counts as the same answer. For example, `Smith, John` and `John Smith` are the same person written two ways; whether your code should call that agreement is your call to make.

**3. Count.** Report two numbers: how many filings the two models agreed on, and how many they didn't.

**4. Inspect one disagreement.** Pick a filing the two models disagreed on, open it, and work out which model was right — or whether both were wrong.

<details markdown="1">
<summary>💡 Hint — reading the raw filing</summary>

A filing is just a text file at a URL, and `data/aws_links.csv` holds those URLs — the same ones your loop reads. Fetch the one you want and look at it directly:

```python
import requests

filing_url = "..."            # the URL of the filing the models disagreed on
text = requests.get(filing_url).text

print(len(text), "characters")
print(text[:3000])            # the header, where the identifying fields sit
```

Alternatively, rather than reading the whole thing, search it for what each model reported:

```python
for line in text.splitlines():
    if "<what the model reported>" in line.upper():
        print(line)
```

</details>

<label class="quest-check"><input type="checkbox" data-room="d4-failure-modes" data-key="exercise"> Exercise complete — I ran two models over the same filings, counted the disagreements, and inspected the filing where the models disagreed</label>

---

## What You Learned

- You can name the main ways LLMs fail — hallucination, inconsistency, a lack of guardrails, and standing in for thinking you should be doing yourself
- You know that an agentic LLM inherits whatever permissions you give it, and that some of what it can do — deleting or overwriting a file — cannot be undone
- You have a set of robustness checks to reach for: paying for a better model, automatic format and sanity checks, comparing across models, spot-checking a sample against ground truth, and grounding the answers that matter most
- You ran the same filings through two models, counted where they agreed, and used a disagreement to find a case worth reading by hand
- You know that one endpoint serves many models, so trying a different one is a change of the `model` argument alone
