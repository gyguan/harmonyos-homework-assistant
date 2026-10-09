#!/usr/bin/env python3
"""Issue #478: source-bound model-led first pass for 110 inline-verbatim P7 items.

This is NOT a claim of independent expert, human, or ETS validation.
"""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path

from validate_toeic_question_quality import collect

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "docs/product/toeic-issue478-inline-verbatim-first-pass-110.json"


def snapshot(q) -> dict:
    return {
        "passage": q.passage,
        "stem": q.stem,
        "choices": q.choices,
        "answer": q.answer,
        "explanation": q.explanation,
        "evidence": q.evidence,
    }


def verify_item(entry: dict, q) -> None:
    key = entry["assetId"]
    if key != q.id or entry["sourceFile"] != q.source + ".ets":
        raise AssertionError(f"{key}: wrong source or ID")
    if entry["reviewedVersion"] != q.version:
        raise AssertionError(f"{key}: stale published content version")
    if entry["questionSnapshot"] != snapshot(q):
        raise AssertionError(f"{key}: reading article, stem, choices, answer or evidence changed")
    if entry["sourceAnchor"] != q.evidence or entry["sourceAnchor"] not in q.passage:
        raise AssertionError(f"{key}: source quotation no longer matches")
    if entry["isExpertCertified"] is not False:
        raise AssertionError(f"{key}: may not claim expert certification")
    if key == "R-M1-P7-094":
        if (entry["reviewOutcome"] != "AI_FLAGGED_AMBIGUITY" or
                entry.get("editorialFinding") !=
                "Unanchored 'next week' relative to October 4–8 closure; do not republish unchanged as a newly validated question." or
                len(entry.get("correctBasis", "").strip()) < 15):
            raise AssertionError(f"{key}: archived ambiguity must remain explicitly flagged")
    elif entry["reviewOutcome"] != "AI_FIRST_PASS" or entry.get("correctBasis") != q.explanation:
        raise AssertionError(f"{key}: unreviewed or changed explanation")
    reasons = entry.get("distractorReasons")
    if not isinstance(reasons, list) or len(reasons) != 3:
        raise AssertionError(f"{key}: each wrong choice must have an exclusion")
    if any(not isinstance(x, str) or len(x.strip()) < 4 for x in reasons):
        raise AssertionError(f"{key}: missing substantive wrong-choice reason")
    if len(q.choices) != 4 or q.answer not in range(4):
        raise AssertionError(f"{key}: invalid four-choice item")


def validate() -> None:
    data = json.loads(LEDGER.read_text(encoding="utf-8"))
    if data.get("reviewStatus") != "AI_FIRST_PASS_WITH_ONE_FLAGGED" or data.get("notExpertCertified") is not True:
        raise AssertionError("invalid or misleading editorial status")
    original, _ = collect()
    by_id = {q.id: q for q in original}
    expected = {
        q.id for q in original
        if q.part == "PART_7" and q.passage and q.evidence and q.evidence in q.passage
    }
    actual = [entry["assetId"] for entry in data["items"]]
    if len(expected) != 110 or len(actual) != 110 or len(set(actual)) != 110 or set(actual) != expected:
        raise AssertionError("all 110 original in-passage quote questions must be reviewed exactly once")
    for entry in data["items"]:
        verify_item(entry, by_id[entry["assetId"]])

    # A passing gate must not greenlight a saved review for changed option,
    # answer or version. Never mutate the shipping ledger in this regression.
    original_note = data["items"][0]
    altered = deepcopy(original_note)
    altered["questionSnapshot"]["choices"][0] += " (unreviewed)"
    try:
        verify_item(altered, by_id[altered["assetId"]])
    except AssertionError:
        pass
    else:
        raise AssertionError("negative control accepted a stale option")
    altered = deepcopy(original_note)
    altered["reviewedVersion"] += 1
    try:
        verify_item(altered, by_id[altered["assetId"]])
    except AssertionError:
        pass
    else:
        raise AssertionError("negative control accepted an unreviewed version")
    changed = by_id["R-M1-P7-094"]
    assert changed.version == 1 and changed.answer == 0
    assert changed.stem == "Why is the south entrance not recommended?"
    assert "Clients arriving next week" in changed.passage
    assert "Oct. 4–8" in changed.passage
    flagged = [e for e in data["items"] if e["reviewOutcome"] == "AI_FLAGGED_AMBIGUITY"]
    assert len(flagged) == 1 and flagged[0]["assetId"] == changed.id
    print("TOEIC_ISSUE478_INLINE_VERBATIM_FIRST_PASS_PASS originalP7=110 "
          "exclusion_notes=330 content_snapshot_bound=110 "
          "ai_first_pass_no_issue=109 flagged_archival_ambiguity=1 "
          "archived_question_version1_preserved=YES expert_certification=NO")


if __name__ == "__main__":
    validate()
