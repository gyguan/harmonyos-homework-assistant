#!/usr/bin/env python3
"""Issue #478: resolve article provenance before asking for semantic decisions.

The original 431 questions are NOT a full corpus of v2 mock derivatives.
A successful source-quote test is NOT a proof of a unique correct answer.
"""
from __future__ import annotations

import ast
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re

from validate_toeic_question_quality import (
    collect, fields, literals_after, remove_arkts_comments
)

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"
GROUP_FILES = (
    "ToeicExtraReadingContent",
    "ToeicExtraReadingBatchTwo",
    "ToeicExtraReadingBatchThree",
    "ToeicExtraReadingBatchFour",
    "ToeicExtraReadingBatchFive",
    "ToeicExtraReadingBatchSix",
)


def parse_group_sources() -> dict[str, dict]:
    """Read the actual shared passage blocks; never use question.passage alone."""
    groups: dict[str, dict] = {}
    for source in GROUP_FILES:
        raw_text = (CONTENT / (source + ".ets")).read_text(encoding="utf-8")
        for call in literals_after(remove_arkts_comments(raw_text), "new ToeicReadingGroup("):
            args = fields(call)
            if len(args) < 3 or args[0][:1] not in ("'", '"'):
                continue
            group_id, question_ids, docs = (ast.literal_eval(x) for x in args[:3])
            if group_id in groups:
                raise AssertionError(f"duplicate source group {group_id}")
            if not docs or not question_ids or len(set(question_ids)) != len(question_ids):
                raise AssertionError(f"invalid source group {group_id}")
            groups[group_id] = {
                "file": source,
                "questionIds": question_ids,
                "documents": docs,
            }
    return groups


def digest(question) -> str:
    fields_to_hash = [
        question.id, question.version, question.part, question.passage,
        question.stem, question.choices, question.answer,
        question.explanation, question.evidence, question.group,
    ]
    data = json.dumps(fields_to_hash, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(data.encode("utf-8")).hexdigest()


def triage() -> dict:
    originals, _ = collect()
    groups = parse_group_sources()
    pending = []
    group_proven = []
    exact = []
    for q in originals:
        if q.part != "PART_7":
            continue
        if q.evidence and q.evidence in q.passage:
            exact.append(q.id)
            continue
        record = {
            "assetId": q.id,
            "version": q.version,
            "questionSha256": digest(q),
            "sourceFile": q.source + ".ets",
            "groupId": q.group,
            "evidence": q.evidence,
        }
        if q.group:
            group = groups.get(q.group)
            if group is None or q.id not in group["questionIds"]:
                raise AssertionError(f"{q.id}: missing or unlinked group passages {q.group}")
            snippets = [piece.strip() for piece in q.evidence.split(" || ")]
            supporting_docs = [
                [i + 1 for i, document in enumerate(group["documents"]) if snip in document]
                for snip in snippets
            ]
            if not all(snippets) or not all(supporting_docs):
                raise AssertionError(f"{q.id}: shared document quotation cannot be located")
            record.update({
                "category": "SHARED_PASSAGE_VERBATIM",
                "passageSourceFile": group["file"] + ".ets",
                "evidenceDocumentNumbers": supporting_docs,
                "semanticDecision": "NOT_INDEPENDENTLY_PROVED",
            })
            group_proven.append(record)
        else:
            if not q.passage:
                raise AssertionError(f"{q.id}: unresolved empty passage and group")
            evidence = q.evidence
            if "..." in evidence or "…" in evidence:
                issue = "ELLIPSIS_COMPRESSION"
            elif " || " in evidence:
                issue = "MULTI_FRAGMENT_INTERPRETATION"
            elif ";" in evidence or re.search(r"\d+\s*[+=-]\s*\d+", evidence):
                issue = "CONDITIONS_OR_ARITHMETIC"
            else:
                issue = "NON_VERBATIM_PARAPHRASE"
            record.update({
                "category": "INLINE_PASSAGE_SEMANTIC_REVIEW",
                "riskType": issue,
                "passage": q.passage,
                "question": q.stem,
                "options": q.choices,
                "answerIndex": q.answer,
                "semanticDecision": "PENDING",
            })
            pending.append(record)
    if len(originals) != 431 or len(exact) + len(group_proven) + len(pending) != 246:
        raise AssertionError("legacy question corpus/Part7 inventory changed")
    if len(group_proven) != 65 or len(pending) != 71:
        raise AssertionError("Issue #478 evidence baseline changed: update review ledger")
    if len({x["assetId"] for x in group_proven + pending}) != 136:
        raise AssertionError("duplicate evidence review asset")
    return {
        "schemaVersion": 1,
        "scope": "LEGACY_READING_CORPUS_ONLY",
        "notSemanticCertification": True,
        "summary": {
            "legacyReadingQuestions": len(originals),
            "legacyPart7": 246,
            "inlineVerbatim": len(exact),
            "sharedPassageVerbatim": len(group_proven),
            "inlineNonverbatimPending": len(pending),
            "totalPreviousFalsePositivePool": len(group_proven) + len(pending),
            "newDay14Day19DerivedMockQuestionsIncluded": False,
        },
        "pendingCountsByReason": dict(sorted(Counter(x["riskType"] for x in pending).items())),
        "groupProvenance": group_proven,
        "needsIndependentSemanticReview": pending,
    }


def validate() -> None:
    result = triage()
    summary = result["summary"]
    # Confirm the original 136 "non-verbatim" alerts are not all errors.
    assert summary["sharedPassageVerbatim"] == 65
    assert summary["inlineNonverbatimPending"] == 71
    assert result["notSemanticCertification"] is True
    print("TOEIC_ISSUE478_EVIDENCE_PROVENANCE_PASS "
          f"originalPart7={summary['legacyPart7']} "
          f"single_quote_verified={summary['inlineVerbatim']} "
          f"shared_group_quote_verified={summary['sharedPassageVerbatim']} "
          f"inline_semantic_pending={summary['inlineNonverbatimPending']} "
          "independent_semantic_certification=NOT_DONE")
    print("TOEIC_ISSUE478_PENDING_BY_REASON "
          + " ".join(f"{key}={value}" for key,value in result["pendingCountsByReason"].items()))


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, help="Export complete ID/evidence/source queue")
    args = parser.parse_args()
    validate()
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(triage(), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")
