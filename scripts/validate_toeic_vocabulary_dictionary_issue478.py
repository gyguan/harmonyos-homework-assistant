#!/usr/bin/env python3
"""Issue #478 dictionary-grounded targeted lexical gate (NOT 300-word certification).

Covers 300 IDs and IPA presence, exact approvals for 180 published batch words,
two newly corrected meanings, seven high-risk pronunciation/part-of-speech
entries, and negative corruption checks. Source URLs are maintained in the
written review. The gate cannot independently evaluate all 300 pronunciations.
"""
from __future__ import annotations

from copy import deepcopy
import json
import re

from export_toeic_review_pack import CONTENT, ROOT, WORD_RE, concatenated_sources
from toeic_review_integrity import vocabulary_fingerprint
from validate_toeic_vocabulary_examples_issue478 import get_rows

APPROVALS = ROOT / "docs/product/toeic-editorial-approvals.json"
AI_AUDIT = ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json"
SECOND_PASS = ROOT / "docs/product/toeic-remaining-content-review-2026-10-08.json"

TARGETS = {
    "V-164": {
        "word": "contingency",
        "pos": "n.",
        "meaning": "可能发生的意外情况；应急安排",
        "collocations": ["contingency plan"],
        "synonyms": ["possible future event"],
        "example": "The operations team prepared a contingency plan for network outages.",
        "ipa": "/kənˈtɪndʒənsi/",
    },
    "V-245": {
        "word": "enclosure",
        "pos": "n.",
        "meaning": "随函附件；围起来的区域",
        "collocations": ["letter enclosure"],
        "synonyms": ["document included with a letter"],
        "example": "The signed application is listed as an enclosure in the letter.",
        "ipa": "/ɪnˈkloʊʒər/",
    },
}

# Retain valid US pronunciation distinctions, rather than rewriting them by
# analogy with UK speech or a different grammatical sense.
IPA_PROBES = {
    "V-014": "/ˈriːfʌnd/ n. · /ˌriːˈfʌnd/ v.",
    "V-033": "/ˈrɛzəˌmeɪ/",
    "V-038": "/ˈtrænsfɝː/ n./v. · /trænsˈfɝː/ v. variant",  # both attested US verb stress patterns
    "V-051": "/ˈɛstəmət/ n. · /ˈɛstəmeɪt/ v.",
    "V-082": "/ʌpˈɡreɪd/ v. · /ˈʌpɡreɪd/ n.",
    "V-238": "/əˈrɪrz/",
    "V-283": "/rɪˈfrɛʃmənts/",
    "V-300": "/pɚ ˈdiːəm/",
}


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError("TOEIC_ISSUE478_DICTIONARY_FAIL: " + message)


def parse_batches() -> dict[str, dict]:
    rows: dict[str, dict] = {}
    for match in WORD_RE.finditer(concatenated_sources("ToeicVocabularyBatch*.ets")):
        item = match.groupdict()
        obj = {k: json.loads(item[k]) for k in
               ("id", "word", "pos", "meaning", "scene", "collocations",
                "synonyms", "example")}
        obj["level"] = item["level"]
        obj["status"] = item["status"]
        require(obj["id"] not in rows, f"duplicate batch ID {obj['id']}")
        rows[obj["id"]] = obj
    require(set(rows) == {f"V-{i:03d}" for i in range(121, 301)},
            "batch word ID list must be V-121..V-300")
    return rows


def check_target(rows: dict, ipa: dict, approvals: dict, ai: dict, second: dict) -> None:
    for item_id, expected in TARGETS.items():
        row = rows[item_id]
        for key in ("word", "pos", "meaning", "collocations", "synonyms", "example"):
            require(row[key] == expected[key], f"{item_id}: reviewed {key} was changed")
        require(ipa[item_id] == expected["ipa"],
                f"{item_id}: IPA differs from reviewed US pronunciation")
        require(row["status"] == "PUBLISHED", f"{item_id}: published flag drift")
        digest = vocabulary_fingerprint(row, ipa[item_id])
        require(approvals["vocabulary"][item_id]["contentSha256"] == digest,
                f"{item_id}: editorial approval hash mismatch")
        require(approvals["vocabulary"][item_id]["approvedAt"] == "2026-10-09",
                f"{item_id}: dictionary-recheck date missing")
        require(approvals["vocabulary"][item_id]["reviewMode"] == "AI_EDITORIAL",
                f"{item_id}: AI check must not be relabeled human approval")
        require(ai["vocabulary"][item_id]["contentSha256"] == digest,
                f"{item_id}: original AI ledger hash mismatch")
        require(ai["vocabulary"][item_id]["updatedAt"] == "2026-10-09",
                f"{item_id}: new review evidence not distinguished from original")
        if item_id == "V-245":
            require(second["vocabulary"][item_id]["contentSha256"] == digest,
                    "V-245: second AI review hash mismatch")
            require(second["vocabulary"][item_id]["meaning"] == expected["meaning"],
                    "V-245: second AI review meaning mismatch")


