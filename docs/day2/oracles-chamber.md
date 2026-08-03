---
layout: default
title: "The Oracle's Chamber"
parent: "Day 2 — The Alchemist's Lab"
nav_order: 6
permalink: /day2/oracles-chamber/
---

# The Oracle's Chamber

<div data-room-id="d2-oracles-chamber"></div>

The Oracle answers, but only as well as you ask. In this room you make your first live call to the Stanford AI API Gateway, then put a model to real work: reading a dense SEC Form 3 filing and pulling out who filed it and in what role. You will shape the prompt until the answer comes back clean, validate it with Pydantic so bad output fails loudly instead of corrupting your results, and move the working logic out of the notebook into a logged, reproducible script.

---

## 🗡️ Main Quest

{: .important }
> **Quest:** Make your first live API call, then use the Stanford AI API Gateway to extract structured information from a real SEC Form 3 filing, and save the logic to a standalone Python script.

---

### Step 1: Open the Oracle's Notebook

Every invocation in this room happens in one notebook. In JupyterHub (on the Yens), open your `day2/` folder and create a **new notebook named `oracle.ipynb`**. From the kernel menu in the top-right, choose **Bootcamp 2026**, the kernel you forged in [The Venv Forge](../venv-forge/).

{: .important }
> Selecting the **Bootcamp 2026** kernel is what gives this notebook its reagents (`openai`, `python-dotenv`, and `pydantic`), the packages you installed into that venv. If the imports in the next step fail with `ModuleNotFoundError`, the wrong kernel is almost always the culprit: check the kernel name shown in the notebook's top-right corner.

Every code cell below runs in `oracle.ipynb` unless it says otherwise.

---

### Step 2: Hello World

Load your `.env`, initialize the OpenAI client, and confirm the API answers:

```python
from dotenv import load_dotenv
import os
import openai

load_dotenv()

client = openai.OpenAI(
    api_key=os.environ["STANFORD_API_KEY"],
    base_url="https://aiapi-prod.stanford.edu/v1",
)

completion = client.chat.completions.create(
    model="gemini-2.5-flash-lite",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Say hello world!"}
    ]
)

print(completion.choices[0].message.content)
```

If you see a response, the API is working.

---

### Step 3: Load and Inspect a SEC Filing

A sample SEC Form 3 filing is included in your course repo:

```bash
ls ~/gsb-research-computing-ai-skills/data/sec_filings/
```

You should see five `.txt` files, one per company. Load one in `oracle.ipynb` and take a look:

```python
with open("../data/sec_filings/Cheniere_Energy_Inc.txt", "r") as f:
    filing_text = f.read()

print(filing_text[:2000])   # preview the first 2000 characters
```

SEC Form 3 filings report an insider's financial interest in a company: their name, role, and any shares held. The format is dense and not consistently structured. This is where the Oracle earns its keep.

---

### Step 4: Extract Information with the API

Now ask the model to pull out the key fields:

```python
response = client.chat.completions.create(
    model="gemini-2.5-flash-lite",
    messages=[
        {
            "role": "system",
            "content": "You are a financial data extraction assistant. Extract information precisely and concisely."
        },
        {
            "role": "user",
            "content": f"""From this SEC Form 3 filing, extract:
1. The insider's full name
2. Their role/relationship to the issuer (e.g. Director, Officer, 10% Owner)

Reply with only: NAME | ROLE

Filing:
{filing_text[:4000]}"""
        }
    ]
)

print(response.choices[0].message.content)
```

{: .note }
> 💡 The `[:4000]` slice limits how much text you send, since models have context limits. For now we stay within budget; Day 3 will scale this to hundreds of filings.

Experiment: try changing the system prompt. What happens if you ask for more fields? What if the prompt is vague?

---

### Step 5: From Notebook to Script

A notebook is great for exploration. Once the logic works, move it to a standalone script, the form you'll actually schedule and run on the cluster.

Three things should change when code leaves the notebook.

**How it reports progress.** In a notebook you watch cell output live. A script often runs unattended (in the background, or as a cluster job whose output you read afterward), so instead of scattering `print()` calls for status, use Python's built-in **`logging`** library. It stamps each message with a timestamp and a severity level, and you can turn it up or down without rewriting the rest of your code.

Point it at **two destinations at once**: your screen, so you can watch, and a **log file**, so you don't have to. The file handler *appends*, so every run adds to the bottom of the same file instead of erasing the last one. After a morning of edits and reruns you have a timestamped history of every attempt, which is the record you go back to when a result looks wrong and you need to know what you actually ran.

