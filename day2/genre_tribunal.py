"""Day 2 Challenge: The Genre Tribunal.

Classifies each movie's genre with one model, checks the call with a second
independent model, and lets a line of code — not a model — decide which
verdicts need a human. See MENU -> PICK -> CHECK -> DECIDE -> RECORD.

Run it from day2/:
    python3 genre_tribunal.py
"""
import json
import logging
import os
from enum import Enum
from typing import Optional

import pandas as pd
from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel, ValidationError

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    handlers=[
        logging.FileHandler("../genre_tribunal.log"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)

load_dotenv("../.env")

CLASSIFIER_MODEL = "gemini-2.5-flash-lite"   # the apprentice: picks a genre
JUDGE_MODEL = "gpt-5-mini"                   # the master: a different model, checks it

DATA_PATH = "../data/top_rated_movies.csv"
RESULTS_DIR = "../results"
OUTPUT_PATH = f"{RESULTS_DIR}/genre_verdicts.json"
CERTAINTY_THRESHOLD = 70

client = OpenAI(
    base_url="https://aiapi-prod.stanford.edu/v1",
    api_key=os.getenv("STANFORD_API_KEY"),
)


class Genre(str, Enum):
    ACTION = "Action"
    ADVENTURE = "Adventure"
    ANIMATION = "Animation"
    COMEDY = "Comedy"
    CRIME = "Crime"
    DOCUMENTARY = "Documentary"
    DRAMA = "Drama"
    FAMILY = "Family"
    FANTASY = "Fantasy"
    HORROR = "Horror"
    MYSTERY = "Mystery"
    ROMANCE = "Romance"
    SCIENCE_FICTION = "Science Fiction"
    THRILLER = "Thriller"
    WAR = "War"
    WESTERN = "Western"
    OTHER = "Other"


GENRE_LIST = ", ".join(g.value for g in Genre)


class ClassifierReply(BaseModel):
    genre: Genre
    reason: str


class JudgeReply(BaseModel):
    agrees: bool
    certainty: int
    reason: str
    suggested_genre: Optional[Genre] = None


def classify(title: str, overview: str) -> ClassifierReply:
    """The apprentice: picks one genre from the menu and says why."""
    response = client.chat.completions.create(
        model=CLASSIFIER_MODEL,
        response_format={"type": "json_object"},
        messages=[
            {
                "role": "system",
                "content": (
                    "You classify movies into exactly one genre from a fixed list. "
                    f"Choose from: {GENRE_LIST}. Use Other only for genuine misfits. "
                    'Reply with JSON matching this schema: '
                    '{"genre": "<one of the list>", "reason": "<one sentence, max 25 words>"}'
                ),
            },
            {
                "role": "user",
                "content": f"Title: {title}\nOverview: {overview}",
            },
        ],
    )
    raw = response.choices[0].message.content
    return ClassifierReply.model_validate_json(raw)


def judge(title: str, overview: str, predicted_genre: Genre) -> JudgeReply:
    """The master: a second opinion, blind to the apprentice's reason."""
    response = client.chat.completions.create(
        model=JUDGE_MODEL,
        response_format={"type": "json_object"},
        messages=[
            {
                "role": "system",
                "content": (
                    "You are an independent second opinion checking a genre classification. "
                    f"Valid genres are: {GENRE_LIST}. "
                    "You are not told why the first genre was picked. "
                    "Say whether you agree, how certain you are (0-100), your own one-sentence "
                    "reason, and — only if you disagree — the genre you would suggest instead. "
                    'Reply with JSON matching this schema: '
                    '{"agrees": <bool>, "certainty": <int 0-100>, "reason": "<one sentence>", '
                    '"suggested_genre": "<one of the list, or null>"}'
                ),
            },
            {
                "role": "user",
                "content": (
                    f"Title: {title}\nOverview: {overview}\n\n"
                    f"Predicted genre: {predicted_genre.value}\nDo you agree?"
                ),
            },
        ],
    )
    raw = response.choices[0].message.content
    return JudgeReply.model_validate_json(raw)


def main():
    os.makedirs(RESULTS_DIR, exist_ok=True)

    df = pd.read_csv(DATA_PATH).head(10)
    verdicts = []

    for row in df.itertuples():
        logger.info("Classifying %s (id=%s)", row.title, row.id)
        try:
            classification = classify(row.title, row.overview)
        except ValidationError as e:
            logger.error("Classifier output failed validation for %s: %s", row.title, e)
            raise

        try:
            verdict = judge(row.title, row.overview, classification.genre)
        except ValidationError as e:
            logger.error("Judge output failed validation for %s: %s", row.title, e)
            raise

        needs_human_review = (not verdict.agrees) or (verdict.certainty < CERTAINTY_THRESHOLD)

        if needs_human_review:
            logger.warning(
                "FLAGGED %s: agrees=%s certainty=%d predicted=%s suggested=%s",
                row.title, verdict.agrees, verdict.certainty,
                classification.genre.value,
                verdict.suggested_genre.value if verdict.suggested_genre else None,
            )
        else:
            logger.info(
                "OK %s: agrees=%s certainty=%d predicted=%s",
                row.title, verdict.agrees, verdict.certainty, classification.genre.value,
            )

        verdicts.append({
            "id": int(row.id),
            "title": row.title,
            "predicted_genre": classification.genre.value,
            "classifier_reason": classification.reason,
            "agrees": verdict.agrees,
            "certainty": verdict.certainty,
            "judge_reason": verdict.reason,
            "suggested_genre": verdict.suggested_genre.value if verdict.suggested_genre else None,
            "needs_human_review": needs_human_review,
            "classifier_model": CLASSIFIER_MODEL,
            "judge_model": JUDGE_MODEL,
        })

    with open(OUTPUT_PATH, "w") as f:
        json.dump(verdicts, f, indent=2)
    logger.info("Wrote %s", OUTPUT_PATH)

    n = len(verdicts)
    agreed = sum(1 for v in verdicts if v["agrees"])
    flagged = sum(1 for v in verdicts if v["needs_human_review"])
    certainties = sorted(v["certainty"] for v in verdicts)
    median = certainties[len(certainties) // 2]

    print()
    print(f"agreement rate ........  {agreed}/{n}  ({round(100 * agreed / n)}%)")
    print(f"certainty  min/med/max   {certainties[0]} / {median} / {certainties[-1]}")
    print(f"flagged for review ....  {flagged}/{n}")


if __name__ == "__main__":
    main()
