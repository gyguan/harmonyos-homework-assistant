#!/usr/bin/env python3
"""Issue #478: do not infer venue request receipt from an email's date.

Source-bound review of a published cross-document Part 7 question, its real
Chinese option/explanation and original AI editorial snapshots. Does not
certify all TOEIC content or simulate HarmonyOS device compilation.
"""
from __future__ import annotations

from copy import deepcopy
import ast
import json
from pathlib import Path

from export_toeic_review_pack import GROUP_RE, QUESTION_RE
from toeic_review_integrity import reading_fingerprint
from validate_toeic_question_quality import collect
from validate_toeic_translation_coverage import CONTENT, collect_translations

ROOT = Path(__file__).resolve().parents[1]
SOURCE = CONTENT / "ToeicExtraReadingContent.ets"
APPROVED = ROOT / "docs/product/toeic-editorial-approvals.json"
AI_REVIEW = ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json"
SHARED = ROOT / "docs/product/toeic-issue478-shared-part7-first-pass-65.json"
GROUP = "P7-EX-VENUE"
QID = "R-P7-VENUE-05"
STEM = "What is supported about the room-change request by the two documents?"
OPTIONS = [
    "The coordinator approved Cedar Hall on September 10",
    "The request was received after September 12",
    "The email is dated September 10, but no receipt date is stated",
    "The room change adds no rental charge",
]
EXPLANATION = (
    "指南要求换厅请求最迟于9月12日送达协调员，但9月10日只是邮件标注日期，"
    "材料未给出实际送达或协调员确认收到的时间，不能断言已满足送达截止日。"
)
EVIDENCE = (
    "Requests to change rooms must reach the venue coordinator by September 12"
    " || DOCUMENT 2 — EMAIL, SEPTEMBER 10"
)
ZH_STEM = "综合预订指南和邮件，关于换厅申请，哪项说法有资料支持？"
ZH_OPTIONS = [
    "协调员在9月10日批准使用雪松厅",
    "协调员在9月12日之后才收到申请",
    "邮件标注日期为9月10日，但材料未注明协调员的收件日期",
    "换厅不会增加租金",
]


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise AssertionError("TOEIC_ISSUE478_RECEIPT_FAIL: " + reason)


def read_source() -> tuple[dict, list[dict]]:
    content = SOURCE.read_text(encoding="utf-8")
    matches = {
        m[1]: {"ids": json.loads(m[2]), "docs": json.loads(m[3])}
        for m in GROUP_RE.finditer(content)
    }
    require(GROUP in matches, "missing actual published venue group")
    source_rows = []
    for m in QUESTION_RE.finditer(content):
        row = m.groupdict()
        if row["group"] != GROUP:
            continue
        for field in ("stem", "options", "explanation", "evidence", "paraphrase"):
            row[field] = json.loads(row[field])
        row["answer"] = int(row["answer"])
        row["seconds"] = int(row["seconds"])
        source_rows.append(row)
    group = matches[GROUP]
    require(len(group["docs"]) == 2 and len(group["ids"]) ==
            len(source_rows) == 5, "venue source must contain 2 documents/5 questions")
    return group, source_rows


def resolved_venue_passage() -> str:
    """Resolve the actual runtime article, not the coverage parser's variable name."""
    source = (CONTENT / "ToeicQuestionTranslationSupplementaryCatalog.ets").read_text(
        encoding="utf-8")
    lines = [line.strip() for line in source.splitlines()
             if line.strip().startswith("let venuePassage:string=")]
    require(len(lines) == 1 and lines[0].endswith('";'),
            "expected exactly one literal runtime VENUE article")
    literal = lines[0].split("=", 1)[1][:-1]
    return ast.literal_eval(literal)


