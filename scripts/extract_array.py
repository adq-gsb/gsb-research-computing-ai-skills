"""Extract SEC Form 3 filings assigned to a Slurm array task."""

import json
import os
import sys
import time
from pathlib import Path
from typing import List

# Set these before importing pandas so each array task stays within its CPU
# allocation instead of allowing BLAS to create one thread per core.
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("OMP_NUM_THREADS", "1")

import pandas as pd
import requests
from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel, field_validator


CSV_PATH = "data/aws_links.csv"
RESULTS_DIR = Path("results")
FILINGS_PER_TASK = 2
MODEL = "gemini-2.5-flash"
MAX_API_ATTEMPTS = 5


class Form3Filing(BaseModel):
    insider_name: str
    insider_role: List[str]
    company_name: str
    company_cik: str
    filing_date: str

    @field_validator("insider_name", mode="before")
    @classmethod
    def join_multiple_insiders(cls, value: object) -> object:
        """Keep the flat output schema when a filing names multiple insiders."""
        if isinstance(value, list):
            return "; ".join(str(name) for name in value)
        return value


SYSTEM_PROMPT = """
You are a data extraction agent for SEC Form 3 filings.

Extract the following fields:
- insider_name: The name of the insider (from reportingOwner or anywhere in the document).
- insider_role: A list of roles the insider holds (Director, Officer, 10% Owner, Other).
- company_name: The issuer's company name.
- company_cik: The CIK number of the issuer (from issuerCik or COMPANY DATA).
- filing_date: The filing date (prefer signatureDate or FILED AS OF DATE).

Return valid JSON matching the schema exactly.
Return a SINGLE JSON object, not a list. Do not wrap it in an array.
"""


def get_filings(task_id: int) -> list[str]:
    urls = pd.read_csv(CSV_PATH)["urls"].dropna()
    filings = [url for url in urls if url.endswith(".txt")]
    task_count = (len(filings) + FILINGS_PER_TASK - 1) // FILINGS_PER_TASK
    if not 1 <= task_id <= task_count:
        raise ValueError(f"task ID must be between 1 and {task_count}, got {task_id}")
    start = (task_id - 1) * FILINGS_PER_TASK
    return filings[start : start + FILINGS_PER_TASK]


def extract_filing(client: OpenAI, filing: str) -> None:
    name = filing.rsplit("/", 1)[-1].replace(".txt", ".json")
    output_path = RESULTS_DIR / name

    # Make reruns cheap: completed filings are never sent to the API again.
    if output_path.exists():
        print(f"{output_path} already exists; skipping")
        return

    print(f"Fetching {filing}")
    filing_response = requests.get(filing, timeout=60)
    filing_response.raise_for_status()

    for attempt in range(1, MAX_API_ATTEMPTS + 1):
        try:
            api_response = client.chat.completions.create(
                model=MODEL,
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": filing_response.text},
                ],
            )
            result = Form3Filing.model_validate_json(api_response.choices[0].message.content)
            RESULTS_DIR.mkdir(parents=True, exist_ok=True)
            with output_path.open("w") as output_file:
                json.dump(result.model_dump(), output_file, indent=2)
            print(f"Saved {output_path}")
            return
        except Exception:
            if attempt == MAX_API_ATTEMPTS:
                raise
            delay = 2 ** attempt
            print(f"Attempt {attempt} failed for {name}; retrying in {delay}s", file=sys.stderr)
            time.sleep(delay)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: python scripts/extract_array.py TASK_ID")
    task_id = int(sys.argv[1])
    filings = get_filings(task_id)
    load_dotenv()
    client = OpenAI(
        base_url="https://aiapi-prod.stanford.edu/v1",
        api_key=os.getenv("STANFORD_API_KEY"),
    )

    failures = []
    for filing in filings:
        try:
            extract_filing(client, filing)
        except Exception as error:
            failures.append((filing, error))
            print(f"Failed {filing}: {error}", file=sys.stderr)
    if failures:
        raise SystemExit(f"{len(failures)} filing(s) failed in task {task_id}")


if __name__ == "__main__":
    main()
