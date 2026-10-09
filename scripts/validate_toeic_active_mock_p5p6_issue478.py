#!/usr/bin/env python3
"""Issue #478: actual two-mock Part5/6 editorial first-pass evidence gate.

Checks each current slot and authored rationale. Hashes bind *all* source code
that dynamically creates a question so a later edit invalidates old review.
This is AI first-pass, not human/ETS independent certification.
"""
from __future__ import annotations

import ast
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

from validate_toeic_question_quality import collect, fields, literals_after

ROOT = Path(__file__).resolve().parents[1]
CONT = ROOT / "entry/src/main/ets/toeic/content"
LEDGER = ROOT / "docs/product/toeic-issue478-active-mock-p5p6-first-pass-92.json"
NOTE_P5 = ROOT / "docs/product/toeic-issue478-active-mock-p5-review-notes-60.txt"
NOTE_P6 = ROOT / "docs/product/toeic-issue478-active-mock-p6-review-notes-32.txt"
NEW_P5 = "entry/src/main/ets/toeic/content/ToeicMockDay19Part5V2Content.ets"
NEW_P6 = "entry/src/main/ets/toeic/content/ToeicMockPart6V2RepairContent.ets"
DAY19_P6 = "entry/src/main/ets/toeic/content/ToeicMockDay19Part6V2Content.ets"
NEW_FINISH = "entry/src/main/ets/toeic/content/ToeicMockDay19Part6CompletionContent.ets"


def source_blob(path: Path) -> str:
    content = path.read_bytes()
    return hashlib.sha1(f"blob {len(content)}\0".encode("ascii") + content).hexdigest()


def literal_calls(name: str) -> dict[str, list[str]]:
    source = (ROOT / name).read_text(encoding="utf-8")
    result = {}
    for call in literals_after(source, "new ToeicQuestion("):
        args = fields(call)
        if args and re.fullmatch(r"""(?:'R-FM[^']+'|"R-FM[^"]+")""", args[0]):
            key = ast.literal_eval(args[0])
            if key in result:
                raise AssertionError(f"duplicate new question {key}")
            result[key] = args
    return result


def legacy_skills() -> dict[str, str]:
    found = {}
    for name in ("ToeicWeekTwoContent", "ToeicWeekThreeContent"):
        path = CONT / (name + ".ets")
        for call in literals_after(path.read_text(encoding="utf-8"), f"{name}.q("):
            args = fields(call)
            if args and re.fullmatch(r"""(?:'R-M[12]-P[56]-[^']+'|"R-M[12]-P[56]-[^"]+")""", args[0]):
                found[ast.literal_eval(args[0])] = args[2].split(".")[-1]
    return found


def inventory_article() -> str:
    source = (ROOT / DAY19_P6).read_text(encoding="utf-8")
    body = source.split("let passage=", 1)[1].split(";\n    let items:", 1)[0]
    atoms = re.findall(r"""'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*" """.strip(), body)
    if len(atoms) != 6:
        raise AssertionError("Day19 updated inventory article concatenation changed")
    return "".join(ast.literal_eval(token) for token in atoms)


def insertion_question() -> tuple[str, list[str], str]:
    source = (ROOT / DAY19_P6).read_text(encoding="utf-8")
    block = source.split("if (i===2) {", 1)[1].split("items.push(", 1)[0]
    stem = re.search(r"""stem=('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*");""", block)
    options = re.search(r"options=(\[.*?\]);", block, flags=re.S)
    explanation = re.search(r"""explanation=('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*");""", block)
    if not (stem and options and explanation):
        raise AssertionError("Day19 edited sentence-insertion semantics not parseable")
    return (ast.literal_eval(stem[1]), ast.literal_eval(options[1]),
            ast.literal_eval(explanation[1]))