**Where it puts the answer.** A notebook keeps your result on screen in the cell output. A script's terminal output scrolls away the moment you close the window, and a cluster job has no screen at all. So the script has to **write its result to a file**. That file is the actual product of the run: the thing you can reopen tomorrow, hand to a collaborator, or feed into the next step of a pipeline.

**What it's pointed at.** In the notebook the filename sits wherever you happened to type it. In a script, anything you expect to change between runs belongs in a **constant at the top**, where you can find it without reading the whole file. Here that's `FILING`, and naming the output file after it means two runs on two filings leave two results instead of one overwriting the other.

In `oracle.ipynb`, consolidate the working code into one cell, now with logging:

```python
import logging
import os
import openai
from dotenv import load_dotenv

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    handlers=[
        logging.FileHandler("form3_test.log"),   # appends, so runs accumulate
        logging.StreamHandler(),                 # and still shows on screen
    ],
)
logger = logging.getLogger(__name__)

load_dotenv()

FILING = "Cheniere_Energy_Inc"      # the one thing you'll change between runs

client = openai.OpenAI(
    api_key=os.environ["STANFORD_API_KEY"],
    base_url="https://aiapi-prod.stanford.edu/v1",
)

logger.info("Reading filing")
with open(f"../data/sec_filings/{FILING}.txt", "r") as f:
    filing_text = f.read()

logger.info("Sending %d characters to the model", len(filing_text[:4000]))
response = client.chat.completions.create(
    model="gemini-2.5-flash-lite",
    messages=[
        {"role": "system", "content": "You are a financial data extraction assistant. Extract information precisely and concisely."},
        {"role": "user", "content": f"Extract the insider's name and role. Reply with: NAME | ROLE\n\n{filing_text[:4000]}"}
    ]
)
logger.info("Model responded")

answer = response.choices[0].message.content

output_path = f"form3_output_{FILING}.txt"     # output named after the input
with open(output_path, "w") as f:
    f.write(answer)
logger.info("Wrote %s", output_path)

print(answer)
```

{: .note }
> 💡 Notice the three-way split. **`logging` is for diagnostics**: what the program is doing and when, stamped with a timestamp and a level (`INFO`, `WARNING`, `ERROR`), now going to both your screen and `form3_test.log`. **`form3_output_*.txt` is for the result**, the durable output that outlives the run. **`print` is a convenience**, so you can see the answer while you're standing there watching. Drop the `print` and the script still works; drop the file write and the run leaves nothing behind. On Day 3, when these scripts run as cluster jobs, the logs are what you read to see what happened, and the result files are what you collect.
>
> Two different kinds of output, two different lifetimes. Results are data you keep and commit. Logs are a diary of the process, useful for weeks and then disposable, which is why `*.log` normally belongs in `.gitignore` rather than in your repo.

Copy this into a new file called `form3_test.py` in your `day2/` folder (in the Jupyter terminal: `cd ~/gsb-research-computing-ai-skills/day2 && touch form3_test.py`).

Now run it from the terminal. The notebook got `openai` and `pydantic` from the **Bootcamp 2026** kernel, but a fresh terminal knows nothing about that, so **activate the venv first**:

```bash
source ~/gsb-research-computing-ai-skills/.venv/bin/activate
cd ~/gsb-research-computing-ai-skills/day2
python form3_test.py
```

Your prompt should now start with `(.venv)`, the same signal you saw in [The Venv Forge](../venv-forge/). That prefix is your confirmation that `python` means *your* Python, the one with the packages installed.

{: .note }
> 💡 Skip the `source` line and you'll get `ModuleNotFoundError: No module named 'openai'`, which looks like a broken script but is really the wrong interpreter. Selecting a kernel and activating a venv are the same act in two different places: the notebook does it through the kernel menu, the terminal does it with `source`. Run `which python3` before and after activating to watch the path change.

You'll see the timestamped log lines and then the answer. Now confirm the result actually persisted:

```bash
cat form3_output_Cheniere_Energy_Inc.txt
```

The name and role are sitting in a file on disk, and they'll still be there after you close the terminal. Verify it matches what the notebook gave you. You now have a reproducible script you can schedule, share, or scale.

#### Quick exercise: point it at a different company

Cheniere Energy is one of five filings in that folder. See the rest:

