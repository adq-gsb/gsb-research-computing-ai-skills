"""Write the demo's filing URLs, one per line, for the .slurm scripts to slice up.

Reads the same source as the Day 3 batch job — data/aws_links.csv — so the demos
process exactly what students processed yesterday, rather than the five sample
filings checked into data/sec_filings/.

    python .instructor/parallelization_demos/make_url_list.py <output_path>
"""

import os

# Same reason as extract_form_3_batch.py: this is an API-bound job, so don't let
# pandas' numeric libraries claim a thread per core on a shared node. Must be set
# before pandas is imported.
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("OMP_NUM_THREADS", "1")

import sys
from pathlib import Path

import pandas as pd

CSV_PATH = "data/aws_links.csv"

# How many filings every demo processes. Fixed so the four runs are comparable.
# Note the cost: this is 20 paid API calls per demo, so 80 for a full four-way
# comparison with a cleared results directory.
NUM_FILINGS = 20


def main():
    output_path = Path(sys.argv[1])

    df = pd.read_csv(CSV_PATH)
    # The first row is just the S3 folder URL, so keep only the .txt filings.
    urls = [u for u in df["urls"].dropna().tolist() if u.endswith(".txt")]
    urls = urls[:NUM_FILINGS]

    output_path.parent.mkdir(parents=True, exist_ok=True)
    # Every task of an array demo runs this against the same path, so write to a
    # private temp file and rename into place. os.replace is atomic on POSIX, so
    # a concurrent reader sees either the old list or the new one, never half.
    tmp_path = output_path.with_suffix(f".{os.getpid()}.tmp")
    tmp_path.write_text("\n".join(urls) + "\n")
    os.replace(tmp_path, output_path)

    print(f"Wrote {len(urls)} filing URLs to {output_path}")


if __name__ == "__main__":
    main()
