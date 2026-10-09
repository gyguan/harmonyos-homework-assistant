#!/usr/bin/env python3
"""Issue #478 P1 audit inventory. Does not fabricate semantic approvals.

Records exactly which original Part5/6 items and vocabulary words still
need independent second-pass review. Existing active mock first-pass reviews
are separate assets and MUST NOT be silently counted against these IDs.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from validate_toeic_question_quality import collect
from validate_toeic_vocabulary_examples_issue478 import get_rows
from validate_toeic_vocabulary_dictionary_issue478 import parse_batches
from validate_toeic_translation_coverage import collect_translations

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/product/toeic-issue478-p1-pending-inventory.json"

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="write deterministic machine-readable inventory")
    args = parser.parse_args()
    source, _ = collect()
    translations = collect_translations()
    questions = sorted((q for q in source if q.part in ("PART_5", "PART_6")), key=lambda q: q.id)
    assert len(questions) == 185, f"Expected 185 original P5/P6 items, got {len(questions)}"
    assert len(set(q.id for q in questions)) == 185, "Duplicate original Part5/6 IDs"
    words = get_rows()
    assert len(words) == 300 and set(words) == {f"V-{i:03d}" for i in range(1, 301)}
    batches = parse_batches()
    assert len(batches) == 180
    items = []
    for q in questions:
        if len(q.choices) != 4 or q.answer not in range(4):
            raise AssertionError(f"{q.id}: invalid options/answer")
        items.append({
            "assetId": q.id, "source": q.source + ".ets",
            "version": q.version, "part": q.part,
            "stem": q.stem, "options": q.choices,
            "correctIndex": q.answer,
            "existingExplanation": q.explanation, "existingEvidence": q.evidence,
            "hasChineseTranslation": q.id in translations,
            "contentReviewStatus": "NEED_INDEPENDENT_SECOND_PASS",
            "reviewRequired": ["source context", "one correct answer", "three distractor exclusions",
                "part-specific grammar/cohesion", "English-Chinese consistency", "version/source binding"],
        })
    word_items = []
    for id, (word, meaning, example) in sorted(words.items()):
        word_items.append({
            "assetId": id, "headword": word, "meaning": meaning,
            "example": example, "isBatchWordWithAIEditorialHash": id in batches,
            "contentReviewStatus": "NEED_DICTIONARY_BOUND_SECOND_PASS",
            "reviewRequired": ["part of speech and sense", "business usage",
                "collocation", "contextual paraphrase", "US IPA and pronunciation variants", "example grammar"],
        })
    result = {
        "issue": 478,
        "reviewScope": "original 185 Part5/Part6 and all 300 vocabulary entries",
        "attestation": "INVENTORY_ONLY_NOT_SEMANTIC_CERTIFICATION",
        "originalP5P6Count": len(items),
        "vocabularyCount": len(word_items),
        "originalP5P6": items,
        "vocabulary": word_items,
    }
    if args.write:
        OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("TOEIC_ISSUE478_P1_INVENTORY_PASS original_p5p6=185 vocabulary=300 semantic_approval=NO")

if __name__ == "__main__":
    main()
