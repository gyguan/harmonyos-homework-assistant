#!/usr/bin/env python3
"""Issue #478: source-bound AI first-pass for new Day14/19 Part7 items.

Separately verify the option/answer transform contract for the 72 inherited
Part7 items. This does NOT establish independent expert/ETS certification.
"""
from __future__ import annotations

from copy import deepcopy
import json
import re
from pathlib import Path

from validate_toeic_question_quality import (
    collect, fields, literals_after, parse_question, remove_arkts_comments,
)

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"
LEDGER = ROOT / "docs/product/toeic-issue478-v2-authored-part7-review-36.json"
DAY14 = CONTENT / "ToeicMockDay14V2Content.ets"
DAY19 = CONTENT / "ToeicMockDay19V2Content.ets"


def authored_questions(path: Path) -> dict[str, dict]:
    source = remove_arkts_comments(path.read_text(encoding="utf-8"))
    result = {}
    for call in literals_after(source, "new ToeicQuestion("):
        args = fields(call)
        # Computed strings such as 'R-FM1-'+String(group) are derived
        # constructors, not 36 literal authored questions.
        if not args or not re.fullmatch(r"""(?:'R-FM[^']+'|"R-FM[^"]+")""", args[0]):
            continue
        question = parse_question(args, path.stem, False)
        if question is None or question.part != "PART_7":
            raise AssertionError(f"invalid authored Part7 constructor in {path.name}")
        if question.id in result:
            raise AssertionError(f"duplicate authored new question: {question.id}")
        result[question.id] = {
            "id": question.id,
            "skill": args[3].rsplit(".", 1)[-1],
            "passage": question.passage,
            "stem": question.stem,
            "options": question.choices,
            "answerIndex": question.answer,
            "explanation": question.explanation,
            "evidence": question.evidence,
            "version": question.version,
        }
    return result


def check_record(note: dict, q: dict, mock_day: int) -> None:
    qid = note["assetId"]
    if note["questionSnapshot"] != q:
        raise AssertionError(f"{qid}: authored answer/options/source/version changed")
    if note["mockDay"] != mock_day:
        raise AssertionError(f"{qid}: wrong source paper")
    if note["sourceFile"] != ("ToeicMockDay14V2Content.ets" if mock_day == 14
                              else "ToeicMockDay19V2Content.ets"):
        raise AssertionError(f"{qid}: stale source file")
    if note["reviewOutcome"] != "AI_FIRST_PASS" or note["isExpertCertified"] is not False:
        raise AssertionError(f"{qid}: misleading editorial certification")
    if len(note.get("correctBasis", "").strip()) < 5:
        raise AssertionError(f"{qid}: correct answer rationale missing")
    reasons = note.get("distractorReasons")
    if not isinstance(reasons, list) or len(reasons) != 3:
        raise AssertionError(f"{qid}: require all three wrong-option exclusions")
    if any(not isinstance(x, str) or len(x.strip()) < 4 for x in reasons):
        raise AssertionError(f"{qid}: incomplete wrong-option analysis")
    if q["version"] < 1 or q["answerIndex"] not in range(4) or len(q["options"]) != 4:
        raise AssertionError(f"{qid}: invalid question contract")


def derived_answer_mappings() -> dict[str, tuple[str, int, int]]:
    """Map all 72 new v2 derived IDs to archive IDs, expected answer and version."""
    original, _ = collect()
    by_id = {q.id: q for q in original}
    expected = {}
    for i in range(24):
        old = by_id[f"R-M1-P7-{47+i:03d}"]
        id = f"R-FM1-P7-S{i//3+1:02d}-{i%3+1:02d}"
        expected[id] = (old.id, old.answer, old.version)
    for g in range(5):
        for i in range(3):
            old = by_id[f"R-M1-P7-{71+g*3+i:03d}"]
            id = f"R-FM1-P7-M{g+1}-{i+1:02d}"
            rotated = (old.answer + i) % 4
            # Runtime rotates newOptions[x] = oldOptions[(x+4-i)%4]
            new_options = [old.choices[(j+4-i)%4] for j in range(4)]
            if new_options[rotated] != old.choices[old.answer]:
                raise AssertionError(f"{id}: rotated answer text drift")
            expected[id] = (old.id, rotated, 2 if old.id == "R-M1-P7-077" else 1)
    for i in range(18):
        old = by_id[f"R-M2-P7-{chr(ord('A')+i//3)}-{i%3+1:02d}"]
        id = f"R-FM2-P7-S{i//3+1:02d}-{i%3+1:02d}"
        expected[id] = (old.id, old.answer, 1)
    for g in range(5):
        for i in range(3):
            old = by_id[f"R-M2-P7-{chr(ord('G')+g)}-{i+1:02d}"]
            id = f"R-FM2-P7-M{g+1}-{i+1:02d}"
            rotation = (i-old.answer+4)%4
            new_options = [old.choices[(j+4-rotation)%4] for j in range(4)]
            if new_options[i] != old.choices[old.answer]:
                raise AssertionError(f"{id}: wrong answer after derived choice rotation")
            expected[id] = (old.id, i, 1)
    if len(expected) != 72:
        raise AssertionError(f"inherited mock derived coverage changed: {len(expected)}")
    return expected


