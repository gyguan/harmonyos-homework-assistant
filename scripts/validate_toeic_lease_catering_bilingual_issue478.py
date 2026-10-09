#!/usr/bin/env python3
"""Issue #478: lease-inclusive deadlines and catering charged-person semantics.

Read the actual published Part 7 English groups, 10 learner-facing translation
records, lease answer explanation, and AI review ledgers. This is a bounded
semantic regression, not expert certification of the other 211 translations.
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
LEASE_SOURCE = CONTENT / "ToeicExtraReadingBatchFour.ets"
CATERING_SOURCE = CONTENT / "ToeicExtraReadingBatchSix.ets"
APPROVALS = ROOT / "docs/product/toeic-editorial-approvals.json"
AI_FIRST = ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json"
AI_SECOND = ROOT / "docs/product/toeic-remaining-content-review-2026-10-08.json"
SHARED = ROOT / "docs/product/toeic-issue478-shared-part7-first-pass-65.json"

LEASE_SENTENCE = "如果最迟于8月15日（含当天）签署协议，我们可以将租期延至9月30日。"
LEASE_OLD = "如果在8月15日前签署协议，我们可以将租期延至9月30日。"
CATERING_SENTENCE = "咖啡服务按实际享用咖啡的参会者每人4美元收费，盒装午餐每份8美元。"
CATERING_OLD = "咖啡服务按每人4美元收费，盒装午餐每份8美元。"
LEASE_EXPLANATION = "物业回复写明续租协议最迟应于8月15日（含当天）签署。"


def require(ok: bool, detail: str) -> None:
    if not ok:
        raise AssertionError("TOEIC_ISSUE478_LEASE_CATERING_FAIL: " + detail)


def read_group(path: Path, group_id: str) -> tuple[dict, list[dict]]:
    source = path.read_text(encoding="utf-8")
    groups = {
        match[1]: {"ids": json.loads(match[2]), "docs": json.loads(match[3])}
        for match in GROUP_RE.finditer(source)
    }
    require(group_id in groups, f"{group_id}: reading documents missing")
    questions = []
    for match in QUESTION_RE.finditer(source):
        row = match.groupdict()
        if row["group"] != group_id:
            continue
        for name in ("stem", "options", "explanation", "evidence", "paraphrase"):
            row[name] = json.loads(row[name])
        row["answer"] = int(row["answer"])
        row["seconds"] = int(row["seconds"])
        questions.append(row)
    group = groups[group_id]
    require(len(group["ids"]) == len(questions) == 5,
            f"{group_id}: expected five published source questions")
    return group, questions


def check(trans: dict, questions: dict, approved: dict, first: dict,
          second: dict, shared: dict) -> None:
    require(len(trans) == 221, "all 221 translated questions required")
    for prefix, positive, negative in (
        ("LEASE", LEASE_SENTENCE, LEASE_OLD),
        ("CATERING", CATERING_SENTENCE, CATERING_OLD),
    ):
        passages = set()
        for index in range(1, 6):
            qid = f"R-P7-{prefix}-{index:02d}"
            require(qid in trans and qid in questions, f"{qid}: source missing")
            passage, _, translated_options = trans[qid]
            require(isinstance(passage, str) and positive in passage,
                    f"{qid}: semantic boundary/denominator missing")
            require(negative not in passage, f"{qid}: stale Chinese source")
            require(len(translated_options) == 4 and len(questions[qid].choices) == 4,
                    f"{qid}: options changed")
            passages.add(passage)
        require(len(passages) == 1, f"{prefix}: inconsistent translated article")

    lease = questions["R-P7-LEASE-04"]
    require(lease.version == 2, "R-P7-LEASE-04: published correction needs v2")
    require(lease.answer == 3 and lease.choices[3] == "August 15",
            "R-P7-LEASE-04: canonical English answer changed")
    require(lease.explanation == LEASE_EXPLANATION,
            "R-P7-LEASE-04: visible answer explanation was not corrected")
    require("by August 15" in lease.evidence,
            "R-P7-LEASE-04: original inclusive evidence changed")

    lease_group, lease_rows = read_group(LEASE_SOURCE, "P7-EX-LEASE")
    catering_group, _ = read_group(CATERING_SOURCE, "P7-EX-CATERING")
    require("if the agreement is signed by August 15" in
            " ".join(lease_group["docs"]),
            "LEASE: 'by Aug 15' English source no longer matches")
    catering = " ".join(catering_group["docs"])
    require("Coffee service costs $4 per attendee served" in catering and
            "Catering: 100 coffee servings and 120 boxed lunches" in catering and
            "Original catering cost: $1,360" in catering,
            "CATERING: English per-served unit and example quantity changed")
    require(100 * 4 + 120 * 8 == 1360,
            "CATERING: first invoice must count 100 coffee servings, not 120 attendees")
    digest = reading_fingerprint("P7-EX-LEASE", lease_group, lease_rows)
    a = approved["readingGroups"]["P7-EX-LEASE"]
    require(a["contentSha256"] == digest and a["reviewer"] == "AI-GPT6" and
            a["reviewMode"] == "AI_EDITORIAL" and a["approvedAt"] == "2026-10-09",
            "LEASE: stale editorial SHA or overstated human review")
    require(first["readingGroups"]["P7-EX-LEASE"]["contentSha256"] == digest and
            first["readingGroups"]["P7-EX-LEASE"]["decision"] == "PASS",
            "LEASE: first AI reading-group ledger is out of sync")
    require(second["readingGroups"]["P7-EX-LEASE"]["contentSha256"] == digest and
            second["readingGroups"]["P7-EX-LEASE"]["decision"] == "PASS_AI_RECHECK",
            "LEASE: second AI review is out of sync")

    notes = [item for item in shared["items"]
             if item["questionSnapshot"]["groupId"] == "P7-EX-LEASE"]
    require(len(notes) == 5 and all(
        note["groupContentSha256"] == digest and
        note["reviewOutcome"] == "AI_FIRST_PASS" and
        note["isExpertCertified"] is False for note in notes),
        "LEASE: five shared Part 7 AI-first-pass fingerprints missing")
    note = next(note for note in notes if note["assetId"] == "R-P7-LEASE-04")
    require(note["questionSnapshot"]["version"] == 2 and
            note["questionSnapshot"]["explanation"] == LEASE_EXPLANATION and
            "8月15日" in note["correctBasis"],
            "LEASE-04: versioned source snapshot is stale")


def validate() -> None:
    trans = collect_translations()
    rows, _ = collect()
    questions = {row.id: row for row in rows}
    approved = json.loads(APPROVALS.read_text(encoding="utf-8"))
    first = json.loads(AI_FIRST.read_text(encoding="utf-8"))
    second = json.loads(AI_SECOND.read_text(encoding="utf-8"))
    shared = json.loads(SHARED.read_text(encoding="utf-8"))
    check(trans, questions, approved, first, second, shared)

    # Two true source-text corruption probes; all five entries in each group
    # must remain consistent with their real English article and with each other.
    for qid, required, obsolete in (
        ("R-P7-LEASE-01", LEASE_SENTENCE, LEASE_OLD),
        ("R-P7-CATERING-03", CATERING_SENTENCE, CATERING_OLD),
    ):
        corrupted = deepcopy(trans)
        passage, stem, options = corrupted[qid]
        corrupted[qid] = (passage.replace(required, obsolete), stem, options)
        try:
            check(corrupted, questions, approved, first, second, shared)
        except AssertionError as error:
            require(qid in str(error), f"{qid}: wrong negative-control reason")
        else:
            raise AssertionError(f"{qid}: stale Chinese passage incorrectly passed")

    bad_question = deepcopy(questions)
    bad_question["R-P7-LEASE-04"].version = 1
    try:
        check(trans, bad_question, approved, first, second, shared)
    except AssertionError as error:
        require("LEASE-04" in str(error), "version negative-control wrong reason")
    else:
        raise AssertionError("LEASE-04: published v1 incorrectly accepted")

    bad_approval = deepcopy(approved)
    bad_approval["readingGroups"]["P7-EX-LEASE"]["contentSha256"] = "0" * 64
    try:
        check(trans, questions, bad_approval, first, second, shared)
    except AssertionError as error:
        require("editorial SHA" in str(error), "approval negative wrong reason")
    else:
        raise AssertionError("LEASE: fabricated editorial approval accepted")

    bad_shared = deepcopy(shared)
    next(item for item in bad_shared["items"]
         if item["assetId"] == "R-P7-LEASE-02")["groupContentSha256"] = "0" * 64
    try:
        check(trans, questions, approved, first, second, bad_shared)
    except AssertionError as error:
        require("five shared" in str(error), "shared review negative wrong reason")
    else:
        raise AssertionError("LEASE: stale shared Part7 review accepted")

    bad_explanation = deepcopy(questions)
    bad_explanation["R-P7-LEASE-04"].explanation = (
        "物业回复写明8月15日前签署续租协议。")
    try:
        check(trans, bad_explanation, approved, first, second, shared)
    except AssertionError as error:
        require("LEASE-04" in str(error), "explanation negative wrong reason")
    else:
        raise AssertionError("LEASE: old answer explanation accepted")

    print("TOEIC_ISSUE478_LEASE_CATERING_PASS translations_total=221 "
          "shared_translations_checked=10 corrected_groups=2 "
          "versioned_explanation=R-P7-LEASE-04-v2 "
          "negative_checks=6 expert_certification=NO")


if __name__ == "__main__":
    validate()
