"""Stage 1 of 3 — the smallest thing that works.

Reads one SEC Form 3 filing, asks the model for the insider's name and role,
and prints the answer. That's it. Nothing here is written to disk.

What the next two stages add:
    Stage 2   logging, and saving the result to a file
    Stage 3   a Pydantic schema, so bad output fails loudly instead of quietly

Run it from the repo root:
    python3 scripts/extract_form_3_step1_basic.py
"""
import os

from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()   # reads .env from the repo root

FILING_PATH = "data/sec_filings/Cheniere_Energy_Inc.txt"
MODEL = "gemini-2.5-flash-lite"   # cheap and fast, which is what you want while experimenting

client = OpenAI(
    base_url="https://aiapi-prod.stanford.edu/v1",
    api_key=os.getenv("STANFORD_API_KEY"),
)

with open(FILING_PATH) as f:
    filing_text = f.read()

response = client.chat.completions.create(
    model=MODEL,
    messages=[
        {"role": "system", "content": "You extract data from SEC filings. Be precise and concise."},
        {"role": "user", "content": f"Extract the insider's name and role.\nReply with only: NAME | ROLE\n\n{filing_text[:4000]}"},
    ],
)

print(response.choices[0].message.content)