def check(trans: dict, questions: dict, group: dict, source_rows: list[dict],
          approved: dict, ai: dict, shared: dict) -> None:
    require(len(trans) == 221, "221 unique translated questions required")
    require(QID in trans and QID in questions, "venue question/translation missing")
    guide, email = group["docs"]
    require("Requests to change rooms must reach the venue coordinator by September 12"
            in guide, "deadline must refer to receipt, not mere dispatch")
    require("Switching from Maple Room to Cedar Hall adds $160" in guide,
            "positive change charge must remain in the evidence")
    require("DOCUMENT 2 — EMAIL, SEPTEMBER 10" in email and
            "we would like to move to Cedar Hall" in email,
            "request document and email date changed")
    require("received" not in email.lower() and
            "confirmed receipt" not in email.lower(),
            "new document may now prove receipt: re-review the answer")
    q = questions[QID]
    source = next((r for r in source_rows if r["id"] == QID), None)
    require(source is not None and source["skill"] == "CROSS_DOCUMENT" and
            source["answer"] == 2, "must retain source question's cross-document answer")
    require(q.version == 2, "changed published question must be v2")
    require(q.stem == source["stem"] == STEM,
            "English stem must ask what the two documents establish")
    require(q.choices == source["options"] == OPTIONS,
            "English distractors must not assert that an email date proves receipt")
    require(q.explanation == source["explanation"] == EXPLANATION,
            "visible explanation must say the coordinator receipt date is unknown")
    require(q.evidence == source["evidence"] == EVIDENCE,
            "published evidence must distinguish deadline and email date")

    passage_ref, zh_stem, zh_options = trans[QID]
    require(passage_ref == "venuePassage",
            "published VENUE-05 must reference the actual shared Chinese article")
    passage = resolved_venue_passage()
    require("最迟应于9月12日送达场地协调员" in passage and
            "9月10日的邮件" in passage,
            "real Chinese article must preserve delivery condition and email date")
    require(zh_stem == ZH_STEM and zh_options == ZH_OPTIONS,
            "Chinese stem/options must not infer venue receipt")
    for index in range(1, 6):
        ident = f"R-P7-VENUE-{index:02d}"
        require(ident in trans and trans[ident][0] == passage_ref,
                f"{ident}: shared VENUE translated article reference mismatch")

    digest = reading_fingerprint(GROUP, group, source_rows)
    approval = approved["readingGroups"][GROUP]
    require(approval["contentSha256"] == digest and
            approval["reviewMode"] == "AI_EDITORIAL" and
            approval["reviewer"] == "AI-GPT6" and
            approval["approvedAt"] == "2026-10-09",
            "source SHA or AI-only approval provenance mismatch")
    first = ai["readingGroups"][GROUP]
    match = next((r for r in first["questions"] if r["id"] == QID), None)
    require(first["contentSha256"] == digest and first["decision"] == "PASS" and
            match is not None and match["answerIndex"] == 2 and
            match["skill"] == "CROSS_DOCUMENT",
            "AI first review source/answer mismatch")
    records = [n for n in shared["items"]
               if n["questionSnapshot"]["groupId"] == GROUP]
    require(len(records) == 5 and all(
        n["groupContentSha256"] == digest and
        n["reviewOutcome"] == "AI_FIRST_PASS" and
        n["isExpertCertified"] is False for n in records),
        "five shared source AI first-pass SHA snapshots must agree")
    note = next((n for n in records if n["assetId"] == QID), None)
    require(note is not None and note["questionSnapshot"] == {
        "id": QID,
        "sourceFile": "ToeicExtraReadingContent.ets",
        "groupId": GROUP,
        "version": 2,
        "stem": STEM,
        "options": OPTIONS,
        "answerIndex": 2,
        "explanation": EXPLANATION,
        "evidence": EVIDENCE,
    }, "v2 correct-answer review snapshot is stale")
    require("缺少协调员收件日期" in note["correctBasis"],
            "AI answer justification must not invent confirmed receipt")


def negative(test, message: str) -> None:
    try:
        test()
    except AssertionError:
        return
    raise AssertionError("TOEIC_ISSUE478_RECEIPT_FAIL: accepted negative " + message)


def validate() -> None:
    group, rows = read_source()
    trans = collect_translations()
    published, _ = collect()
    questions = {q.id: q for q in published}
    approved = json.loads(APPROVED.read_text(encoding="utf-8"))
    first = json.loads(AI_REVIEW.read_text(encoding="utf-8"))
    shared = json.loads(SHARED.read_text(encoding="utf-8"))
    check(trans, questions, group, rows, approved, first, shared)

    def test(t=trans, q=questions, g=group, a=approved, ai=first, sh=shared):
        check(t, q, g, rows, a, ai, sh)

    old_stem = deepcopy(questions)
    old_stem[QID].stem = "Was the request for a different room sent by the stated deadline?"
    negative(lambda: test(q=old_stem), "old send/receive English inference")

    old_chinese = deepcopy(trans)
    passage, _, answers = old_chinese[QID]
    old_chinese[QID] = (passage, "更换房间的请求是否在规定截止日期前发出？", answers)
    negative(lambda: test(t=old_chinese), "old Chinese receipt inference")

    old_answer = deepcopy(trans)
    article, stem, choices = old_answer[QID]
    old_answer[QID] = (article, stem,
                        [*choices[:2], "是，邮件于9月10日发出", choices[3]])
    negative(lambda: test(t=old_answer), "old Chinese answer")

    v1 = deepcopy(questions)
    v1[QID].version = 1
    negative(lambda: test(q=v1), "old published version")

    expired_approval = deepcopy(approved)
    expired_approval["readingGroups"][GROUP]["contentSha256"] = "0" * 64
    negative(lambda: test(a=expired_approval), "forged editorial SHA")

    stale_review = deepcopy(shared)
    next(n for n in stale_review["items"] if n["assetId"] == QID)[
        "questionSnapshot"]["version"] = 1
    negative(lambda: test(sh=stale_review), "outdated shared review")

    fabricated_receipt = deepcopy(group)
    fabricated_receipt["docs"][1] += "\nVenue coordinator confirmed receipt on September 10."
    negative(lambda: test(g=fabricated_receipt), "source now confirms receipt")

    print("TOEIC_ISSUE478_RECEIPT_PASS venue_questions=5 "
          "corrected_published_question=R-P7-VENUE-05-v2 "
          "source_translations=221 negative_checks=7 "
          "human_ETS_certification=NO")


if __name__ == "__main__":
    validate()
