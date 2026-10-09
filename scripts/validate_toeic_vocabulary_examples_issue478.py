#!/usr/bin/env python3
"""Issue #478: fail closed if any of 300 published TOEIC words lacks an example.

This is a deterministic coverage/asset-binding gate, NOT dictionary/semantic
certification. Sentence wording still requires editorial review.
"""
from __future__ import annotations

import ast
from pathlib import Path
import re

from validate_toeic_question_quality import fields, literals_after

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"
SOURCE_NAMES = [
    "PresetToeicContent.ets", "ToeicWeekOneContent.ets",
    "ToeicVocabularyExpansion.ets",
] + [f"ToeicVocabularyBatch{part}.ets" for part in
     ("Two", "Three", "Four", "Five", "Six", "Seven")]
CATALOG = CONTENT / "ToeicVocabularyExampleCatalog.ets"


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"TOEIC_ISSUE478_VOCAB_EXAMPLE_FAIL: {message}")


def get_rows() -> dict[str, tuple[str, str, str]]:
    result: dict[str, tuple[str, str, str]] = {}
    for name in SOURCE_NAMES:
        source = (CONTENT / name).read_text(encoding="utf-8")
        for raw in literals_after(source, "new ToeicVocabularyItem("):
            parts = fields(raw)
            item_id, headword, meaning = (ast.literal_eval(parts[i]) for i in (0, 1, 3))
            require(re.fullmatch(r"V-\d{3}", item_id) is not None, f"unexpected ID: {item_id}")
            require(item_id not in result, f"duplicate original word: {item_id}")
            if len(parts) > 11:
                example = ast.literal_eval(parts[11])
            else:
                example = ""
            require(isinstance(example, str), f"{item_id}: invalid example type")
            require(bool(headword) and bool(meaning), f"{item_id}: missing headword/meaning")
            result[item_id] = (headword, meaning, example)
    return result


def get_supplement() -> dict[str, str]:
    source = CATALOG.read_text(encoding="utf-8")
    result: dict[str, str] = {}
    for raw in literals_after(source, "new ToeicVocabularyExample("):
        parts = fields(raw)
        require(len(parts) == 2, f"malformed example constructor: {raw[:60]}")
        item_id, sentence = (ast.literal_eval(part) for part in parts)
        require(item_id not in result, f"duplicate supplemental example: {item_id}")
        result[item_id] = sentence
    return result


def check(rows: dict[str, tuple[str, str, str]], extras: dict[str, str]) -> None:
    all_ids = {f"V-{i:03d}" for i in range(1, 301)}
    legacy_ids = {f"V-{i:03d}" for i in range(1, 91)}
    require(set(rows) == all_ids, f"original vocabulary coverage: {len(rows)}/300")
    require(set(extras) == legacy_ids, f"legacy example coverage: {len(extras)}/90")
    for item_id, (word, _, original_example) in rows.items():
        sentence = original_example or extras.get(item_id, "")
        require(bool(sentence.strip()), f"{item_id}: no learning example")
        require(len(sentence) >= 32 and len(sentence) <= 250,
                f"{item_id}: example sentence unusually short/long")
        require(sentence[-1] in ".!?", f"{item_id}: example lacks sentence ending")
        require(re.search(r"(?i)(?<![a-z])" + re.escape(word) + r"(?![a-z])", sentence) is not None,
                f"{item_id}: example does not contain its headword {word}")
        if item_id in legacy_ids:
            require(original_example == "", f"{item_id}: original baseline was unexpectedly modified")
        else:
            require(item_id not in extras, f"{item_id}: do not override already published example")
    preset = (CONTENT / "PresetToeicContent.ets").read_text(encoding="utf-8")
    require(
        "ToeicPronunciationCatalog.apply(ToeicVocabularyExampleCatalog.apply(base.concat(" in preset
        and "ToeicVocabularyBatchSeven.items())));" in preset,
        "legacy enrichment is not hooked into the runtime vocabulary",
    )
    ui = (ROOT / "entry/src/main/ets/toeic/ui/ToeicHomePage.ets").read_text(encoding="utf-8")
    require("if (item.exampleSentence.length>0)" in ui and
            "Text('例句：'+item.exampleSentence)" in ui,
            "vocabulary examples are not visible in the vocabulary card")


def validate() -> None:
    rows, extras = get_rows(), get_supplement()
    check(rows, extras)
    # A deliberately missing historical example MUST close the gate.
    corrupted = dict(extras)
    corrupted.pop("V-001")
    try:
        check(rows, corrupted)
    except SystemExit as error:
        require("legacy example coverage" in str(error), "negative test failed for wrong reason")
    else:
        raise SystemExit("TOEIC_ISSUE478_VOCAB_EXAMPLE_FAIL: missing example incorrectly passed")
    print("TOEIC_ISSUE478_VOCAB_EXAMPLE_PASS all=300 supplement=90 existing=210 negative_missing=PASS semantic_certified=NO")


if __name__ == "__main__":
    validate()
