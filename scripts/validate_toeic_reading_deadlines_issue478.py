#!/usr/bin/env python3
"""Issue #478: learner-facing inclusive by/through deadline translation audit.

Validates 15 published hidden translation assets sharing three English reading
passages and the answer explanation for R-P7-CATERING-04. This is targeted
semantic evidence, not full human certification of all 221 translations.
"""
from __future__ import annotations

from copy import deepcopy
import json
import re

from export_toeic_review_pack import GROUP_RE, QUESTION_RE
from toeic_review_integrity import reading_fingerprint
from validate_toeic_translation_coverage import CONTENT, collect_translations
from validate_toeic_question_quality import collect
from validate_toeic_bilingual_semantics_issue478 import check_translations as check_prior_translations

CATALOG = CONTENT / "ToeicQuestionTranslationSupplementaryCatalog.ets"
CATALOG_CATERING = CONTENT / "ToeicQuestionTranslationDay18And20Catalog.ets"
EN_DELIVERY = CONTENT / "ToeicExtraReadingContent.ets"
EN_FILTER = CONTENT / "ToeicExtraReadingBatchTwo.ets"
EN_CATERING = CONTENT / "ToeicExtraReadingBatchSix.ets"
APPROVALS = CONTENT.parents[5] / "docs/product/toeic-editorial-approvals.json"
AI_REVIEW = CONTENT.parents[5] / "docs/product/toeic-ai-editorial-review-2026-10-08.json"
SECOND = CONTENT.parents[5] / "docs/product/toeic-remaining-content-review-2026-10-08.json"

GROUPS = {
    "DELIVERY": ("deliveryPassage",
                 "加急升级申请最迟须于10月10日下午4点（含该时刻）提出。",
                 "加急升级必须在10月10日下午4点前提出。"),
    "FILTER": ("filterPassage",
               "如果余货最迟于10月10日（含当天）到达，原发票可以保持不变。",
               "如果余货于10月10日前到达，原发票可以保持不变。"),
    "CATERING": (None,
                 "餐饮订单可在10月8日下午5点及之前修改（含截止时刻）。",
                 "餐饮订单最迟可在10月8日下午5点前修改。"),
}


def require(ok: bool, msg: str) -> None:
    if not ok:
        raise AssertionError("TOEIC_ISSUE478_DEADLINE_FAIL: " + msg)


def shared_passage(source: str, variable: str) -> str:
    m = re.search(r"let " + variable +
                  r':string=("(?:[^"\\]|\\.)*");', source)
    require(m is not None, f"missing {variable} runtime passage")
    return json.loads(m[1])


def effective_passages(translations: dict) -> dict[str, str]:
    source = CATALOG.read_text(encoding="utf-8")
    resolved = {}
    for group, (variable, _, _) in GROUPS.items():
        if variable:
            text = shared_passage(source, variable)
            for n in range(1, 6):
                id = f"R-P7-{group}-{n:02d}"
                require(translations[id][0] == variable,
                        f"{id}: translation no longer references shared passage")
                resolved[id] = text
        else:
            for n in range(1, 6):
                id = f"R-P7-{group}-{n:02d}"
                resolved[id] = translations[id][0]
    return resolved


def reading_group() -> tuple[dict, list[dict]]:
    source = EN_CATERING.read_text(encoding="utf-8")
    groups = {}
    for m in GROUP_RE.finditer(source):
        groups[m[1]] = {"ids": json.loads(m[2]), "docs": json.loads(m[3])}
    require("P7-EX-CATERING" in groups, "missing actual published catering group")
    group = groups["P7-EX-CATERING"]
    questions = []
    for m in QUESTION_RE.finditer(source):
        d = m.groupdict()
        if d["group"] != "P7-EX-CATERING":
            continue
        for name in ("stem", "options", "explanation", "evidence", "paraphrase"):
            d[name] = json.loads(d[name])
        d["answer"] = int(d["answer"])
        d["seconds"] = int(d["seconds"])
        questions.append(d)
    require(len(questions) == 5 and len(group["docs"]) == 3,
            "actual catering question/document set must be complete")
    return group, questions