```bash
ls ../data/sec_filings/
```

Pick another one and change the single line at the top of `form3_test.py`:

```python
FILING = "FLOWSERVE_CORP"
```

Then run it again and look at what's in your folder:

```bash
python form3_test.py
ls form3_output_*.txt
cat form3_output_FLOWSERVE_CORP.txt
```

A different insider, a different role, and **both** output files are still there. Now read the log:

```bash
cat form3_test.log
```

Both runs are in it, in order, timestamped. Notice the `Sending N characters` line differs between them, because the two filings aren't the same length. That is the log doing its job: not just "it worked," but a record of *what* each run actually did.

{: .note }
> 💡 Two habits just paid off at once. Naming the output after the input meant the second run didn't overwrite the first, which is the difference between a pipeline that accumulates results and one that quietly destroys them. And hoisting `FILING` to the top turned "edit the script" into "change one value." Hold that thought: if swapping one filing is a single variable, then processing all five is a `for` loop around the same code. That is exactly the move you'll make on Day 3, at a scale where you would never edit by hand.

---

### Step 6: Validate with Pydantic

Your `form3_output_*.txt` files are real artifacts, but each one is still just a blob of text: `NAME | ROLE`, and nothing checks that the model actually gave you that shape. Split it on the wrong character, or get a chatty reply that opens with "Sure! Here's the extraction:", and your parsing quietly breaks. This step fixes that at both ends. Ask for **JSON** instead of freeform text, and validate it with **Pydantic**, which turns the reply into a typed Python object and rejects anything that doesn't match your schema.

Below is your Step 5 script with four additions folded in. Every new or modified line is marked **`# ✦ NEW`**. Everything unmarked is code you already wrote and already understand, so read the marked lines and skip the rest.

The four additions are:

1. **A schema** (`Form3Extraction`), your Python declaration of the fields you expect and their types.
2. **The schema in the prompt**, so the model knows what to call each field.
3. **`response_format`**, which constrains the reply to valid JSON as the model writes it.
4. **Validation**, which checks the finished reply and fails loudly if it doesn't match.

```python
import json                                              # ✦ NEW
import logging
import os
import openai
from dotenv import load_dotenv
from pydantic import BaseModel, ValidationError          # ✦ NEW
from typing import Optional                              # ✦ NEW

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    handlers=[
        logging.FileHandler("form3_test.log"),   # appends, so runs accumulate
        logging.StreamHandler(),                 # and still shows on screen
    ],
)
logger = logging.getLogger(__name__)

load_dotenv()

FILING = "Cheniere_Energy_Inc"

client = openai.OpenAI(
    api_key=os.environ["STANFORD_API_KEY"],
    base_url="https://aiapi-prod.stanford.edu/v1",
)


# ✦ NEW ─── 1. The schema: what a good answer looks like ──────────────
# Optional[...] = None marks a field the model may legitimately omit.
# Every other field is required, and its absence is an error.
class Form3Extraction(BaseModel):                        # ✦ NEW
    insider_name: str                                    # ✦ NEW
    role: str                                            # ✦ NEW
    issuer_name: str                                     # ✦ NEW
    transaction_date: Optional[str] = None               # ✦ NEW
    shares_acquired: Optional[int] = None                # ✦ NEW


logger.info("Reading filing")
with open(f"../data/sec_filings/{FILING}.txt", "r") as f:
    filing_text = f.read()

# ✦ NEW ─── 2. Pydantic describes itself, and you send that to the model ───
# Without this, the model never learns your field names and guesses
# "name" or "company" instead. This is what keeps both ends in sync.
schema = json.dumps(Form3Extraction.model_json_schema(), indent=2)   # ✦ NEW

logger.info("Sending %d characters to the model", len(filing_text[:4000]))
response = client.chat.completions.create(
    model="gemini-2.5-flash-lite",
    messages=[
        # ✦ NEW: the system prompt now carries the schema
        {"role": "system", "content": f"Extract the requested fields from this SEC Form 3 filing.\nReturn only valid JSON matching this schema:\n\n{schema}"},
        {"role": "user", "content": f"Extract from this filing:\n\n{filing_text[:4000]}"}
    ],
    # ✦ NEW ─── 3. Constrain generation itself to valid JSON ───────────
    response_format={"type": "json_object"},             # ✦ NEW
)
logger.info("Model responded")

raw = response.choices[0].message.content

# Save the raw reply FIRST, before anything can fail. If validation
# blows up two lines from now, this file is your evidence.
raw_path = f"form3_output_{FILING}.txt"    # same file as Step 5
with open(raw_path, "w") as f:
    f.write(raw)
logger.info("Wrote %s", raw_path)

# ✦ NEW ─── 4. Validate before you trust it ───────────────────────────
# This is the line that turns a hopeful string into a checked object.
try:                                                     # ✦ NEW
    data = Form3Extraction.model_validate_json(raw)      # ✦ NEW
except ValidationError as e:                             # ✦ NEW
    logger.error("Model output failed validation: %s", e)  # ✦ NEW
    raise                                                # ✦ NEW

logger.info("Validated extraction for issuer: %s", data.issuer_name)   # ✦ NEW

json_path = f"form3_extraction_{FILING}.json"            # ✦ NEW
with open(json_path, "w") as f:                          # ✦ NEW
    f.write(data.model_dump_json(indent=2))              # ✦ NEW
logger.info("Wrote %s", json_path)                       # ✦ NEW

print(data.model_dump_json(indent=2))                    # ✦ NEW
```

