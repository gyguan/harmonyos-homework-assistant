#!/usr/bin/env python3
"""Issue #478: contextual business-lexicon semantic corrections.

Covers exactly five audited content IDs with current exact fingerprints,
AI-only evidence, correct examples/paraphrases and negative corruption probes.
This is deterministic regression evidence, not a blanket expert review of all
300 vocabulary words or device TTS pronunciation.
"""
from __future__ import annotations

from copy import deepcopy
import json
import re

from export_toeic_review_pack import CONTENT, ROOT
from toeic_review_integrity import vocabulary_fingerprint
from validate_toeic_vocabulary_dictionary_issue478 import parse_batches
from validate_toeic_vocabulary_examples_issue478 import get_rows, get_supplement

APPROVALS = ROOT / "docs/product/toeic-editorial-approvals.json"
FIRST = ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json"
SECOND = ROOT / "docs/product/toeic-remaining-content-review-2026-10-08.json"

TARGETS = {
    "V-180": {
        "word": "margin", "pos": "n.",
        "collocations": ["profit margin"],
        "synonyms": ["difference between revenue and cost, often expressed as a percentage"],
        "example": "Higher shipping costs reduced the company's profit margin.",
    },
    "V-202": {
        "word": "troubleshoot", "pos": "v.",
        "collocations": ["troubleshoot a connection"],
        "synonyms": ["identify a fault and seek a solution"],
        "example": "The support engineer will troubleshoot the network connection.",
    },
    "V-207": {
        "word": "cancellation", "pos": "n.",
        "collocations": ["cancellation fee"],
        "synonyms": ["withdrawal of a booking"],
        "example": "The hotel charges a cancellation fee when guests cancel after the deadline.",
    },
    "V-214": {
        "word": "occupancy", "pos": "n.",
        "collocations": ["occupancy rate"],
        "synonyms": ["percentage of available hotel rooms occupied"],
        "example": "The hotel reported an occupancy rate of eighty percent.",
    },
    "V-297": {
        "word": "attendance", "pos": "n.",
        "collocations": ["attendance record"],
        "synonyms": ["number of people attending an event"],
        "example": "The conference organizer reported higher attendance this year.",
    },
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise AssertionError("TOEIC_ISSUE478_BUSINESS_CONTEXT_FAIL: " + message)


def check(rows: dict, ipa: dict, approvals: dict, first: dict, second: dict) -> None:
    require(len(rows) == 180, "all 180 source vocabulary items required")
    require(len(ipa) == 300, "300 pronunciation entries required")
    for key, expect in TARGETS.items():
        row = rows[key]
        for field in ("word", "pos", "collocations", "synonyms", "example"):
            require(row[field] == expect[field], f"{key}: reviewed {field} drift")
        require(row["status"] == "PUBLISHED", f"{key}: review status drift")
        require(ipa[key].startswith("/") and ipa[key].count("/") >= 2,
                f"{key}: missing IPA mapping")
        digest = vocabulary_fingerprint(row, ipa[key])
        approval = approvals["vocabulary"][key]
        require(approval["contentSha256"] == digest,
                f"{key}: approval is not linked to current source")
        require(approval["reviewer"] == "AI-GPT6" and
                approval["reviewMode"] == "AI_EDITORIAL" and
                approval["approvedAt"] == "2026-10-09",
                f"{key}: editorial review provenance must remain AI-only")
        first_row = first["vocabulary"][key]
        require(first_row["contentSha256"] == digest and
                first_row["updatedAt"] == "2026-10-09" and
                first_row["decision"] == "PASS",
                f"{key}: first AI review evidence mismatch")
        if key != "V-180":
            second_row = second["vocabulary"][key]
            require(second_row["contentSha256"] == digest and
                    second_row["decision"] == "PASS_AI_RECHECK" and
                    second_row["example"] == row["example"] and
                    second_row["synonyms"] == row["synonyms"],
                    f"{key}: second AI review evidence mismatch")

    # Explicit semantic boundaries: margin is not automatically a percentage,
    # hotel occupancy is a ratio of occupied to AVAILABLE rooms, and fees are
    # tied to cancellation itself rather than arbitrary booking edits.
    require("often expressed as a percentage" in rows["V-180"]["synonyms"][0],
            "V-180: do not equate an absolute profit amount with every margin")
    require("available hotel rooms occupied" in rows["V-214"]["synonyms"][0],
            "V-214: hotel occupancy denominator missing")
    require("cancel after the deadline" in rows["V-207"]["example"],
            "V-207: late-change wording falsely implies cancellations")



def check_effective_examples(extras: dict[str, str]) -> None:
    """Inspect the exact learning-card example catalog, not synthetic test data."""
    originals = get_rows()
    require(len(originals) == 300, "expected 300 real original words")
    require(len(extras) == 90, "expected 90 real supplemental examples")
    corrected = (
        "The hotel will charge a cancellation fee if guests cancel "
        "after the cancellation deadline."
    )
    require(extras.get("V-056") == corrected,
            "V-056: still teaches cancellation fees for arbitrary late changes")
    for item_id, (_, _, original_sentence) in originals.items():
        effective = original_sentence or extras.get(item_id, "")
        if "cancellation fee" in effective.lower():
            require("late changes" not in effective.lower(),
                    f"{item_id}: late changes incorrectly equated to cancellation")



def validate() -> None:
    rows = parse_batches()
    pronunciation = (CONTENT / "ToeicPronunciationCatalog.ets").read_text(
        encoding="utf-8")
    matches = re.findall(
        r"new ToeicPronunciationEntry\('(V-\d+)','([^']+)'", pronunciation)
    ipa = dict(matches)
    require(len(matches) == len(ipa) == 300, "duplicate or missing IPA")
    approvals = json.loads(APPROVALS.read_text(encoding="utf-8"))
    first = json.loads(FIRST.read_text(encoding="utf-8"))
    second = json.loads(SECOND.read_text(encoding="utf-8"))
    check(rows, ipa, approvals, first, second)
    examples = get_supplement()
    check_effective_examples(examples)
    for key, column, obsolete in (
        ("V-180", "synonyms", ["difference between revenue and cost"]),
        ("V-207", "example", "The hotel charges a cancellation fee for late changes."),
        ("V-214", "synonyms", ["room utilization"]),
        ("V-297", "synonyms", ["presence"]),
    ):
        corrupt = deepcopy(rows)
        corrupt[key][column] = obsolete
        try:
            check(corrupt, ipa, approvals, first, second)
        except AssertionError as ex:
            require(key in str(ex), f"{key}: negative check failed unexpectedly")
        else:
            raise AssertionError(
                f"TOEIC_ISSUE478_BUSINESS_CONTEXT_FAIL: obsolete {key} accepted")

    corrupted_examples = dict(examples)
    corrupted_examples["V-056"] = (
        "The hotel will charge a cancellation fee for late changes.")
    try:
        check_effective_examples(corrupted_examples)
    except AssertionError as ex:
        require("V-056" in str(ex),
                "real learner example negative check failed unexpectedly")
    else:
        raise AssertionError(
            "TOEIC_ISSUE478_BUSINESS_CONTEXT_FAIL: old V-056 example accepted")

    corrupted_review = deepcopy(approvals)
    corrupted_review["vocabulary"]["V-202"]["contentSha256"] = "0" * 64
    try:
        check(rows, ipa, corrupted_review, first, second)
    except AssertionError as ex:
        require("V-202" in str(ex), "stale review SHA not properly rejected")
    else:
        raise AssertionError(
            "TOEIC_ISSUE478_BUSINESS_CONTEXT_FAIL: forged hash accepted")

    print("TOEIC_ISSUE478_BUSINESS_CONTEXT_PASS source_batch_words=180 "
          "corrected_word_ids=6 corrected_examples=2 negative_checks=6 "
          "human_ETS_certification=NO")


if __name__ == "__main__":
    validate()
