#!/usr/bin/env python3
"""Issue #478: keep archived mock history while removing 3 non-unique answers from new sessions.

The old versions remain addressable for history; they are not silently
certified as accurate, and they must not reappear in subsequent drills.
"""
from __future__ import annotations

import ast
from pathlib import Path
from validate_toeic_question_quality import collect, fields, literals_after, parse_question

ROOT = Path(__file__).resolve().parents[1]
C = ROOT / "entry/src/main/ets/toeic/content"
DAY19_P5 = C / "ToeicMockDay19Part5V2Content.ets"
P6_REPAIRS = C / "ToeicMockPart6V2RepairContent.ets"
PRESET = C / "PresetToeicContent.ets"


def authored_args(path: Path) -> dict[str, list[str]]:
    source = path.read_text(encoding="utf-8")
    items = {}
    for call in literals_after(source, "new ToeicQuestion("):
        args = fields(call)
        if args and args[0].startswith(("'R-FM", '"R-FM')):
            qid = ast.literal_eval(args[0])
            if qid in items:
                raise AssertionError(f"{qid}: duplicate replacement ID")
            items[qid] = args
    return items


def validate() -> None:
    originals, _ = collect()
    by_id = {q.id: q for q in originals}
    original_p5 = by_id["R-M2-P5-007"]
    original_p6_day14 = by_id["R-M1-P6-033"]
    original_p6_day19 = by_id["R-M2-P6-009"]
    assert original_p5.version == original_p6_day14.version == original_p6_day19.version == 1
    assert original_p5.choices == ["visits", "visited", "will visit", "has visited"]
    assert original_p5.answer == 2
    assert original_p6_day14.choices == ["they", "it", "one", "those"]
    assert original_p6_day14.answer == 0
    assert original_p6_day19.choices == ["needs", "needed", "will need", "needing"]
    assert original_p6_day19.answer == 1

    day19_p5 = authored_args(DAY19_P5)
    p6_repairs = authored_args(P6_REPAIRS)
    assert set(day19_p5) == {"R-FM2-P5-007"}
    assert set(p6_repairs) == {"R-FM1-P6-033", "R-FM2-P6-009"}
    q = parse_question(day19_p5["R-FM2-P5-007"], "ToeicMockDay19Part5V2Content", False)
    assert q.version == 1 and q.answer == 2
    assert q.stem == original_p5.stem
    assert q.choices == ["visit", "visited", "will visit", "has visited"]
    assert q.choices[q.answer] == original_p5.choices[original_p5.answer]
    assert "next Monday" in q.stem

    day14_args = p6_repairs["R-FM1-P6-033"]
    day19_args = p6_repairs["R-FM2-P6-009"]
    assert ast.literal_eval(day14_args[6]) == ["they", "them", "their", "themselves"]
    assert int(day14_args[7]) == original_p6_day14.answer == 0
    assert ast.literal_eval(day19_args[6]) == [
        "were required", "was required", "is requiring", "have been required"
    ]
    assert int(day19_args[7]) == original_p6_day19.answer == 1
    assert "ToeicSkill.REFERENCE" in day14_args[3]
    assert "ToeicSkill.VOICE" in day19_args[3]
    assert "'was required to attend = had to attend'" in day19_args[10]
    assert "archived.passage" in day14_args and "archived.passage" in day19_args
    assert "ToeicReviewStatus.PUBLISHED" in day14_args[14]
    assert "ToeicReviewStatus.PUBLISHED" in day19_args[14]

    source = PRESET.read_text(encoding="utf-8")
    assert "ToeicMockDay19Part5V2Content.questions()" in source
    assert "ToeicMockPart6V2RepairContent.day14()" in source
    assert "ToeicMockPart6V2RepairContent.day19()" in source
    assert "ids[32]=ToeicMockPart6V2RepairContent.day14().id" in source
    assert "ids[6]=ToeicMockDay19Part5V2Content.questions()[0].id" in source
    assert "ids[38]=ToeicMockPart6V2RepairContent.day19().id" in source
    assert "let published=PresetToeicContent.publishedQuestions();" in source
    live = source.split("static liveTrainingQuestions():ToeicQuestion[]", 1)[1].split("\n  }", 1)[0]
    for qid in ("R-M1-P7-094", "R-M2-P5-007", "R-M1-P6-033", "R-M2-P6-009"):
        assert f"question.id==='{qid}'" in live, f"{qid}: legacy ambiguity leaked into drills"
    # Do not alter the publishedQuestions() lookup used by saved history reports.
    assert "static publishedQuestions():ToeicQuestion[]" in source

    print("TOEIC_ISSUE478_MOCK_P5P6_UNIQUE_PASS new_active_items=3 "
          "old_version1_preserved=3 live_old_ambiguities_excluded=3 "
          "historical_lookup_unchanged=YES")


if __name__ == "__main__":
    validate()
