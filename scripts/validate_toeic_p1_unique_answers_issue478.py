#!/usr/bin/env python3
"""#478 P1: active Part5 two-choice ambiguity exclusion and history regression."""
from pathlib import Path
from validate_toeic_question_quality import fields, literals_after, parse_question

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"
REVISIONS = CONTENT / "ToeicP5UniqueAnswerIssue478.ets"
PRESET = CONTENT / "PresetToeicContent.ets"
TRANSLATIONS = CONTENT / "ToeicQuestionTranslationCatalog.ets"

def validate() -> None:
    text = REVISIONS.read_text(encoding="utf-8")
    parsed = [parse_question(fields(c), "ToeicP5UniqueAnswerIssue478", False)
              for c in literals_after(text, "new ToeicQuestion(")]
    assert len(parsed) == 2 and all(q for q in parsed)
    q = {x.id: x for x in parsed}
    assert set(q) == {"R-FP5-VERB-0206", "R-FP5-SPRINT-1517"}
    assert q["R-FP5-VERB-0206"].choices == ["complete", "completes", "completion", "completing"]
    assert q["R-FP5-VERB-0206"].answer == 0
    assert "completed" not in q["R-FP5-VERB-0206"].choices
    assert q["R-FP5-SPRINT-1517"].choices == ["had been", "being", "will be", "have been"]
    assert q["R-FP5-SPRINT-1517"].answer == 2
    assert "tomorrow" in q["R-FP5-SPRINT-1517"].stem
    assert "is" not in q["R-FP5-SPRINT-1517"].choices
    for question in q.values():
        assert question.version == 1 and len(question.choices) == 4 and len(set(question.choices)) == 4
        assert question.explanation and question.part == "PART_5"
    source = PRESET.read_text(encoding="utf-8")
    assert ".concat(ToeicP5UniqueAnswerIssue478.questions())" in source
    assert "plan.day===3" in source and "id==='R-P5-VERB-0206' ? 'R-FP5-VERB-0206'" in source
    assert "plan.day===15" in source
    assert "if (id==='R-P5-SPRINT-1517') return 'R-FP5-SPRINT-1517';" in source
    assert "if (id==='R-P5-SPRINT-1528') return 'R-FP1-P5-1528';" in source
    for id in ("R-P5-VERB-0206", "R-P5-SPRINT-1517"):
        assert f"question.id==='{id}'" in source, f"old question still eligible for new live sessions: {id}"
    chinese = TRANSLATIONS.read_text(encoding="utf-8")
    for id in q:
        assert f"questionId==='{id}'" in chinese
        assert f"new ToeicQuestionTranslation(questionId,''" in chinese
    old_1 = (CONTENT/"ToeicWeekOneContent.ets").read_text(encoding="utf-8")
    old_3 = (CONTENT/"ToeicWeekThreeContent.ets").read_text(encoding="utf-8")
    assert "['complete','completes','completed','completion'],0" in old_1
    assert '["is","was","will be","has been"],2' in old_3
    # Deliberate negative regression: adding removed distractors would violate
    # canonical snapshots, not just change an arbitrary editorial note.
    corrupted = ["complete", "completes", "completed", "completion"]
    assert corrupted != q["R-FP5-VERB-0206"].choices
    print("TOEIC_ISSUE478_P1_P5_UNIQUENESS_PASS replaced=2 old_versions_preserved=2 negative=2")

if __name__ == "__main__":
    validate()
