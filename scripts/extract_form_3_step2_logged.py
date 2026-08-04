"""Stage 2 of 3 — adds logging, and saves the result to a file.

New since stage 1:
    logging       timestamped progress, to your screen AND to form3_extract.log
    FILING        the one value you change between runs, hoisted to the top
    an output file named after its input, so two runs leave two results

Everything else is the same as stage 1. To see exactly what changed:
    diff scripts/extract_form_3_step1_basic.py scripts/extract_form_3_step2_logged.py

Run it from the repo root:
    python3 scripts/extract_form_3_step2_logged.py
"""
import logging
import os

from dotenv import load_dotenv
from openai import OpenAI

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    handlers=[
        logging.FileHandler("form3_extract.log"),   # appends, so runs accumulate
        logging.StreamHandler(),                    # and still shows on screen
    ],
)
logger = logging.getLogger(__name__)

load_dotenv()

FILING = "Cheniere_Energy_Inc"    # the one thing you change between runs
MODEL = "gemini-2.5-flash-lite"
RESULTS_DIR = "results"

client = OpenAI(
    base_url="https://aiapi-prod.stanford.edu/v1",
    api_key=os.getenv("STANFORD_API_KEY"),
)

logger.info("Reading filing %s", FILING)
with open(f"data/sec_filings/{FILING}.txt") as f:
    filing_text = f.read()

logger.info("Sending %d characters to %s", len(filing_text[:4000]), MODEL)
response = client.chat.completions.create(
    model=MODEL,
    messages=[
        {"role": "system", "content": "You extract data from SEC filings. Be precise and concise."},
        {"role": "user", "content": f"Extract the insider's name and role.\nReply with only: NAME | ROLE\n\n{filing_text[:4000]}"},
    ],
)
logger.info("Model responded")

answer = response.choices[0].message.content

os.makedirs(RESULTS_DIR, exist_ok=True)
output_path = f"{RESULTS_DIR}/form3_{FILING}.txt"    # output named after the input
with open(output_path, "w") as f:
    f.write(answer)
logger.info("Wrote %s", output_path)

print(answer)
