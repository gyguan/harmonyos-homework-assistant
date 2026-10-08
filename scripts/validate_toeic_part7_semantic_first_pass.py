#!/usr/bin/env python3
"""Content-bound AI first-pass editorial ledger for the 71 legacy P7 items.

This gate proves that the recorded editorial analysis applies to exactly the
same question/version/options/passage. It does NOT prove the editorial judgement
correct or that an independent human/ETS reviewer certified the source.
"""
from __future__ import annotations

from collections import Counter
from copy import deepcopy
import hashlib
import json
from pathlib import Path

from validate_toeic_question_quality import collect
from validate_toeic_evidence_provenance import triage

ROOT = Path(__file__).resolve().parents[1]
LEDGER_PATH = ROOT / "docs/product/toeic-issue478-part7-semantic-first-pass-71.json"


def question_snapshot(question) -> dict:
    return {
        "passage": question.passage,
        "stem": question.stem,
        "choices": question.choices,
        "answer": question.answer,
        "explanation": question.explanation,
        "evidence": question.evidence,
    }


def snapshot_sha256(snapshot: dict) -> str:
    raw = json.dumps(snapshot, sort_keys=True, ensure_ascii=False,
                     separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def verify_item(item: dict, question) -> None:
    question_id = item["assetId"]
    if question_id != question.id:
        raise AssertionError(f"{question_id}: mismatched review asset")
    if item["sourceFile"] != question.source + ".ets":
        raise AssertionError(f"{question_id}: source file mismatch")
    if item["reviewedVersion"] != question.version:
        raise AssertionError(f"{question_id}: review refers to an older content version")
    snapshot = question_snapshot(question)
    if item["questionSnapshot"] != snapshot:
        raise AssertionError(f"{question_id}: question changed since first-pass review")
    if item["snapshotSha256"] != snapshot_sha256(snapshot):
        raise AssertionError(f"{question_id}: review SHA-256 no longer matches")
    if item.get("sourceAnchor", "") not in question.passage:
        raise AssertionError(f"{question_id}: source anchor is not in the document")
    if item.get("reviewOutcome") != "AI_FIRST_PASS" or item.get("isExpertCertified") is not False:
        raise AssertionError(f"{question_id}: forbidden or misleading editorial status")
    if len(item.get("correctBasis", "").strip()) < 8:
        raise AssertionError(f"{question_id}: answer rationale not captured")
    exclusions = item.get("distractorReasons")
    if not isinstance(exclusions, list) or len(exclusions) != 3:
        raise AssertionError(f"{question_id}: three distractors need exclusion reasons")
    if any(not isinstance(reason, str) or len(reason.strip()) < 7 for reason in exclusions):
        raise AssertionError(f"{question_id}: empty or token distractor review")
    if len(snapshot["choices"]) != 4 or snapshot["answer"] not in range(4):
        raise AssertionError(f"{question_id}: expected four answer choices")


def validate() -> None:
    data = json.loads(LEDGER_PATH.read_text(encoding="utf-8"))
    if data.get("notIndependentExpertCertification") is not True:
        raise AssertionError("cannot represent AI screening as expert certification")
    legacy, _ = collect()
    by_id = {q.id: q for q in legacy}
    candidates = {item["assetId"] for item in triage()["needsIndependentSemanticReview"]}
    records = data["items"]
    reviewed = [item["assetId"] for item in records]
    if len(records) != 71 or len(set(reviewed)) != 71 or set(reviewed) != candidates:
        raise AssertionError("71 nonverbatim legacy P7 items must be accounted for once")
    for entry in records:
        verify_item(entry, by_id[entry["assetId"]])

    # Negative-control: a changed answer index must fail without modifying
    # the saved ledger or shipping a test-only branch in production.
    negative = deepcopy(records[0])
    negative["questionSnapshot"]["answer"] = (
        negative["questionSnapshot"]["answer"] + 1) % 4
    try:
        verify_item(negative, by_id[negative["assetId"]])
    except AssertionError:
        pass
    else:
        raise AssertionError("content changed but stale review did not fail")

    print("TOEIC_ISSUE478_AI_FIRST_PASS_LEDGER_PASS "
          "items=71 distractor_exclusions=213 "
          "content_sha256_bound=71 expert_certification=NO "
          "new_mocks_and_vocab_covered=NO")


if __name__ == "__main__":
    validate()
