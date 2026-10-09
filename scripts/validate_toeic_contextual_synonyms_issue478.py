#!/usr/bin/env python3
"""Issue #478: dictionary-bound corrections to contextual vocabulary paraphrases.

This validates five concrete AI editorial corrections, their source examples,
POS, current US IPA binding and versioned editorial hashes. It is a targeted
check, not independent linguistic certification of all 300 published words.
"""
from __future__ import annotations

from copy import deepcopy
import json
import re

from export_toeic_review_pack import CONTENT, ROOT
from toeic_review_integrity import vocabulary_fingerprint
from validate_toeic_vocabulary_dictionary_issue478 import parse_batches

APPROVALS = ROOT / "docs/product/toeic-editorial-approvals.json"
AI_REVIEW = ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json"
SECOND_PASS = ROOT / "docs/product/toeic-remaining-content-review-2026-10-08.json"

TARGETS = {
    "V-123": {
        "word": "competitive", "pos": "adj.",
        "meaning": "有竞争力的；竞争性的",
        "collocations": ["competitive pricing"],
        "synonyms": ["as good as or better than competing prices"],
        "example": "The vendor offered competitive pricing for bulk purchases.",
        "obsolete": "attractive in price",
    },
    "V-130": {
        "word": "efficient", "pos": "adj.",
        "meaning": "高效的；效率高的",
        "collocations": ["efficient process"],
        "synonyms": ["achieving results without wasting resources"],
        "example": "The new filing system makes the approval process more efficient.",
        "obsolete": "productive",
    },
    "V-144": {
        "word": "respondent", "pos": "n.",
        "meaning": "问卷受访者；答复者",
        "collocations": ["survey respondent"],
        "synonyms": ["person answering survey questions"],
        "example": "Most survey respondents preferred evening appointments.",
        "obsolete": "participant",
    },
    "V-146": {
        "word": "subscription", "pos": "n.",
        "meaning": "订阅；订阅费",
        "collocations": ["annual subscription"],
        "synonyms": ["regular payment for access to a product or service"],
        "example": "The annual subscription includes access to technical support.",
        "obsolete": "membership plan",
    },
    "V-255": {
        "word": "credential", "pos": "n.",
        "meaning": "登录凭据；身份或资格证明",
        "collocations": ["login credentials"],
        "synonyms": ["authentication information"],
        "example": "Do not share your login credentials with other users.",
        "obsolete": "proof of identity",
    },
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError("TOEIC_ISSUE478_CONTEXTUAL_FAIL: " + message)


def check(rows: dict, ipa: dict, approvals: dict, first: dict, second: dict) -> None:
    require(len(rows) == 180, "expected 180 complete batch records")
    require(len(ipa) == 300, "expected 300 current pronunciation records")
    for key, expected in TARGETS.items():
        row = rows[key]
        for field in ("word", "pos", "meaning", "collocations", "synonyms", "example"):
            require(row[field] == expected[field],
                    f"{key}: dictionary-corrected {field} drift")
        require(expected["obsolete"] not in row["synonyms"],
                f"{key}: obsolete overbroad synonym reintroduced")
        require(row["status"] == "PUBLISHED", f"{key}: not published")
        require(row["example"].endswith("."), f"{key}: incomplete example")
        require(ipa[key].startswith("/"), f"{key}: missing IPA")
        digest = vocabulary_fingerprint(row, ipa[key])
        approval = approvals["vocabulary"][key]
        require(approval["contentSha256"] == digest,
                f"{key}: exact vocabulary fingerprint stale")
        require(approval["reviewer"] == "AI-GPT6" and
                approval["reviewMode"] == "AI_EDITORIAL" and
                approval["approvedAt"] == "2026-10-09",
                f"{key}: source review provenance must remain explicit AI-only")
        review = first["vocabulary"][key]
        require(review["contentSha256"] == digest and
                review["updatedAt"] == "2026-10-09" and
                review["decision"] == "PASS",
                f"{key}: first-pass and current corrections disagree")
        if key == "V-255":
            backcheck = second["vocabulary"][key]
            require(backcheck["meaning"] == row["meaning"] and
                    backcheck["synonyms"] == row["synonyms"] and
                    backcheck["contentSha256"] == digest and
                    backcheck["decision"] == "PASS_AI_RECHECK",
                    "V-255: secondary AI review must track revised meaning")


def validate() -> None:
    rows = parse_batches()
    source = (CONTENT / "ToeicPronunciationCatalog.ets").read_text(encoding="utf-8")
    ipa_rows = re.findall(
        r"new ToeicPronunciationEntry\\('(V-\\d+)','([^']+)'", source)
    ipa = dict(ipa_rows)
    require(len(ipa_rows) == len(ipa) == 300, "duplicate or missing pronunciation")
    approvals = json.loads(APPROVALS.read_text(encoding="utf-8"))
    first = json.loads(AI_REVIEW.read_text(encoding="utf-8"))
    second = json.loads(SECOND_PASS.read_text(encoding="utf-8"))
    check(rows, ipa, approvals, first, second)
    # Negative tests are real semantic/persistence corruption simulations.
    altered = deepcopy(rows)
    altered["V-130"]["synonyms"] = ["productive"]
    try:
        check(altered, ipa, approvals, first, second)
    except AssertionError as ex:
        require("V-130" in str(ex), "negative productive-paraphrase check wrong reason")
    else:
        raise AssertionError("TOEIC_ISSUE478_CONTEXTUAL_FAIL: old synonym accepted")

    altered = deepcopy(rows)
    altered["V-255"]["meaning"] = "身份凭证；资格证书"
    try:
        check(altered, ipa, approvals, first, second)
    except AssertionError as ex:
        require("V-255" in str(ex), "negative login credential check wrong reason")
    else:
        raise AssertionError("TOEIC_ISSUE478_CONTEXTUAL_FAIL: old meaning accepted")

    altered_approvals = deepcopy(approvals)
    altered_approvals["vocabulary"]["V-144"]["contentSha256"] = "0" * 64
    try:
        check(rows, ipa, altered_approvals, first, second)
    except AssertionError as ex:
        require("V-144" in str(ex), "negative stale hash check wrong reason")
    else:
        raise AssertionError("TOEIC_ISSUE478_CONTEXTUAL_FAIL: stale approval accepted")

    print("TOEIC_ISSUE478_CONTEXTUAL_PASS batch_words=180 corrected_words=5 "
          "stable_word_ids=5 documented_examples=5 negative_checks=3 "
          "human_ETS_certification=NO")


if __name__ == "__main__":
    validate()
