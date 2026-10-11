#!/usr/bin/env python3
"""#478: source-bound estimate-vs-served catering review, with negative cases."""
from __future__ import annotations
from copy import deepcopy
import json
from pathlib import Path
from validate_toeic_question_quality import collect
from validate_toeic_translation_coverage import collect_translations

ROOT = Path(__file__).resolve().parents[1]
HASH = "f64086ae61837653d0f72323766a1aefc920ccc7a543443e0ad8186a1125836f"
EXPECTED = {
    "R-P7-CATERING-02": ("Based on the accepted quantities, how much higher is the estimated revised catering cost?",
       "按已接受的135份咖啡及135份盒饭计算，预计订单额为1620美元，比原先1360美元高260美元。咖啡最终实际计费仍取决于接受服务的人数。", 2, 0),
    "R-P7-CATERING-05": ("Assuming all 135 ordered coffee servings are served, what is the estimated total catering charge?",
       "假设135份预订咖啡均已实际提供，则咖啡费为540美元；135份盒饭为1080美元，预计合计1620美元。实际咖啡收费仍取决于接受服务人数。", 2, 1),
}

def require(condition, message):
    if not condition:
        raise AssertionError("TOEIC_CATERING_ESTIMATE_FAIL " + message)

def check(qs, translations, approvals, ai, first, second):
    source = {q.id: q for q in qs}
    for qid, (stem, explanation, version, answer) in EXPECTED.items():
        q = source[qid]
        require(q.stem == stem and q.explanation == explanation and q.version == version and q.answer == answer,
                qid + " actual published question drifted")
    require(approvals["readingGroups"]["P7-EX-CATERING"]["contentSha256"] == HASH, "approval fingerprint")
    require(ai["readingGroups"]["P7-EX-CATERING"]["contentSha256"] == HASH, "AI fingerprint")
    require(second["readingGroups"]["P7-EX-CATERING"]["contentSha256"] == HASH, "second pass fingerprint")
    for note in first["items"]:
        snapshot = note["questionSnapshot"]
        if snapshot["groupId"] != "P7-EX-CATERING":
            continue
        q = source[note["assetId"]]
        require(note["groupContentSha256"] == HASH, "first pass hash " + q.id)
        require(snapshot["stem"] == q.stem and snapshot["explanation"] == q.explanation and
                snapshot["version"] == q.version and snapshot["answerIndex"] == q.answer,
                "stale first pass snapshot " + q.id)
    cn = {
        "R-P7-CATERING-02": "按已接受的预订数量估算，修订后的餐饮费用预计增加多少？",
        "R-P7-CATERING-05": "假设预订的135份咖啡全部实际提供，预计餐饮总费用是多少？",
    }
    for qid, stem in cn.items():
        require(translations[qid][1] == stem, "stale Chinese stem " + qid)
    return source

def validate():
    questions, _ = collect()
    translations = collect_translations()
    load = lambda name: json.loads((ROOT / ("docs/product/" + name)).read_text(encoding="utf-8"))
    approvals = load("toeic-editorial-approvals.json")
    ai = load("toeic-ai-editorial-review-2026-10-08.json")
    first = load("toeic-issue478-shared-part7-first-pass-65.json")
    second = load("toeic-remaining-content-review-2026-10-08.json")
    qs = [q for q in questions if q.group == "P7-EX-CATERING"]
    require(len(qs) == 5, "actual 5 question group")
    source = check(qs, translations, approvals, ai, first, second)
    # Deliberate regressions must fail against source-bound invariants.
    negatives = 0
    for qid, outdated in [
        ("R-P7-CATERING-02", "How much more will the revised catering order cost?"),
        ("R-P7-CATERING-05", "What should the updated invoice show as the total catering charge?"),
    ]:
        q = source[qid]
        prior = q.stem
        q.stem = outdated
        try:
            check(qs, translations, approvals, ai, first, second)
        except AssertionError:
            negatives += 1
        else:
            raise AssertionError("obsolete prompt was accepted " + qid)
        finally:
            q.stem = prior
    bad = deepcopy(first)
    for item in bad["items"]:
        if item["assetId"] == "R-P7-CATERING-05":
            item["questionSnapshot"]["version"] = 1
            break
    try:
        check(qs, translations, approvals, ai, bad, second)
    except AssertionError:
        negatives += 1
    else:
        raise AssertionError("stale version was accepted")
    bad_approvals = deepcopy(approvals)
    bad_approvals["readingGroups"]["P7-EX-CATERING"]["contentSha256"] = "0"*64
    try:
        check(qs, translations, bad_approvals, ai, first, second)
    except AssertionError:
        negatives += 1
    else:
        raise AssertionError("spoofed fingerprint was accepted")
    require(negatives == 4, "negative check count")
    print("TOEIC_CATERING_ESTIMATE_PASS revised_questions=2 negative_checks=4 human_ETS_certification=NO")

if __name__ == "__main__":
    validate()
