#!/usr/bin/env python3
"""Issue #478: context-preserving source-backed checks for eight TOEIC words.

This checks exact source literals, collocations, example/IPA pairing, approval
SHA, review provenance and 9 intentional regression cases. It does not claim
independent language-expert certification for all 300 words.
"""
from __future__ import annotations

from copy import deepcopy
import json
import re

from export_toeic_review_pack import CONTENT, ROOT
from toeic_review_integrity import vocabulary_fingerprint
from validate_toeic_vocabulary_dictionary_issue478 import parse_batches

APPROVALS = ROOT / "docs/product/toeic-editorial-approvals.json"
FIRST = ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json"
SECOND = ROOT / "docs/product/toeic-remaining-content-review-2026-10-08.json"

TARGETS = {
    "V-124": {
        "word": "bid", "pos": "n.",
        "collocations": ["submit a bid"],
        "synonyms": ["offer to provide goods or work at a stated price"],
        "obsolete": "offer",
        "example": "Three suppliers submitted bids for the maintenance contract.",
    },
    "V-125": {
        "word": "subcontractor", "pos": "n.",
        "collocations": ["hire a subcontractor"],
        "synonyms": ["contractor carrying out part of another contractor's work"],
        "obsolete": "outside contractor",
        "example": "The project manager hired a subcontractor to install the wiring.",
    },
    "V-215": {
        "word": "utilities", "pos": "n. pl.",
        "collocations": ["monthly utilities"],
        "synonyms": ["essential services such as electricity, gas, and water"],
        "obsolete": "water and electricity services",
        "example": "Utilities are billed separately from the office rent.",
    },
    "V-264": {
        "word": "accessibility", "pos": "n.",
        "collocations": ["website accessibility"],
        "synonyms": ["ability of people with disabilities to use a website"],
        "obsolete": "ease of access",
        "example": "The redesign improved website accessibility for keyboard users.",
    },
    "V-276": {
        "word": "shuttle", "pos": "n.",
        "collocations": ["airport shuttle"],
        "synonyms": ["vehicle making regular trips between two places"],
        "obsolete": "transfer bus",
        "example": "A complimentary shuttle runs between the airport and the hotel.",
    },
    "V-277": {
        "word": "commute", "pos": "v.",
        "collocations": ["commute by train"],
        "synonyms": ["travel regularly between home and work"],
        "obsolete": "travel to work",
        "example": "Several employees commute by train to avoid traffic.",
    },
    "V-284": {
        "word": "amenity", "pos": "n.",
        "collocations": ["hotel amenity"],
        "synonyms": ["hotel facility or service that improves comfort"],
        "obsolete": "guest facility",
        "example": "Free wireless internet is one of the hotel's amenities.",
    },
    "V-298": {
        "word": "roster", "pos": "n.",
        "collocations": ["staff roster"],
        "synonyms": ["staff list with assigned duties or shifts"],
        "obsolete": "list of assigned staff",
        "example": "The supervisor updated the staff roster before the weekend shift.",
    },
}


def require(ok: bool, message: str) -> None:
    if not ok:
        raise AssertionError("TOEIC_ISSUE478_DOMAIN_FAIL: " + message)


def check(rows: dict, ipa: dict, approved: dict, first: dict, second: dict) -> None:
    require(len(rows) == 180, "expected 180 published batch rows")
    require(len(ipa) == 300, "expected 300 unique pronunciation entries")
    for key, expected in TARGETS.items():
        row = rows[key]
        for field in ("word", "pos", "collocations", "synonyms", "example"):
            require(row[field] == expected[field],
                    f"{key}: reviewed {field} changed")
        require(row["status"] == "PUBLISHED", f"{key}: published state changed")
        require(expected["obsolete"] not in row["synonyms"],
                f"{key}: overbroad old paraphrase reintroduced")
        require(ipa[key].startswith("/") and ipa[key].count("/") >= 2,
                f"{key}: missing US IPA entry")
        digest = vocabulary_fingerprint(row, ipa[key])
        approval = approved["vocabulary"][key]
        require(approval["contentSha256"] == digest and
                approval["approvedAt"] == "2026-10-09" and
                approval["reviewer"] == "AI-GPT6" and
                approval["reviewMode"] == "AI_EDITORIAL",
                f"{key}: stale or misleading source approval")
        first_row = first["vocabulary"][key]
        require(first_row["contentSha256"] == digest and
                first_row["updatedAt"] == "2026-10-09" and
                first_row["decision"] == "PASS",
                f"{key}: first editorial snapshot out of sync")
        if int(key[-3:]) >= 181:
            sec = second["vocabulary"][key]
            require(sec["contentSha256"] == digest and
                    sec["synonyms"] == row["synonyms"] and
                    sec["example"] == row["example"] and
                    sec["decision"] == "PASS_AI_RECHECK",
                    f"{key}: second editorial snapshot out of sync")


def validate() -> None:
    rows = parse_batches()
    pron = (CONTENT / "ToeicPronunciationCatalog.ets").read_text(encoding="utf-8")
    pairs = re.findall(r"new ToeicPronunciationEntry\('(V-\d+)','([^']+)'", pron)
    ipa = dict(pairs)
    require(len(pairs) == len(ipa) == 300, "missing/duplicate IPA")
    approved = json.loads(APPROVALS.read_text(encoding="utf-8"))
    first = json.loads(FIRST.read_text(encoding="utf-8"))
    second = json.loads(SECOND.read_text(encoding="utf-8"))
    check(rows, ipa, approved, first, second)

    for key, expected in TARGETS.items():
        reverted = deepcopy(rows)
        reverted[key]["synonyms"] = [expected["obsolete"]]
        try:
            check(reverted, ipa, approved, first, second)
        except AssertionError as error:
            require(key in str(error), f"{key}: wrong negative-test failure")
        else:
            raise AssertionError(
                f"TOEIC_ISSUE478_DOMAIN_FAIL: obsolete {key} was accepted")

    forged = deepcopy(approved)
    forged["vocabulary"]["V-215"]["contentSha256"] = "0" * 64
    try:
        check(rows, ipa, forged, first, second)
    except AssertionError as error:
        require("V-215" in str(error), "stale SHA negative failed unexpectedly")
    else:
        raise AssertionError("TOEIC_ISSUE478_DOMAIN_FAIL: forged approval passed")

    print("TOEIC_ISSUE478_DOMAIN_PASS corrected_words=8 "
          "source_batch_words=180 ipa_ids=300 negative_checks=9 "
          "human_ETS_certification=NO")


if __name__ == "__main__":
    validate()
