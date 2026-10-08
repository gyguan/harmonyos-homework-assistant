#!/usr/bin/env python3
"""Issue #478: independently trace AI first-pass notes for 65 shared P7 questions.

The legacy published source/group hash remains protected by the existing
editorial approval validation; this does not grant human or ETS certification.
"""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path

from validate_toeic_question_quality import collect
from validate_toeic_evidence_provenance import triage, parse_group_sources

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "docs/product/toeic-issue478-shared-part7-first-pass-65.json"
APPROVALS = ROOT / "docs/product/toeic-editorial-approvals.json"
AI_EVIDENCE = ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json"


def snapshot(question) -> dict:
    return {
        "id": question.id,
        "sourceFile": question.source + ".ets",
        "groupId": question.group,
        "version": question.version,
        "stem": question.stem,
        "options": question.choices,
        "answerIndex": question.answer,
        "explanation": question.explanation,
        "evidence": question.evidence,
    }


def check_record(note: dict, question, groups: dict,
                 approvals: dict, ai_evidence: dict) -> None:
    qid = note["assetId"]
    if note["questionSnapshot"] != snapshot(question):
        raise AssertionError(f"{qid}: stale question version or source snapshot")
    if note.get("reviewOutcome") != "AI_FIRST_PASS" or note.get("isExpertCertified") is not False:
        raise AssertionError(f"{qid}: AI notes must not masquerade as certified review")
    reasons = note.get("distractorReasons")
    if len(note.get("correctBasis", "").strip()) < 8:
        raise AssertionError(f"{qid}: missing correct-answer argument")
    if not isinstance(reasons, list) or len(reasons) != 3 or any(
            not isinstance(reason, str) or len(reason.strip()) < 5 for reason in reasons):
        raise AssertionError(f"{qid}: require three meaningful distractor exclusions")
    group = groups.get(question.group)
    if group is None or qid not in group["questionIds"]:
        raise AssertionError(f"{qid}: broken shared-source membership")
    if len(question.choices) != 4 or question.answer not in range(4):
        raise AssertionError(f"{qid}: wrong answer or number of options")
    digest = note["groupContentSha256"]
    approval = approvals.get("readingGroups", {}).get(question.group, {})
    ai = ai_evidence.get("readingGroups", {}).get(question.group, {})
    if (approval.get("contentSha256") != digest or ai.get("contentSha256") != digest or
            approval.get("reviewMode") != "AI_EDITORIAL" or
            ai.get("decision") != "PASS"):
        raise AssertionError(f"{qid}: stale or non-AI shared group editorial fingerprint")
    if not any(x.get("id") == qid and x.get("answerIndex") == question.answer
               for x in ai.get("questions", [])):
        raise AssertionError(f"{qid}: approved group's answer index differs from question")


def validate() -> None:
    ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
    approvals = json.loads(APPROVALS.read_text(encoding="utf-8"))
    ai_evidence = json.loads(AI_EVIDENCE.read_text(encoding="utf-8"))
    if ledger.get("reviewStatus") != "AI_FIRST_PASS":
        raise AssertionError("shared group ledger status must not imply human certification")
    legacy, _ = collect()
    by_id = {q.id: q for q in legacy}
    provenance = triage()
    required = {q["assetId"] for q in provenance["groupProvenance"]}
    groups = parse_group_sources()
    rows = ledger["items"]
    recorded = [r["assetId"] for r in rows]
    if len(rows) != 65 or len(set(recorded)) != 65 or set(recorded) != required:
        raise AssertionError("all 65 shared group questions need unique source-bound notes")
    if len({r["questionSnapshot"]["groupId"] for r in rows}) != 13:
        raise AssertionError("shared group review must cover all 13 released groups")
    for note in rows:
        check_record(note, by_id[note["assetId"]], groups, approvals, ai_evidence)

    # No silent re-use of the reviewed record after changing a version/answer.
    modified = deepcopy(rows[0])
    modified["questionSnapshot"]["answerIndex"] = (
        modified["questionSnapshot"]["answerIndex"] + 1) % 4
    try:
        check_record(modified, by_id[modified["assetId"]], groups, approvals, ai_evidence)
    except AssertionError:
        pass
    else:
        raise AssertionError("negative control accepted a stale published answer")

    delivery = by_id["R-P7-DELIVERY-01"]
    support = by_id["R-P7-SUPPORT-05"]
    assert delivery.version == 2 and "guarantees" in delivery.stem
    assert support.version == 2 and "after the service interruption began" in support.stem
    assert "SLA" not in support.stem
    print("TOEIC_ISSUE478_SHARED_P7_FIRST_PASS_PASS groups=13 questions=65 "
          "correct_reasons=65 wrong_option_reasons=195 "
          "version2_delivery=OK version2_support=OK "
          "independent_expert_certification=NO")


if __name__ == "__main__":
    validate()
