#!/usr/bin/env python3
"""Issue #478 P2 final content gate.

Validates:
- all 246 original Part 7 assets have a source-bound AI second-pass decision;
- the only unresolved ambiguity remains archived and excluded from live training;
- all 221 Chinese question translations and all 70 sentence drills are covered by
  a final source-blob-bound bilingual second pass;
- current active Day14/19 Part7 review evidence still covers 36 authored + 72
  derived questions.

This is AI editorial evidence, not human/ETS certification.
"""
from __future__ import annotations
import ast
import hashlib
import json
from pathlib import Path

from validate_toeic_question_quality import (
    CONTENT, FILES, collect, fields, literals_after, remove_arkts_comments,
)
from validate_toeic_translation_coverage import collect_translations

ROOT = Path(__file__).resolve().parents[1]
PART7 = ROOT / "docs/product/toeic-issue478-p2-final-part7-review-2026-10-09.json"
BILINGUAL = ROOT / "docs/product/toeic-issue478-p2-final-bilingual-review-2026-10-09.json"
AUTHORED = ROOT / "docs/product/toeic-issue478-v2-authored-part7-review-36.json"
DERIVED = ROOT / "docs/product/toeic-issue478-v2-derived-part7-semantic-review-72.json"

def canonical_sha(obj: dict) -> str:
    raw = json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()

def git_blob_sha(text: str) -> str:
    data = text.encode("utf-8")
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()

def parse_part7_current() -> dict[str, dict]:
    source_items, _ = collect()
    meta = {q.id: q for q in source_items if q.part == "PART_7"}
    rows: dict[str, dict] = {}
    for basename in FILES:
        source = (CONTENT / f"{basename}.ets").read_text(encoding="utf-8")
        wrapper = basename in ("ToeicWeekTwoContent", "ToeicWeekThreeContent")
        signature = f"{basename}.q(" if wrapper else "new ToeicQuestion("
        for raw in literals_after(remove_arkts_comments(source), signature):
            args = fields(raw)
            if not args or not args[0].startswith(("'", '"')):
                continue
            values = [ast.literal_eval(x) if x.startswith(("'", '"', "[")) else x for x in args]
            question_id = values[0]
            if question_id not in meta:
                continue
            q = meta[question_id]
            shift = 0 if wrapper else 1
            row = {
                "id": question_id,
                "sourceFile": basename + ".ets",
                "passage": values[3 + shift],
                "stem": values[4 + shift],
                "options": values[5 + shift],
                "answerIndex": int(values[6 + shift]),
                "explanation": values[7 + shift],
                "evidence": values[8 + shift],
                "paraphrase": values[9 + shift],
                "version": q.version,
            }
            row["contentSha256"] = canonical_sha(row)
            rows[question_id] = row
    assert len(rows) == 246, f"current Part7 count {len(rows)} != 246"
    return rows

def parse_drill_ids() -> set[str]:
    ids: set[str] = set()
    for basename in ("ToeicWeekOneContent", "ToeicWeekTwoContent", "ToeicWeekThreeContent"):
        source = (CONTENT / f"{basename}.ets").read_text(encoding="utf-8")
        for raw in literals_after(remove_arkts_comments(source), "new ToeicSentenceDrill("):
            args = fields(raw)
            if not args or not args[0].startswith(("'", '"')):
                continue
            drill_id = ast.literal_eval(args[0])
            if isinstance(drill_id, str) and drill_id.startswith("S-"):
                assert drill_id not in ids
                ids.add(drill_id)
    assert len(ids) == 70
    return ids