def notes() -> dict[str, tuple[str, list[str]]]:
    rows = {}
    for path in (NOTE_P5, NOTE_P6):
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            parts = line.split("|")
            if len(parts) != 5 or parts[0] in rows:
                raise AssertionError(f"invalid editorial note: {parts[0]}")
            rows[parts[0]] = (parts[1], parts[2:])
    if len(rows) != 92:
        raise AssertionError("all 92 Part5/6 options require authored reasons")
    return rows


def current_items() -> list[dict]:
    originals, _ = collect()
    by_id = {q.id: q for q in originals}
    skills = legacy_skills()
    source_two = "entry/src/main/ets/toeic/content/ToeicWeekTwoContent.ets"
    source_three = "entry/src/main/ets/toeic/content/ToeicWeekThreeContent.ets"
    files = {**literal_calls(NEW_P5), **literal_calls(NEW_P6),
             **literal_calls(NEW_FINISH)}
    required = {"R-FM2-P5-007", "R-FM1-P6-033", "R-FM2-P6-009",
                "R-FM2-P6-017", "R-FM2-P6-018"}
    if set(files) != required:
        raise AssertionError(f"unexpected new P5/6 constructors {set(files)}")
    new_article = inventory_article()
    ins_stem, ins_opts, ins_explain = insertion_question()
    result = []
    for day in (14, 19):
        prefix = "R-M1" if day == 14 else "R-M2"
        for slot in range(46):
            original_id = (
                f"{prefix}-P5-{slot+1:03d}" if slot < 30 else
                f"{prefix}-P6-{slot+1:03d}" if day == 14 else
                f"{prefix}-P6-{slot-29:03d}"
            )
            if original_id not in by_id:
                raise AssertionError(f"lost original {original_id}")
            old = by_id[original_id]
            qid = original_id
            origin_file = source_two if day == 14 else source_three
            skill = skills[original_id]
            article = old.passage
            stem = old.stem
            options = old.choices
            answer = old.answer
            explanation = old.explanation
            if day == 14 and slot == 32:
                qid, origin_file = "R-FM1-P6-033", NEW_P6
            elif day == 19:
                special = {6: ("R-FM2-P5-007", NEW_P5),
                           30: ("R-FM2-P6-001", DAY19_P6),
                           31: ("R-FM2-P6-002", DAY19_P6),
                           32: ("R-FM2-P6-003", DAY19_P6),
                           33: ("R-FM2-P6-017", NEW_FINISH),
                           37: ("R-FM2-P6-018", NEW_FINISH),
                           38: ("R-FM2-P6-009", NEW_P6)}
                if slot in special:
                    qid, origin_file = special[slot]
            if qid in files:
                args = files[qid]
                skill = args[3].split(".")[-1]
                options = ast.literal_eval(args[6])
                answer = int(args[7])
                explanation = ast.literal_eval(args[8])
                if qid == "R-FM2-P5-007":
                    stem = ast.literal_eval(args[5])
            if qid in ("R-FM2-P6-001", "R-FM2-P6-002",
                       "R-FM2-P6-003", "R-FM2-P6-017"):
                article = new_article
            if qid == "R-FM2-P6-003":
                stem, options, explanation = ins_stem, ins_opts, ins_explain
                answer, skill = 3, "SENTENCE_INSERTION"
            result.append({
                "id": qid, "day": day, "slot": slot,
                "source": {"originId": original_id, "originFile": origin_file,
                           "originVersion": old.version},
                "question": {
                    "part": old.part, "skill": skill, "article": article,
                    "stem": stem, "options": options,
                    "answerIndex": answer, "explanation": explanation,
                    "version": 1,
                },
            })
    return result