Notice what did **not** change: the logging setup and its log file, the client, the `FILING` constant, reading the file, the text write, the output-naming habit. The scaffolding you built in Step 5 carried straight over, and `form3_test.log` keeps appending, so Step 6's runs land in the same history as Step 5's. What you added is a known shape to ask for and a check that the answer matches it.

**Why the script now writes two files.** Every run leaves both `form3_output_{FILING}.txt`, the raw reply exactly as the model sent it, and `form3_extraction_{FILING}.json`, the validated object. They usually look nearly identical, and keeping both anyway is the point:

- **The raw file is your evidence.** It's written *before* validation, so it exists even on the runs that crash. When a `ValidationError` fires, you don't have to re-run (and re-pay for) the call to find out what the model actually said. You open the file and look. Most "the model returned garbage" mysteries turn out to be one stray character, visible in two seconds if you kept the raw reply.
- **The JSON file is your data.** It's what survived the check, normalized to your types: `shares_acquired` is a real integer, absent fields are explicit `null`s. This is the file downstream code reads.
- **Together they're an audit trail.** Six months from now, "what did the model return, and what did we keep?" is answerable from disk rather than from memory. That's the difference between a pipeline a colleague can check and one they have to take on faith.

This is the finished script, so put it in `form3_test.py`, replacing what's there, and run it from the terminal:

```bash
source ~/gsb-research-computing-ai-skills/.venv/bin/activate   # if not already active
cd ~/gsb-research-computing-ai-skills/day2
python form3_test.py
ls form3_*                                       # both artifacts, raw and validated
cat form3_extraction_Cheniere_Energy_Inc.json
```

Same naming habit as Step 5: the output carries the input's name, so you can work through all five filings without one clobbering the next.

<details markdown="1">
<summary>🔬 In the weeds: how the model is actually constrained (click to reveal)</summary>

**`response_format` and Pydantic are two different defenses, at two different moments.** It's tempting to think Pydantic is somehow steering the model. It isn't.

**`response_format={"type": "json_object"}` runs on the server, while the model is still writing.** A model generates one token at a time, choosing from a probability distribution over its whole vocabulary. JSON mode *masks* that distribution: any token that would break JSON syntax has its probability forced to zero, so the model literally cannot produce a stray "Sure, here you go!" or a trailing comma. That's why you no longer need to defend against chatty preambles. But notice what it does **not** do: it enforces valid JSON, not *your* JSON. `{"name": "...", "title": "..."}` is perfectly valid JSON and would sail straight through.

**Pydantic runs in your own Python process, after the response has fully arrived.** It never touches generation, and the model has no idea your `Form3Extraction` class exists. `model_validate_json` takes the finished string and checks it against your field names and types, raising `ValidationError` if `insider_name` is missing or `shares_acquired` came back as `"none"` instead of a number.

That leaves a gap between the two, and the `schema` variable is what closes it. The model only knows to call the field `insider_name` because you *told* it, in the prompt. Sending `Form3Extraction.model_json_schema()` means your Pydantic class defines the contract in one place: it instructs the model up front, then audits the reply afterward. Rename a field once and both ends stay in sync.

