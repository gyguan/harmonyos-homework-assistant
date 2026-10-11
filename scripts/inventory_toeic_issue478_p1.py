#!/usr/bin/env python3
"""Issue #478 P1 final inventory.

The inventory is source-driven and now binds every original Part5/6 question
and every vocabulary item to the completed AI editorial second-pass ledgers.
It explicitly does not claim human/ETS certification.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from validate_toeic_question_quality import collect
from validate_toeic_vocabulary_examples_issue478 import get_rows, get_supplement
from validate_toeic_vocabulary_dictionary_issue478 import parse_batches
from validate_toeic_translation_coverage import collect_translations

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/"docs/product/toeic-issue478-p1-final-inventory.json"
QREVIEW=ROOT/"docs/product/toeic-issue478-p1-final-question-review-2026-10-09.json"
VREVIEW=ROOT/"docs/product/toeic-issue478-p1-final-vocabulary-review-2026-10-09.json"

def main()->None:
    parser=argparse.ArgumentParser()
    parser.add_argument("--write",action="store_true")
    args=parser.parse_args()
    qdoc=json.loads(QREVIEW.read_text(encoding="utf-8"))
    vdoc=json.loads(VREVIEW.read_text(encoding="utf-8"))
    qreview={x["id"]:x for x in qdoc["items"]}
    vreview={x["id"]:x for x in vdoc["items"]}
    source,_=collect(); translations=collect_translations()
    questions=sorted((q for q in source if q.part in ("PART_5","PART_6")),key=lambda q:q.id)
    assert len(questions)==185 and set(qreview)=={q.id for q in questions}
    words=get_rows();supplements=get_supplement();batches=parse_batches()
    assert len(words)==300 and set(vreview)==set(words)=={f"V-{i:03d}" for i in range(1,301)}
    assert len(batches)==180
    items=[]
    for q in questions:
        review=qreview[q.id]
        assert review["decision"] in ("PASS_AI_SECOND_PASS","ARCHIVED_REPLACED")
        items.append({
            "assetId":q.id,"source":q.source+".ets","version":q.version,"part":q.part,
            "stem":q.stem,"options":q.choices,"correctIndex":q.answer,
            "existingExplanation":q.explanation,"existingEvidence":q.evidence,
            "hasChineseTranslation":q.id in translations,
            "contentReviewStatus":review["decision"],
            "replacementId":review.get("replacementId"),
            "reviewChecks":review["checks"],
        })
    word_items=[]
    for id,(word,meaning,example) in sorted(words.items()):
        review=vreview[id]
        assert review["decision"] in ("PASS_AI_SECOND_PASS","PASS_AFTER_CORRECTION")
        word_items.append({
            "assetId":id,"headword":word,"meaning":meaning,
            "example":example or supplements.get(id,""),
            "isBatchWordWithAIEditorialHash":id in batches,
            "contentReviewStatus":review["decision"],
            "reviewChecks":review["checks"],
        })
    result={
        "issue":478,
        "reviewScope":"original 185 Part5/Part6 and all 300 vocabulary entries",
        "attestation":"AI_EDITORIAL_SECOND_PASS_COMPLETE_NOT_HUMAN_OR_ETS_CERTIFICATION",
        "originalP5P6Count":len(items),"vocabularyCount":len(word_items),
        "originalP5P6":items,"vocabulary":word_items,
    }
    if args.write:OUTPUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("TOEIC_ISSUE478_P1_INVENTORY_PASS original_p5p6=185 vocabulary=300 final_ai_second_pass=COMPLETE human_ETS_certification=NO")

if __name__=="__main__":main()