def check_one(record: dict, original: dict, reasons: dict) -> None:
    qid = original["id"]
    if {k: record[k] for k in ("id", "day", "slot", "source", "question")} != original:
        changes = {key: {"actual": record.get(key), "expected": original.get(key)} for key in ("id", "day", "slot", "source", "question") if record.get(key) != original.get(key)}
        raise AssertionError(f"{qid}: active snapshot drift {changes}")
    if record.get("reviewOutcome") != "AI_FIRST_PASS" or record.get("expertCertified") is not False:
        raise AssertionError(f"{qid}: invalid editorial status")
    if record["question"]["answerIndex"] not in range(4):
        raise AssertionError(f"{qid}: invalid answer")
    if len(record["question"]["options"]) != 4:
        raise AssertionError(f"{qid}: invalid options")
    if qid not in reasons:
        raise AssertionError(f"{qid}: missing editorial rationale")
    basis, wrong = reasons[qid]
    if record.get("correctBasis") != basis or record.get("distractorReasons") != wrong:
        raise AssertionError(f"{qid}: editorial note and tracked snapshot diverged")
    if len(basis.strip()) < 10 or len(wrong) != 3 or any(len(s.strip()) < 7 for s in wrong):
        raise AssertionError(f"{qid}: incomplete wrong-choice exclusion notes")


def validate() -> None:
    doc = json.loads(LEDGER.read_text(encoding="utf-8"))
    if doc["reviewStatus"] != "AI_FIRST_PASS" or doc["expertCertified"] is not False:
        raise AssertionError("AI note cannot claim human/ETS certification")
    if set(doc["sourceBlobs"]) != {
        "entry/src/main/ets/toeic/content/" + name + ".ets" for name in (
            "ToeicWeekTwoContent", "ToeicWeekThreeContent", "ToeicMockDay19Part5V2Content",
            "ToeicMockPart6V2RepairContent", "ToeicMockDay19Part6V2Content",
            "ToeicMockDay19Part6CompletionContent", "PresetToeicContent")
    }:
        raise AssertionError("source list changed")
    for path, expected in doc["sourceBlobs"].items():
        if source_blob(ROOT / path) != expected:
            raise AssertionError(f"{path}: active source changed; re-review required")
    expected_items = current_items()
    records = doc["items"]
    if len(records) != 92 or len({r["id"] for r in records}) != 92:
        raise AssertionError("two papers must have exactly 92 unique P5+P6 active items")
    reasons = notes()
    if set(reasons) != {r["id"] for r in records}:
        raise AssertionError("reviewed IDs differ from live active paper")
    for actual, expected in zip(records, expected_items, strict=True):
        check_one(actual, expected, reasons)
    changed = deepcopy(records[0])
    changed["question"]["answerIndex"] = (changed["question"]["answerIndex"] + 1) % 4
    try:
        check_one(changed, expected_items[0], reasons)
    except AssertionError:
        pass
    else:
        raise AssertionError("negative answer-tampering check incorrectly passed")
    preset = (CONT / "PresetToeicContent.ets").read_text(encoding="utf-8")
    for expected in (
        "ids[33]=ToeicMockDay19Part6CompletionContent.inventory().id;",
        "ids[37]=ToeicMockDay19Part6CompletionContent.library().id;",
        "if (question.id==='R-M1-P7-094'",
        "question.id==='R-FM2-P6-004'", "question.id==='R-M2-P6-008'",
    ):
        if expected not in preset:
            raise AssertionError(f"new active mock or live exclusion missing: {expected}")
    old, _ = collect()
    originals = {q.id: q for q in old}
    assert originals["R-M2-P6-008"].choices == ["complete", "completed", "completing", "completion"]
    assert originals["R-M2-P6-008"].version == 1
    assert records[79]["id"] == "R-FM2-P6-017" and records[83]["id"] == "R-FM2-P6-018"
    print("TOEIC_ISSUE478_ACTIVE_P5_P6_FIRST_PASS_PASS active=92 day14=46 day19=46 "
          "correct_notes=92 distractor_exclusions=276 source_blobs=7 "
          "historical_double_answer_items_excluded=2 expert_certification=NO")


if __name__ == "__main__":
    validate()
