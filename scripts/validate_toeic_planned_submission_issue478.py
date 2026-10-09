#!/usr/bin/env python3
"""Issue #478: distinguish planned from completed submission in Part 7.

Validate the actual English source, learner-visible Chinese answer help,
published question version and four AI review evidence snapshots. Negative
tests reject 6 stale/incorrect states. This does not certify every TOEIC item.
"""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path

from export_toeic_review_pack import GROUP_RE, QUESTION_RE
from toeic_review_integrity import reading_fingerprint
from validate_toeic_question_quality import collect
from validate_toeic_translation_coverage import CONTENT, collect_translations

ROOT = Path(__file__).resolve().parents[1]
SOURCE = CONTENT / "ToeicExtraReadingBatchFour.ets"
APPROVED = ROOT / "docs/product/toeic-editorial-approvals.json"
FIRST = ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json"
SECOND = ROOT / "docs/product/toeic-remaining-content-review-2026-10-08.json"
SHARED = ROOT / "docs/product/toeic-issue478-shared-part7-first-pass-65.json"
QID = "R-P7-TRAINING-04"
GROUP = "P7-EX-TRAINING"
STEM = "If Daniel submits his reimbursement request on June 2, will it meet the deadline?"
OPTION = "Yes, June 2 is the tenth calendar day after May 23"
EXPLANATION = (
    "Daniel于5月23日完成课程，6月2日是此后第10个自然日。"
    "邮件表示他当日尚未提交申请，因此只有在6月2日当天提交才符合期限，不能当作已经提交。"
)
EVIDENCE = (
    "within 10 calendar days after course completion || "
    "I completed the approved project-management course on May 23 || "
    "EMPLOYEE CLAIM MESSAGE, JUNE 2 || before I submit the form today"
)
ZH_STEM = "如果Daniel于6月2日提交报销申请，是否符合规定的期限？"
ZH_OPTION = "符合，6月2日正好是结业后的第10个自然日"


def require(condition: bool, detail: str) -> None:
    if not condition:
        raise AssertionError("TOEIC_ISSUE478_SUBMISSION_FAIL: " + detail)


def published_group() -> tuple[dict, list[dict]]:
    src = SOURCE.read_text(encoding="utf-8")
    groups = {
        match[1]: {"ids": json.loads(match[2]), "docs": json.loads(match[3])}
        for match in GROUP_RE.finditer(src)
    }
    require(GROUP in groups, "published training group missing")
    group = groups[GROUP]
    rows = []
    for match in QUESTION_RE.finditer(src):
        row = match.groupdict()
        if row["group"] != GROUP:
            continue
        for field in ("stem", "options", "explanation", "evidence", "paraphrase"):
            row[field] = json.loads(row[field])
        row["answer"] = int(row["answer"])
        row["seconds"] = int(row["seconds"])
        rows.append(row)
    require(len(group["docs"]) == 2 and len(rows) == len(group["ids"]) == 5,
            "all two documents and five training questions required")
    return group, rows


