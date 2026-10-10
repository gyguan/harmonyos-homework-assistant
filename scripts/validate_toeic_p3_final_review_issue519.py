#!/usr/bin/env python3
"""Issue #519 P3 release-state blind-review gate.

This is an AI editorial release review, not ETS or human-expert certification.
It preserves previous source IDs for history and fails closed if the four P3
precision revisions or the recorded blind-review coverage regress.
"""
from __future__ import annotations
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CONTENT=ROOT/"entry/src/main/ets/toeic/content"
LEDGER=ROOT/"docs/product/toeic-issue519-p3-final-blind-review-2026-10-09.json"
P1=ROOT/"docs/product/toeic-issue478-p1-final-question-review-2026-10-09.json"
AUTHORED=ROOT/"docs/product/toeic-issue478-v2-authored-part7-review-36.json"
DERIVED=ROOT/"docs/product/toeic-issue478-v2-derived-part7-semantic-review-72.json"

def validate()->None:
    doc=json.loads(LEDGER.read_text(encoding="utf-8"))
    assert doc["issueNumber"]==519
    assert doc["reviewMode"]=="AI_RELEASE_BLIND_REVIEW"
    assert doc["reviewer"]=="AI-GPT5.6-SOL"
    assert doc["expertCertification"]=="NO"

    authored=json.loads(AUTHORED.read_text(encoding="utf-8"))["items"]
    derived=json.loads(DERIVED.read_text(encoding="utf-8"))["items"]
    current_answers={x["assetId"]:x["questionSnapshot"]["answerIndex"] for x in authored}
    current_answers.update({x["id"]:x["answerIndex"] for x in derived})
    blind=doc["activeV2Part7"]
    assert blind["count"]==108 and blind["answerMatches"]==108 and blind["answerMismatches"]==0
    assert len(blind["items"])==108
    assert {x["id"] for x in blind["items"]}==set(current_answers)
    for item in blind["items"]:
        assert item["answerMatch"] is True
        assert item["blindAnswerIndex"]==current_answers[item["id"]]

    p1=json.loads(P1.read_text(encoding="utf-8"))
    expected_replacements={x["id"]:x["replacementId"] for x in p1["items"] if x["replacementId"]}
    rr=doc["replacementReview"]
    assert rr["count"]==14 and rr["passCount"]==13 and rr["replacedAgainCount"]==1
    assert len(rr["items"])==14
    assert {x["originalId"]:x["reviewedReplacementId"] for x in rr["items"]}==expected_replacements
    again=[x for x in rr["items"] if x["decision"]=="REPLACED_AGAIN_P3"]
    assert len(again)==1
    assert again[0]["reviewedReplacementId"]=="R-FP1-P5-1528"
    assert again[0]["p3ReplacementId"]=="R-FP3-P5-1528"

    corrections=doc["corrections"]
    assert len(corrections)==4
    assert {x["newId"] for x in corrections}=={
        "R-FP3-P5-1528",
        "R-FP3-FM1-P7-M2-03",
        "R-FP3-FM1-P7-S09-01",
        "R-FP3-FM2-P7-S07-03",
    }

    p3=(CONTENT/"ToeicP3FinalCorrections.ets").read_text(encoding="utf-8")
    exact=[
        "All applicants must identify _____ with a photo ID at reception.",
        "['itself','himself','themselves','ourselves'],2",
        "Which delivery option is available at no charge for this order?",
        "Spend $80 or more online and receive free standard delivery. || My cart total is $92.",
        "Which entrance can employees with active staff badges use after 6 P.M.?",
        "To schedule that collection, customers will be contacted to arrange a convenient pickup time.",
        "if (id==='R-FM1-P7-M2-03') return 'R-FP3-FM1-P7-M2-03';",
        "if (id==='R-FM1-P7-S09-01') return 'R-FP3-FM1-P7-S09-01';",
        "if (id==='R-FM2-P7-S07-03') return 'R-FP3-FM2-P7-S07-03';",
    ]
    for token in exact:
        assert token in p3, f"P3 correction drift: {token}"

    preset=(CONTENT/"PresetToeicContent.ets").read_text(encoding="utf-8")
    assert "import { ToeicP3FinalCorrections } from './ToeicP3FinalCorrections';" in preset
    assert ".concat(ToeicP3FinalCorrections.questions())" in preset
    assert "if (id==='R-FP1-P5-1528') return 'R-FP3-P5-1528';" in preset
    assert "return ToeicP3FinalCorrections.activePart7Id(id);" in preset
    for archived in (
        "R-FP1-P5-1528","R-FM1-P7-M2-03",
        "R-FM1-P7-S09-01","R-FM2-P7-S07-03",
    ):
        assert f"question.id==='{archived}'" in preset, f"{archived}: must be excluded from new live queues"
    assert "active=ToeicMockPart7EvidenceRevisionContent.activeId(id);" in preset
    assert "active=ToeicP3FinalCorrections.activePart7Id(active);" in preset
    assert "static readingGroupValidationQuestions(" in preset
    assert "new ToeicReadingGroup('FM1-G2',[" in p3
    assert "'R-FP3-FM1-P7-M2-03'" in p3

    service=(ROOT/"entry/src/main/ets/toeic/application/ToeicReadingGroupService.ets").read_text(encoding="utf-8")
    assert "let compatibleIds:string[]=group.questionIds.slice();" in service
    assert "active=ToeicMockPart7EvidenceRevisionContent.activeId(id);" in service
    assert "active=ToeicP3FinalCorrections.activePart7Id(active);" in service
    assert "compatibleIds.indexOf(question.id)>=0" in service

    translations=(CONTENT/"ToeicQuestionTranslationCatalog.ets").read_text(encoding="utf-8")
    for id in (
        "R-FP3-P5-1528","R-FP3-FM1-P7-M2-03",
        "R-FP3-FM1-P7-S09-01","R-FP3-FM2-P7-S07-03",
    ):
        assert f"questionId==='{id}'" in translations, f"{id}: P3 translation missing"

    scan=doc["semanticBoundaryScan"]
    assert scan["outcome"]=="NO_ADDITIONAL_SYSTEMIC_DEFECTS_AFTER_FOUR_P3_PRECISION_FIXES"
    assert set(scan["terms"])=={
        "by","before","until","through","within","no later than","over",
        "at least","up to","unless","except","only","not","may","must","can",
    }

    samples=doc["stratifiedSamples"]
    expected={"vocabulary":30,"translations":30,"sentenceDrills":15,"ordinaryPart5Part6":30}
    for name,count in expected.items():
        assert samples[name]["count"]==count
        assert len(samples[name]["ids"])==count
        assert len(set(samples[name]["ids"]))==count
        assert samples[name]["outcome"]=="PASS"

    # Preserve the already-corrected high-risk boundary semantics from P2.
    week1=(CONTENT/"ToeicQuestionTranslationWeekOneCatalog.ets").read_text(encoding="utf-8")
    week2=(CONTENT/"ToeicQuestionTranslationWeekTwoCatalog.ets").read_text(encoding="utf-8")
    assert "最迟于周五（含当天）_____培训的员工将获得证书。" in week1
    assert "订单金额超过100美元可免标准运费。" in week2
    assert "Jordan 最迟能于11月1日开始工作（含当天）" in week2

    assert doc["conclusion"]=="P3_COMPLETE_INCREMENTAL_REVIEW_ONLY_AFTER_THIS_POINT"
    print(
        "TOEIC_ISSUE519_P3_FINAL_PASS "
        "active_v2_part7=108 blind_match=108 mismatch=0 "
        "replacements=14 pass=13 replaced_again=1 corrections=4 "
        "vocab_sample=30 translation_sample=30 drill_sample=15 p5p6_sample=30 "
        "reviewer=AI-GPT5.6-SOL expert_certification=NO"
    )

if __name__=="__main__":
    validate()
