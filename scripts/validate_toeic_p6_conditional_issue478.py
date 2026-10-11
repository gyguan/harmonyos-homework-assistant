#!/usr/bin/env python3
"""Issue478: active Day16 P6 future conditional uniquely answered and archive safe."""
from pathlib import Path
from validate_toeic_question_quality import fields,literals_after,parse_question
ROOT=Path(__file__).resolve().parents[1]
CONT=ROOT/"entry/src/main/ets/toeic/content"
def validate():
    path=CONT/"ToeicP6ConditionalIssue478.ets"
    items=[parse_question(fields(s),"ToeicP6ConditionalIssue478",False) for s in literals_after(path.read_text(encoding="utf-8"),"new ToeicQuestion(")]
    assert len(items)==1 and items[0] is not None
    q=items[0]
    assert q.id=="R-FP6-SPRINT-1610" and q.part=="PART_6" and q.answer==2
    assert q.choices==["provides","provided","will provide","providing"] and "provide" not in q.choices
    assert q.version==1 and "If the chair cannot be repaired on site" in q.passage
    preset=(CONT/"PresetToeicContent.ets").read_text(encoding="utf-8")
    assert ".concat(ToeicP6ConditionalIssue478.questions())" in preset
    assert "plan.day===16" in preset
    assert "if (id==='R-P6-SPRINT-1606') return 'R-FP1-P6-1606';" in preset
    assert "if (id==='R-P6-SPRINT-1610') return 'R-FP6-SPRINT-1610';" in preset
    assert "question.id==='R-P6-SPRINT-1610'" in preset
    old=(CONT/"ToeicWeekThreeContent.ets").read_text(encoding="utf-8")
    assert '["provide","provided","will provide","providing"],2' in old
    translations=(CONT/"ToeicQuestionTranslationCatalog.ets").read_text(encoding="utf-8")
    assert "questionId==='R-FP6-SPRINT-1610'" in translations
    print("TOEIC_ISSUE478_DAY16_P6_UNIQUE_PASS new=1 original_unchanged=YES")
if __name__=="__main__":
    validate()