def check(trans: dict, questions: dict, group: dict, source_rows: list[dict],
          approvals: dict, first: dict, second: dict, shared: dict) -> None:
    require(len(trans) == 221, "221 existing Chinese translation records required")
    require(QID in questions and QID in trans, "released training question missing")

    docs = "\n".join(group["docs"])
    require("must be submitted within 10 calendar days after course completion" in docs,
            "ten-day submission policy no longer present")
    require("I completed the approved project-management course on May 23" in docs and
            "EMPLOYEE CLAIM MESSAGE, JUNE 2" in docs,
            "course completion date or proposed filing date changed")
    require("before I submit the form today" in docs,
            "the message must state that filing has not yet happened")
    require("scored 88 percent" in docs and "itemized tuition receipt for $260" in docs,
            "other supporting documents accidentally changed")

    source = next((row for row in source_rows if row["id"] == QID), None)
    require(source is not None and source["answer"] == 1,
            "missing original correct answer index")
    q = questions[QID]
    require(q.version == 2, "published question should have version v2")
    require(q.stem == source["stem"] == STEM,
            "English question must describe a conditional June 2 submission")
    require(q.choices == source["options"] and q.choices[1] == OPTION,
            "English correct choice must match the conditional deadline")
    require(q.explanation == source["explanation"] == EXPLANATION,
            "the learner-visible explanation must reject an already-filed claim")
    require(q.evidence == source["evidence"] == EVIDENCE,
            "evidence must include actual future-tense statement")

    passage, stem, options = trans[QID]
    require(isinstance(passage, str) and "请在我今天提交表格前" in passage,
            "Chinese source still needs to convey not-yet-filed intent")
    require(stem == ZH_STEM and options[1] == ZH_OPTION and len(options) == 4,
            "Chinese question and correct option must be conditional")
    for n in range(1, 6):
        ident = f"R-P7-TRAINING-{n:02d}"
        require(ident in trans and trans[ident][0] == passage,
                f"{ident}: a shared Chinese source drifted")

    digest = reading_fingerprint(GROUP, group, source_rows)
    approval = approvals["readingGroups"][GROUP]
    require(approval["contentSha256"] == digest and
            approval["reviewMode"] == "AI_EDITORIAL" and
            approval["reviewer"] == "AI-GPT6" and
            approval["approvedAt"] == "2026-10-09",
            "stale/overclaimed training group editorial approval")
    require(first["readingGroups"][GROUP]["contentSha256"] == digest and
            first["readingGroups"][GROUP]["decision"] == "PASS",
            "first AI group review is stale")
    secondary = second["readingGroups"][GROUP]
    entry = next((r for r in secondary["questions"] if r["id"] == QID), None)
    require(secondary["contentSha256"] == digest and
            secondary["decision"] == "PASS_AI_RECHECK" and entry is not None and
            entry["question"] == STEM and entry["answer"] == OPTION and
            entry["answerIndex"] == 1 and entry["evidence"] == EVIDENCE,
            "second AI review source/correct answer is stale")

    notes = [r for r in shared["items"]
             if r["questionSnapshot"]["groupId"] == GROUP]
    require(len(notes) == 5 and all(
        r["groupContentSha256"] == digest and
        r["reviewOutcome"] == "AI_FIRST_PASS" and
        r["isExpertCertified"] is False for r in notes),
        "shared Part7 5-question AI review hashes must match")
    note = next((r for r in notes if r["assetId"] == QID), None)
    require(note is not None and
            note["questionSnapshot"] == {
                "id": QID,
                "sourceFile": "ToeicExtraReadingBatchFour.ets",
                "groupId": GROUP,
                "version": 2,
                "stem": STEM,
                "options": q.choices,
                "answerIndex": 1,
                "explanation": EXPLANATION,
                "evidence": EVIDENCE,
            },
            "conditional-first-pass snapshot differs")
    # The factual question and explanation must be explicitly conditional:
    require("不能认定已经提交" in note["correctBasis"],
            "review basis must not assert Daniel already filed")


def expect_rejection(action, detail: str) -> None:
    try:
        action()
    except AssertionError:
        return
    raise AssertionError("TOEIC_ISSUE478_SUBMISSION_FAIL: corruption accepted: " + detail)


def validate() -> None:
    trans = collect_translations()
    rows, _ = collect()
    questions = {q.id: q for q in rows}
    group, source_rows = published_group()
    approvals = json.loads(APPROVED.read_text(encoding="utf-8"))
    first = json.loads(FIRST.read_text(encoding="utf-8"))
    second = json.loads(SECOND.read_text(encoding="utf-8"))
    shared = json.loads(SHARED.read_text(encoding="utf-8"))
    check(trans, questions, group, source_rows, approvals, first, second, shared)

    def verify(t=trans, q=questions, a=approvals, f=first, s=second, sh=shared):
        check(t, q, group, source_rows, a, f, s, sh)

    old_english = deepcopy(questions)
    old_english[QID].stem = "Is Daniel submitting the request within the allowed period?"
    expect_rejection(lambda: verify(q=old_english), "ambiguous source stem")

    old_chinese = deepcopy(trans)
    passage, _, options = old_chinese[QID]
    old_chinese[QID] = (passage, "Daniel 是否在允许的期限内提交申请？", options)
    expect_rejection(lambda: verify(t=old_chinese), "nonconditional Chinese stem")

    old_version = deepcopy(questions)
    old_version[QID].version = 1
    expect_rejection(lambda: verify(q=old_version), "old published version")

    old_explanation = deepcopy(questions)
    old_explanation[QID].explanation = "课程结束时间是5月23日，政策期限为结束后10个自然日，6月2日处于截止日。"
    expect_rejection(lambda: verify(q=old_explanation), "old explanation")

    wrong_approval = deepcopy(approvals)
    wrong_approval["readingGroups"][GROUP]["contentSha256"] = "0" * 64
    expect_rejection(lambda: verify(a=wrong_approval), "forged approval hash")

    wrong_snapshot = deepcopy(shared)
    next(r for r in wrong_snapshot["items"] if r["assetId"] == QID)[
        "questionSnapshot"]["version"] = 1
    expect_rejection(lambda: verify(sh=wrong_snapshot), "stale original first pass")

    print("TOEIC_ISSUE478_SUBMISSION_PASS training_group_questions=5 "
          "source_translations_total=221 versioned_question=R-P7-TRAINING-04-v2 "
          "negative_checks=6 human_ETS_certification=NO")


if __name__ == "__main__":
    validate()