**What's actually on the other end of that `base_url`.** The Stanford gateway is a **LiteLLM** proxy. LiteLLM is an open-source router that presents a single OpenAI-compatible API and translates each incoming request into the native format of whichever provider really serves that model, then translates the reply back. That is the machinery behind the Key Vault's one-client-many-services diagram, and behind the models list you pulled in the side quest: Gemini, Claude, and the rest are all reachable through one `base_url` because something in the middle is doing the format translation for you.

The catch is that a proxy can only pass along what the model underneath actually supports, so `response_format` is a request whose enforcement depends on the model behind the name. On this gateway, `{"type": "json_object"}` with `gemini-2.5-flash-lite` does hold: the replies come back as bare, parseable JSON.

A stronger option exists, `{"type": "json_schema"}`, which constrains decoding against your schema itself so the field names are masked into place rather than merely requested. It takes a **nested payload**, not just a type string:

```python
response_format={
    "type": "json_schema",
    "json_schema": {
        "name": "form3_extraction",
        "schema": Form3Extraction.model_json_schema(),
    },
}
```

Get that shape wrong and the failure is quiet rather than loud. Sending a bare `{"type": "json_schema"}` with no schema attached gives the gateway nothing to constrain against, the request degrades to ordinary unconstrained generation, and the model reverts to its default habit of wrapping the answer in a Markdown code fence (three backticks, then `json`). You still get a `200 OK`, and the breakage surfaces one line later as a confusing Pydantic error:

```text
Invalid JSON: expected value at line 1 column 1
  [type=json_invalid, input_value='```json\n{\n  "insider_n...']
```

Read that message closely: the JSON *inside* the fence is perfectly good and the field names are right. The three backticks in front of it are the entire problem. Whenever a validation error quotes an `input_value` that starts with backticks, the constraint layer isn't doing what you assumed it was.

**Which is exactly why you still validate.** The constraint layer is the part that changes when you swap `model="gemini-2.5-flash-lite"` for something else, or when you point `base_url` at a local model on Day 4. Pydantic is the layer that behaves identically no matter who is on the other end. Prompt for the shape you want, ask for whatever constraint the model offers, and then check the result yourself regardless.

</details>

<label class="quest-check"><input type="checkbox" data-room="d2-oracles-chamber" data-key="main"> Main Quest complete</label>

---

## 📦 Side Quests

{: .note }
> Finished early? Try any of these.

Your `client` talks to more than one endpoint. Each of these is a different door on the same Stanford gateway (your `base_url` never changes), so with the client already configured, they just work.

**Side quest: List the Available Models**

Hit the models endpoint (`GET /v1/models`) to see exactly which model ids the gateway accepts. This is the menu for every other call.

```python
for m in client.models.list().data:
    print(m.id)
```

Look for `text-embedding-ada-002` and `imagen-4.0-generate-001` in the list; those are the ids the next two quests use.

<label class="quest-check"><input type="checkbox" data-room="d2-oracles-chamber" data-key="side1"> I listed the available models</label>

**Side quest: Turn Text into an Embedding**

An embedding turns text into a vector of numbers that captures its meaning, the foundation of semantic search and clustering. Call the embeddings endpoint (`POST /v1/embeddings`):

```python
resp = client.embeddings.create(
    model="text-embedding-ada-002",
    input="Insider files a Form 3 disclosure",
)
vector = resp.data[0].embedding
print(len(vector), "dimensions")
print(vector[:8])
```

<label class="quest-check"><input type="checkbox" data-room="d2-oracles-chamber" data-key="side2"> I generated an embedding vector</label>

**Side quest: Generate an Image**

The same gateway can create images. Call the image endpoint (`POST /v1/images/generations`):

```python
import base64
from IPython.display import Image, display

resp = client.images.generate(
    model="imagen-4.0-generate-001",
    prompt="A medieval alchemist's lab full of glowing potions, digital art",
)

img = resp.data[0]
if img.url:                       # some models return a link
    print(img.url)
else:                             # others (e.g. imagen) return base64
    display(Image(data=base64.b64decode(img.b64_json)))
```

{: .note }
> 💡 An images response carries the picture in one of two fields: `url` (a link to download) or `b64_json` (the image encoded inline as base64). A model fills in only one, so `resp.data[0].url` is `None` when the model returned base64. The code above checks for both.

<label class="quest-check"><input type="checkbox" data-room="d2-oracles-chamber" data-key="side3"> I generated an image</label>

**Side quest: Count Tokens and Calculate the Cost**

Every response reports how many tokens it used. Look at the `usage` field on one of your earlier chat responses:

```python
print(response.usage)
# CompletionUsage(prompt_tokens=..., completion_tokens=..., total_tokens=...)
```

Now look up your model's price on the <a href="https://uit.stanford.edu/service/ai-api-gateway/rates" target="_blank" rel="noopener noreferrer">AI API Gateway rates page</a> and work out what that single call cost:

```python
usage = response.usage

# From the rates page, in dollars per 1M tokens (fill in for your model):
input_price = 0.00
output_price = 0.00

cost = (usage.prompt_tokens * input_price + usage.completion_tokens * output_price) / 1_000_000
print(f"This call cost ${cost:.6f}")
```

Then multiply by 10,000 filings. That per-call number is small, but it is exactly what you budget against when you scale.

<label class="quest-check"><input type="checkbox" data-room="d2-oracles-chamber" data-key="side4"> I found the token usage and estimated the cost</label>

**Side quest: Pay for Thinking You Never See**

Some models on the gateway **reason** before they answer: they work the problem through internally, then write a reply. That hidden reasoning is generated text, so it's billed as output tokens, and most of these models never show it to you.

Ask three models the same small trick question and compare what you're charged:

```python
QUESTION = "A farmer has 17 sheep. All but 9 run away. How many sheep are left?"

for model in ["gemini-2.5-flash-lite", "o3-mini", "deepseek-r1"]:
    try:
        r = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": QUESTION}],
        )
        answer = (r.choices[0].message.content or "").strip()
        print(f"\n=== {model} ===")
        print("answer :", answer[:300])
        print("usage  :", r.usage)
    except Exception as e:
        print(f"\n=== {model} ===\n  unavailable: {e}")