def validate() -> None:
    base = get_rows()
    require(set(base) == {f"V-{i:03d}" for i in range(1, 301)},
            "300 original vocabulary IDs required")
    batch = parse_batches()
    source = (CONTENT / "ToeicPronunciationCatalog.ets").read_text(encoding="utf-8")
    pairs = re.findall(r"new ToeicPronunciationEntry\('(V-\d+)','([^']+)'", source)
    ipa = dict(pairs)
    require(len(pairs) == len(ipa) == 300, "300 unique pronunciation entries required")
    require(set(ipa) == set(base), "pronunciation IDs must match 300 vocabulary IDs")
    require(all(value.startswith("/") and "/" in value[1:] for value in ipa.values()),
            "malformed IPA delimiters")
    for key, expected in IPA_PROBES.items():
        require(ipa[key] == expected, f"{key}: dictionary-reviewed IPA regression")
    require("new ToeicPronunciationEntry('V-033','/ˈrɛzəˌmeɪ/','en-US','résumé')" in source,
            "V-033: résumé text-to-speech disambiguation was lost")
    approvals = json.loads(APPROVALS.read_text(encoding="utf-8"))
    ai = json.loads(AI_AUDIT.read_text(encoding="utf-8"))
    second = json.loads(SECOND_PASS.read_text(encoding="utf-8"))
    require(set(approvals["vocabulary"]) == set(batch),
            "batch review approval list is incomplete")
    for key, item in batch.items():
        require(approvals["vocabulary"][key]["contentSha256"] ==
                vocabulary_fingerprint(item, ipa[key]),
                f"{key}: approved exact fingerprint stale")
    check_target(batch, ipa, approvals, ai, second)
    # Cambridge Business English: troubleshooting is an attempt to identify
    # the cause and find a remedy, not a guarantee of successful repair.
    trouble = batch["V-202"]
    require(trouble["meaning"] == "排查故障并尝试解决" and
            trouble["pos"] == "v." and
            trouble["synonyms"] == ["identify a fault and seek a solution"] and
            trouble["collocations"] == ["troubleshoot a connection"],
            "V-202 diagnosis/attempt must not become guaranteed repair")
    d202 = vocabulary_fingerprint(trouble, ipa["V-202"])
    require(approvals["vocabulary"]["V-202"]["contentSha256"] == d202 and
            ai["vocabulary"]["V-202"]["contentSha256"] == d202 and
            second["vocabulary"]["V-202"]["contentSha256"] == d202 and
            second["vocabulary"]["V-202"]["meaning"] == trouble["meaning"],
            "V-202 source-bound approval/second pass drift")
    # Cambridge US utility public services and billed utility costs are related
    # but different senses; neither should be lost in Chinese learning material.
    util = batch["V-215"]
    require(util["pos"] == "n. pl." and
            util["meaning"] == "水电燃气等公用事业服务；水电燃气费用" and
            util["synonyms"] == ["essential services such as electricity, gas, and water"] and
            "billed separately" in util["example"],
            "V-215 utility services / billed costs meaning drift")
    digest215 = vocabulary_fingerprint(util, ipa["V-215"])
    require(approvals["vocabulary"]["V-215"]["contentSha256"] == digest215 and
            ai["vocabulary"]["V-215"]["contentSha256"] == digest215 and
            second["vocabulary"]["V-215"]["contentSha256"] == digest215 and
            second["vocabulary"]["V-215"]["meaning"] == util["meaning"],
            "V-215 second-pass source-bound semantic snapshot drift")
    # V-271 layover: a short intermediate stay on any longer journey,
    # especially (but not limited to) air travel.
    layover = batch["V-271"]
    require(layover["meaning"] == "旅途中途短暂停留；转机等候" and
            layover["synonyms"] == ["short stop during a longer journey"] and
            layover["pos"] == "n." and ipa["V-271"] == "/ˈleɪˌoʊvər/",
            "V-271 dictionary-grounded layover semantic regression")
    require(approvals["vocabulary"]["V-271"]["contentSha256"] ==
            vocabulary_fingerprint(layover, ipa["V-271"]) and
            ai["vocabulary"]["V-271"]["contentSha256"] ==
            vocabulary_fingerprint(layover, ipa["V-271"]),
            "V-271 editorial hash not bound to corrected meaning")
    # V-119: productivity is output relative to inputs, not a synonym for generic efficiency.
    expansion = (CONTENT / "ToeicVocabularyExpansion.ets").read_text(encoding="utf-8")
    productivity = get_rows()["V-119"]
    require(productivity[0] == "productivity" and
            productivity[1] == "生产率；单位投入所产生的产出效率",
            "V-119 productivity definition drift")
    require('["output per unit of input"]' in expansion and
            '"V-119","productivity","n."' in expansion,
            "V-119 contextual paraphrase drift")
    require('["output efficiency"]' not in expansion,
            "V-119 old approximate synonym regression")
    # A deliberately wrong interpretation or stress must always fail the gate.
    corrupted = deepcopy(batch)
    corrupted["V-164"]["synonyms"] = ["backup arrangement"]
    try:
        check_target(corrupted, ipa, approvals, ai, second)
    except AssertionError as exc:
        require("V-164" in str(exc), "negative meaning test failed unexpectedly")
    else:
        raise AssertionError("TOEIC_ISSUE478_DICTIONARY_FAIL: old synonym wrongly passed")
    corrupted_ipa = dict(ipa)
    corrupted_ipa["V-014"] = "/ˈriːfʌnd/"
    try:
        for key, expected in IPA_PROBES.items():
            require(corrupted_ipa[key] == expected, f"{key}: invalid IPA")
    except AssertionError as exc:
        require("V-014" in str(exc), "negative IPA test failed unexpectedly")
    else:
        raise AssertionError("TOEIC_ISSUE478_DICTIONARY_FAIL: collapsed noun/verb IPA passed")
    print("TOEIC_ISSUE478_DICTIONARY_PASS vocabulary_ids=300 ipa_ids=300 "
          "batch_approvals_exact=180 corrected_lexical=2 targeted_ipa_probes=8 "
          "negative_checks=2 independent_300_word_certification=NO")


if __name__ == "__main__":
    validate()
