#!/usr/bin/env python3
"""Issue #478: reproducible high-risk semantic corrections and review triage.

This script is intentionally NOT a semantic certification of the entire TOEIC
corpus. It requires exact evidence for the selected dated cases, keeps a separate
record of legacy paraphrased evidence, and fails if verified corrections regress.
An AI check or a matching source quote alone does not prove a unique answer.
"""
from __future__ import annotations
import ast
import re
from collections import Counter
from pathlib import Path

from validate_toeic_question_quality import collect, fields, literals_after
from validate_toeic_translation_coverage import collect_translations

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"


def read(name: str) -> str:
    return (CONTENT / name).read_text(encoding="utf-8")


def sentence_drills() -> dict[str, tuple[str, str, str]]:
    items: dict[str, tuple[str, str, str]] = {}
    for file in ("ToeicWeekOneContent.ets", "ToeicWeekTwoContent.ets",
                 "ToeicWeekThreeContent.ets"):
        for raw in literals_after(read(file), "new ToeicSentenceDrill("):
            parts = fields(raw)
            if parts and parts[0].startswith(("'S-", '"S-')):
                id, english, chinese = (ast.literal_eval(part) for part in parts[:3])
                guidance = ast.literal_eval(parts[5])
                assert id not in items, f"duplicated sentence drill {id}"
                items[id] = english, chinese, guidance
    return items


def validate() -> None:
    questions, _ = collect()
    by_id = {q.id: q for q in questions}
    assert len(questions) == len(by_id) == 431, "all legacy questions must stay addressable"
    translations = collect_translations()
    assert len(translations) == 221, "published non-mock translation set changed"
    drills = sentence_drills()
    assert len(drills) == 70, "existing 70 sentence drills must remain available"

    # #478 A: a 2023-present CV cannot be treated as less than two years
    # without a document reference date. The corrected case is self-contained.
    job = by_id["R-P7-TRIPLE-1203"]
    assert job.version == 2 and job.answer == 0
    posting = re.search(r"JOB POSTING \(OCTOBER (\d{4})\)", job.passage)
    resume = re.search(r"Sales associate, January (\d{4})–present", job.passage)
    assert posting and resume, "job posting and resume require absolute dates"
    months = (int(posting.group(1)) - int(resume.group(1))) * 12 + (10 - 1)
    assert 0 <= months < 24, "job experience must demonstrably be less than two years"
    assert "inconsistent" in job.stem and "at least two years" in job.choices[0]
    assert "full-time" in job.passage and "full-time" in job.choices[2]
    assert "January 2026–present" in job.evidence
    zh_passage, zh_stem, zh_options = translations[job.id]
    assert "2026年1月至今" in zh_passage and "2026年10月" in zh_passage
    assert "不符" in zh_stem and "至少两年销售经验" in zh_options[0]
    assert len(zh_options) == len(job.choices)

    # #478 B: invoice amount due is NOT a guarantee that a bank transfer
    # initiated on the due date will be received or posted by that date.
    invoice = by_id["R-M1-P7-077"]
    assert invoice.version == 2 and invoice.answer == 0
    assert "excluding any late fee" in invoice.stem
    assert "before November 6" not in invoice.stem
    assert "Bank transfers may take up to two business days to post" in invoice.passage
    assert "Amount due: $640" in invoice.passage and invoice.choices[0] == "$640"
    assert "延迟入账" in invoice.explanation
    v2 = read("ToeicMockDay14V2Content.ets")
    assert "original.id==='R-M1-P7-077'?2:1" in v2, (
        "derived FM1 Part7 invoice also needs its own version increase")

    # #478 C: English 'by' and 'no later than' include the boundary, while
    # 'before' excludes it. Chinese 'XX前' is too ambiguous at these deadlines.
    for id, en_keyword, cn_anchor in (
        ("S-001", "by Friday", "最迟须在周五当天"),
        ("S-037", "no later than October 18", "10 月 18 日当天"),
        ("S-051", "by 9:20", "最迟在 9:20"),
        ("S-054", "by 11:30", "最迟必须在 11:30"),
    ):
        english, chinese, guidance = drills[id]
        assert en_keyword in english, f"{id}: English deadline changed"
        assert cn_anchor in chinese and "前到" not in chinese and "前离开" not in chinese, (
            f"{id}: inclusive Chinese deadline was lost")
        if id != "S-037":
            assert "含" in guidance, f"{id}: guidance must clarify inclusive boundary"

    # Global evidence gate produces triage, NOT a false full semantic PASS.
    part7 = [q for q in questions if q.part == "PART_7"]
    nonverbatim = [
        q.id for q in part7
        if q.evidence and q.evidence not in q.passage
    ]
    duplicate_options = [q.id for q in questions
                         if len({x.casefold().strip() for x in q.choices}) != 4]
    assert not duplicate_options, f"duplicated options: {duplicate_options}"
    print("TOEIC_ISSUE478_TARGETED_SEMANTIC_PASS "
          "dated_job=version2 invoice=version2 boundary_drills=4 bilingual=aligned")
    print(f"TOEIC_ISSUE478_SCOPE_TRIAGE legacy_questions={len(questions)} "
          f"part7={len(part7)} nonverbatim_evidence={len(nonverbatim)} "
          f"hidden_translations={len(translations)} sentence_drills={len(drills)} "
          "full_independent_semantic_certification=NOT_DONE")
    print("TOEIC_ISSUE478_EVIDENCE_TRIAGE_BY_SOURCE " +
          " ".join(f"{k}={v}" for k, v in sorted(Counter(
              q.source for q in part7 if q.id in nonverbatim).items())))


if __name__ == "__main__":
    validate()