def check(source_passages: dict, trans: dict, questions: dict,
          explanations: dict, approval: dict, first: dict, second: dict) -> None:
    require(len(trans) == 221, "all 221 translation records required")
    require(len(source_passages) == 15, "15 group translations required")
    for group, (_, desired, outdated) in GROUPS.items():
        ids = [f"R-P7-{group}-{n:02d}" for n in range(1, 6)]
        passages = {source_passages[id] for id in ids}
        require(len(passages) == 1, f"{group}: inconsistent shared Chinese passage")
        for id in ids:
            require(desired in source_passages[id],
                    f"{id}: inclusive deadline missing")
            require(outdated not in source_passages[id],
                    f"{id}: obsolete before/deadline wording remains")
            require(id in questions, f"{id}: orphan translation")
            require(len(trans[id][2]) == len(questions[id].choices),
                    f"{id}: changed number of translated answers")

    # The filter correct answer and actual learner-visible explanation must
    # make the inclusivity unambiguous, not only the source passage text.
    require("余货保证最迟于10月10日送达" in trans["R-P7-FILTER-04"][2][1],
            "R-P7-FILTER-04: correct option still incorrectly excludes Oct 10")
    require("余货保证在期限前送达" not in trans["R-P7-FILTER-04"][2][1],
            "R-P7-FILTER-04: old option persisted")
    require(questions["R-P7-CATERING-04"].version == 2,
            "R-P7-CATERING-04: changed published explanation must bump version to 2")
    expl = explanations["R-P7-CATERING-04"]
    require("最迟在10月8日17点（含该时刻）" in expl,
            "R-P7-CATERING-04: visible answer explanation still excludes cutoff")
    require("10月8日17点前可更改" not in expl,
            "R-P7-CATERING-04: old exclusive explanation persisted")

    group, question_rows = reading_group()
    digest = reading_fingerprint("P7-EX-CATERING", group, question_rows)
    require(approval["readingGroups"]["P7-EX-CATERING"]["contentSha256"] == digest,
            "catering reading-group approval fingerprint is stale")
    require(approval["readingGroups"]["P7-EX-CATERING"]["reviewMode"] == "AI_EDITORIAL" and
            approval["readingGroups"]["P7-EX-CATERING"]["approvedAt"] == "2026-10-09",
            "review provenance must remain AI-only and accurately dated")
    require(first["readingGroups"]["P7-EX-CATERING"]["contentSha256"] == digest,
            "first AI group audit snapshot not rebound")
    require(second["readingGroups"]["P7-EX-CATERING"]["contentSha256"] == digest and
            second["readingGroups"]["P7-EX-CATERING"]["decision"] == "PASS_AI_RECHECK",
            "second AI group audit snapshot not rebound")


def validate() -> None:
    trans = collect_translations()
    rows, _ = collect()
    questions = {q.id: q for q in rows}
    check_prior_translations(trans, questions)
    supplement = CATALOG.read_text(encoding="utf-8")
    source_deliver = EN_DELIVERY.read_text(encoding="utf-8")
    source_filter = EN_FILTER.read_text(encoding="utf-8")
    source_catering = EN_CATERING.read_text(encoding="utf-8")
    require("must be requested by 4 P.M. on October 10" in source_deliver,
            "express upgrade English source changed")
    require("if the balance arrives by October 10" in source_filter,
            "filter English source changed")
    require("may be changed through October 8 at 5 P.M." in source_catering,
            "catering English source changed")
    passages = effective_passages(trans)
    explanations = {id: q.explanation for id, q in questions.items()}
    approvals = json.loads(APPROVALS.read_text(encoding="utf-8"))
    first = json.loads(AI_REVIEW.read_text(encoding="utf-8"))
    second = json.loads(SECOND.read_text(encoding="utf-8"))
    check(passages, trans, questions, explanations, approvals, first, second)

    for group, (_, desired, old) in GROUPS.items():
        corrupt = dict(passages)
        id = f"R-P7-{group}-01"
        corrupt[id] = corrupt[id].replace(desired, old)
        try:
            check(corrupt, trans, questions, explanations, approvals, first, second)
        except AssertionError as ex:
            require(group in str(ex), f"{group}: negative regression wrong reason")
        else:
            raise AssertionError(f"{group}: incorrect cutoff accepted")

    corrupted = deepcopy(trans)
    passage, stem, options = corrupted["R-P7-FILTER-04"]
    options[1] = "余货保证在期限前送达"
    corrupted["R-P7-FILTER-04"] = (passage, stem, options)
    try:
        check(passages, corrupted, questions, explanations, approvals, first, second)
    except AssertionError as ex:
        require("FILTER-04" in str(ex), "filter option negative wrong reason")
    else:
        raise AssertionError("stale filter option accepted")

    corrupt_expl = dict(explanations)
    corrupt_expl["R-P7-CATERING-04"] = "会务条款规定10月8日17点前可更改。"
    try:
        check(passages, trans, questions, corrupt_expl, approvals, first, second)
    except AssertionError as ex:
        require("CATERING-04" in str(ex), "catering explanation negative wrong reason")
    else:
        raise AssertionError("old catering explanation accepted")

    corrupt_approval = deepcopy(approvals)
    corrupt_approval["readingGroups"]["P7-EX-CATERING"]["contentSha256"] = "0" * 64
    try:
        check(passages, trans, questions, explanations, corrupt_approval, first, second)
    except AssertionError as ex:
        require("fingerprint" in str(ex), "approval negative wrong reason")
    else:
        raise AssertionError("forged catering approval accepted")

    print("TOEIC_ISSUE478_DEADLINE_PASS translations_total=221 "
          "shared_translations_fixed=15 translated_option_fixed=1 "
          "answer_explanation_fixed=1 negative_checks=6 "
          "human_ETS_certification=NO")


if __name__ == "__main__":
    validate()