def validate() -> None:
    data = json.loads(LEDGER.read_text(encoding="utf-8"))
    if data["reviewMode"] != "AI_FIRST_PASS" or data["notExpertCertified"] is not True:
        raise AssertionError("must retain accurate AI first-pass review status")
    day14 = authored_questions(DAY14)
    day19 = authored_questions(DAY19)
    if len(day14) != 15 or len(day19) != 21:
        raise AssertionError("new authored Day14/Day19 item count drift")
    actual = {**day14, **day19}
    notes = data["items"]
    ids = [note["assetId"] for note in notes]
    if len(notes) != 36 or len(set(ids)) != 36 or set(ids) != set(actual):
        raise AssertionError("authored v2 Part7 note coverage not exact")
    for note in notes:
        qid = note["assetId"]
        check_record(note, actual[qid], 14 if qid in day14 else 19)
        # The evidence must be present in the question's own passage, or
        # be part of a published grouped article audited by the format gate.
        q = actual[qid]
        if q["passage"] and q["evidence"] not in q["passage"]:
            raise AssertionError(f"{qid}: evidence missing from the authored passage")

    # Exact record snapshots must become stale if a saved answer or stem moves.
    changed = deepcopy(notes[0])
    changed["questionSnapshot"]["answerIndex"] = (
        changed["questionSnapshot"]["answerIndex"] + 1
    ) % 4
    try:
        check_record(changed, actual[changed["assetId"]], changed["mockDay"])
    except AssertionError:
        pass
    else:
        raise AssertionError("tampered saved answer passed AI first-pass gate")

    legacy_derived = derived_answer_mappings()
    d14_source = DAY14.read_text(encoding="utf-8")
    d19_source = DAY19.read_text(encoding="utf-8")
    for token in (
        "let q=legacy[46+i]", "original=legacy[70+group*3+item]",
        "(o+4-item)%4", "(original.correctIndex+item)%4",
        "original.id==='R-M1-P7-077'?2:1",
    ):
        if token not in d14_source:
            raise AssertionError(f"Day14 actual derived transform changed: {token}")
    for token in (
        "old=legacy[46+i]", "old=legacy[64+group*3+item]",
        "rotation=(item-old.correctIndex+4)%4",
        "old.options[(c+4-rotation)%4]", "choices,item,old.explanation",
    ):
        if token not in d19_source:
            raise AssertionError(f"Day19 actual derived transform changed: {token}")

    # The two labels here are tied to literal passages, not inference/purpose.
    if actual["R-FM2-P7-S07-01"]["skill"] != "DETAIL":
        raise AssertionError("adapter inspection reason must be DETAIL")
    if actual["R-FM2-P7-S09-03"]["skill"] != "DETAIL":
        raise AssertionError("explicitly stated working headset must be DETAIL")
    if len(set(actual).intersection(legacy_derived)) != 0:
        raise AssertionError("new-authored and derived v2 IDs must be disjoint")
    print("TOEIC_ISSUE478_V2_P7_FIRST_PASS_PASS authored=36 day14=15 day19=21 "
          "authored_distractor_notes=108 derived_answer_map=72 "
          "active_v2_p7=108 legacy_version_preserved=YES "
          "independent_expert_certification=NO")


if __name__ == "__main__":
    validate()