```

All three get it right, in about the same number of words. Here's what they charged:

| Model | Prompt tokens | **Completion tokens** | `reasoning_tokens` reported |
|---|---|---|---|
| `gemini-2.5-flash-lite` | 21 | **37** | not reported |
| `o3-mini` | 26 | **112** | **64** |
| `deepseek-r1` | 25 | **688** | not reported |

Read that middle column, because it's the one you pay. Same question, same answer, and `deepseek-r1` billed **18× more output** than `gemini-2.5-flash-lite` for two sentences.

The two reasoning models expose that differently, and both cases are worth seeing:

- **`o3-mini` tells you.** Its `completion_tokens_details` reports `reasoning_tokens=64`, so of the 112 output tokens you were billed for, **57% was thinking you never saw**.
- **`deepseek-r1` doesn't.** It returns `completion_tokens_details=None`, so there's no breakdown at all. The only evidence is the size of the gap: 688 output tokens for a reply you can read in five seconds.

That's why the instruction is to print the whole `usage` object instead of reaching for one field. Whether the split is reported is a property of the model and the gateway, not something to assume. `completion_tokens` is always there, and it's always what you're charged.

{: .note }
> 💡 Not every id is guaranteed to be enabled, which is why the loop catches errors instead of crashing. Run the *List the Available Models* quest above to see what your key can actually reach, and swap in any reasoning model you find (`o1`, or a `gpt-5` variant).

Now price it. Put each model's rate from the rates page into the cost formula from the previous quest and work out the real cost of each of those three answers. The cheapest model is not always the cheapest *call*, and on a reasoning model the length of the reply tells you nothing about the bill.

<label class="quest-check"><input type="checkbox" data-room="d2-oracles-chamber" data-key="side5"> I compared token usage across a plain and a reasoning model</label>

---

## 🧠 Skills Learned

- The OpenAI-compatible API takes a list of messages with `role` (system/user/assistant) and `content` (the text)
- The system prompt frames what the model is and what it should do; the user prompt is the actual data
- Context limits mean you need to trim large documents before sending; `[:4000]` is a quick safeguard
- `response_format={"type": "json_object"}` constrains the model *as it generates*, masking any token that would break JSON syntax; where it's honored, you no longer have to strip chatty preambles by hand
- Pydantic validates *after* the reply arrives; it turns unstructured LLM output into typed, validated Python objects, so if the model returns garbage you catch it before it silently corrupts your dataset
- Those two are separate defenses, and neither one tells the model your field names. Sending `model_json_schema()` in the prompt is what makes your Pydantic class the single source of truth at both ends
- A `logging.FileHandler` appends, so one log file accumulates a timestamped history across every run, which is what you read when a result looks wrong and you need to know what you actually ran
- A notebook is for exploration; a `.py` script is for reproducibility