def validate() -> None:
    current = parse_part7_current()
    doc = json.loads(PART7.read_text(encoding="utf-8"))
    assert doc["reviewMode"] == "AI_EDITORIAL_SECOND_PASS"
    assert doc["expertCertification"] == "NO"
    assert doc["count"] == 246 and doc["passCount"] == 245
    assert doc["archivedAmbiguityCount"] == 1
    assert doc["archivedAmbiguityIds"] == ["R-M1-P7-094"]
    items = {x["id"]: x for x in doc["items"]}
    assert set(items) == set(current)
    for question_id, source in current.items():
        review = items[question_id]
        assert review["contentSha256"] == source["contentSha256"], (
            f"{question_id}: final Part7 review drifted from current source")
        assert review["correctIndex"] == source["answerIndex"]
        assert review["evidence"] == source["evidence"]
        assert review["reviewer"] == "AI-GPT5.6-SOL"
        assert review["reviewedAt"] == "2026-10-09"
        wrong = [x for x in range(4) if x != source["answerIndex"]]
        assert [x["index"] for x in review["wrongOptions"]] == wrong
        assert len(review["wrongOptions"]) == 3 and review["correctBasis"]
        if question_id == "R-M1-P7-094":
            assert review["decision"] == "ARCHIVED_AMBIGUITY"
        else:
            assert review["decision"] == "PASS_AI_SECOND_PASS"

    preset = (CONTENT / "PresetToeicContent.ets").read_text(encoding="utf-8")
    assert "question.id==='R-M1-P7-094'" in preset
    ambiguous = current["R-M1-P7-094"]
    assert "next week" in ambiguous["passage"]
    assert "Oct. 4–8" in ambiguous["passage"]

    bilingual = json.loads(BILINGUAL.read_text(encoding="utf-8"))
    assert bilingual["reviewMode"] == "AI_EDITORIAL_SECOND_PASS"
    assert bilingual["expertCertification"] == "NO"
    assert bilingual["reviewer"] == "AI-GPT5.6-SOL"
    for file_name, expected in bilingual["sourceBlobs"].items():
        source = (CONTENT / file_name).read_text(encoding="utf-8")
        assert git_blob_sha(source) == expected, f"{file_name}: final bilingual source blob drift"

    translations = collect_translations()
    tdoc = bilingual["translations"]
    assert tdoc["count"] == 221 and tdoc["passCount"] == 218 and tdoc["correctedCount"] == 3
    titems = {x["id"]: x for x in tdoc["items"]}
    assert set(titems) == set(translations)
    corrected_t = {"R-P5-VERB-0206", "R-P7-DOUBLE-1105", "R-P7-TRIPLE-1203"}
    assert {x for x, row in titems.items() if row["decision"] == "PASS_AFTER_CORRECTION"} == corrected_t
    for question_id, row in titems.items():
        assert row["decision"] in {"PASS_AI_SECOND_PASS", "PASS_AFTER_CORRECTION"}
        assert len(translations[question_id][2]) == 4

    # Exact semantic-boundary regressions from the final P2 pass.
    week1 = (CONTENT / "ToeicQuestionTranslationWeekOneCatalog.ets").read_text(encoding="utf-8")
    week2 = (CONTENT / "ToeicQuestionTranslationWeekTwoCatalog.ets").read_text(encoding="utf-8")
    assert "最迟于周五（含当天）_____培训的员工将获得证书。" in week1
    assert "在周五前_____培训的员工将获得证书。" not in week1
    assert "订单金额超过100美元可免标准运费。" in week2
    assert "订单满100美元免标准运费。" not in week2
    assert "Jordan 最迟能于11月1日开始工作（含当天）" in week2
    assert "Jordan 能在11月1日前开始工作" not in week2

    drills = parse_drill_ids()
    ddoc = bilingual["sentenceDrills"]
    assert ddoc["count"] == 70 and ddoc["passCount"] == 68 and ddoc["correctedCount"] == 2
    ditems = {x["id"]: x for x in ddoc["items"]}
    assert set(ditems) == drills
    corrected_d = {"S-037", "S-062"}
    assert {x for x, row in ditems.items() if row["decision"] == "PASS_AFTER_CORRECTION"} == corrected_d
    w2 = (CONTENT / "ToeicWeekTwoContent.ets").read_text(encoding="utf-8")
    w3 = (CONTENT / "ToeicWeekThreeContent.ets").read_text(encoding="utf-8")
    assert "最迟将于 10 月 18 日收到联系（含当天，也可能更早）" in w2
    assert "最迟会在 10 月 18 日当天收到联系" not in w2
    assert "收到付款后自动发送的确认信息包含签到时所需的参考编号。" in w3
    assert "付款收到后自动发送的确认信息" not in w3

    authored = json.loads(AUTHORED.read_text(encoding="utf-8"))
    derived = json.loads(DERIVED.read_text(encoding="utf-8"))
    assert len(authored["items"]) == 36
    assert all(x["reviewOutcome"] == "AI_FIRST_PASS" for x in authored["items"])
    assert len(derived["items"]) == 72
    assert all(x["reviewStatus"] == "AI_DERIVED_CONTEXT_PASS" for x in derived["items"])

    print(
        "TOEIC_ISSUE478_P2_FINAL_PASS "
        "original_part7=246 pass=245 archived_ambiguity=1 "
        "active_v2_part7=108 authored=36 derived_second_context=72 "
        "translations=221 pass=218 corrected=3 "
        "drills=70 pass=68 corrected=2 "
        "reviewer=AI-GPT5.6-SOL expert_certification=NO"
    )

if __name__ == "__main__":
    validate()
