#!/usr/bin/env python3
"""Static editorial quality gate for staged original TOEIC vocabulary and P7 bundles.

These tests check structural and exact-evidence consistency; they do not replace
independent human proofreading or authorize publishing a REVIEWED candidate.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
from toeic_review_integrity import reading_fingerprint, vocabulary_fingerprint, is_valid_approval

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"
JSON_STRING = r'"(?:[^"\\]|\\.)*"'
JSON_OPTIONS = r'\[(?:[^\n])*?\]'


def require(value: bool, message: str) -> None:
    if not value:
        raise SystemExit(f"[toeic-editorial] FAIL: {message}")


def validate() -> None:
    # Discover additional batches automatically; adding new content need not
    # weaken evidence or approval gates by patching hardcoded file lists.
    source_files = ["ToeicExtraReadingContent.ets"] + [
        p.name for p in sorted(CONTENT.glob("ToeicExtraReadingBatch*.ets"))
    ]
    word_files = [p.name for p in sorted(CONTENT.glob("ToeicVocabularyBatch*.ets"))]
    source = "\n".join((CONTENT / name).read_text(encoding="utf-8") for name in source_files)
    word_source = "\n".join((CONTENT / name).read_text(encoding="utf-8") for name in word_files)
    pronunciation = (CONTENT / "ToeicPronunciationCatalog.ets").read_text(encoding="utf-8")
    approvals = json.loads((ROOT / "docs/product/toeic-editorial-approvals.json").read_text(encoding="utf-8"))
    ai_audit = json.loads((ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json").read_text(encoding="utf-8"))

    def approved(area: str, key: str, expected_sha: str) -> bool:
        entry = approvals.get(area, {}).get(key, {})
        if not is_valid_approval(entry, expected_sha):
            return False
        if entry.get("reviewMode", "HUMAN") == "AI_EDITORIAL":
            item = ai_audit.get(area, {}).get(key, {})
            if item.get("decision") != "PASS" or item.get("contentSha256") != expected_sha:
                return False
            if area == "readingGroups":
                questions = item.get("questions", [])
                if len(questions) != 5 or any(q.get("decision") != "PASS" for q in questions):
                    return False
        return True

    groups = {}
    group_pattern = r'new ToeicReadingGroup\("([^"]+)",(\[[^\n]*?\]),(\[[^\n]*?\])\)'
    for name, raw_ids, raw_docs in re.findall(group_pattern, source):
        require(name not in groups, f"duplicate group {name}")
        ids, docs = json.loads(raw_ids), json.loads(raw_docs)
        require(len(docs) in (2, 3), f"{name}: expected double/triple documents")
        require(len(ids) >= 5 and len(set(ids)) == len(ids), f"{name}: invalid question membership")
        for number, doc in enumerate(docs, 1):
            require(doc.startswith(f"DOCUMENT {number}"), f"{name}: document headings out of sequence")
        groups[name] = {"ids": ids, "docs": docs}
    require(len(groups) >= 13, f"expected at least 13 authored reading groups, found {len(groups)}")

    question_re = re.compile(
        r'new ToeicQuestion\("(?P<id>[^"]+)",ToeicSection.READING,ToeicPart.PART_7,'
        r'\s*ToeicSkill\.(?P<skill>\w+),\'\','
        rf'(?P<stem>{JSON_STRING}),(?P<options>{JSON_OPTIONS}),(?P<answer>\d+),'
        rf'\s*(?P<explanation>{JSON_STRING}),(?P<evidence>{JSON_STRING}),'
        rf'(?P<paraphrase>{JSON_STRING}),(?P<seconds>\d+),'
        r'\s*ToeicDifficulty\.(?P<difficulty>\w+),ToeicScoreValue\.\w+,'
        r'\s*ToeicReviewStatus\.(?P<status>\w+),1,\'\',\'\',0,0,"(?P<group>[^"]+)"\)'
    )
    questions = []
    for m in question_re.finditer(source):
        obj = m.groupdict()
        for field in ("stem", "options", "explanation", "evidence", "paraphrase"):
            obj[field] = json.loads(obj[field])
        obj["answer"] = int(obj["answer"])
        obj["seconds"] = int(obj["seconds"])
        questions.append(obj)
    require(len(questions) == len(groups) * 5,
            f"each group requires five fully parsed question constructors: {len(questions)} / {len(groups)}")
    require(len({q["id"] for q in questions}) == len(questions), "duplicate P7 question IDs")
    require("undefined" not in source, "undefined appears in P7 authored question source")

    for group_id, group in groups.items():
        members = [q for q in questions if q["group"] == group_id]
        require({q["id"] for q in members} == set(group["ids"]), f"{group_id}: linked IDs mismatch")
        statuses = {q["status"] for q in members}
        require(statuses in ({"REVIEWED"}, {"PUBLISHED"}),
                f"{group_id}: entire linked group must share a recognized review status")
        if statuses == {"PUBLISHED"}:
            group_hash = reading_fingerprint(group_id, group, members)
            require(approved("readingGroups", group_id, group_hash),
                    f"{group_id}: publication requires dated signoff for the exact group contentSha256")
        for option in range(4):
            require(any(q["answer"] == option for q in members),
                    f"{group_id}: answer position {option} is absent")
        for q in members:
            key = q["id"]
            require(q["status"] in ("REVIEWED", "PUBLISHED"),
                    f"{key}: invalid editorial state")
            require(30 <= q["seconds"] <= 180, f"{key}: implausible recommended time")
            require(len(q["options"]) == 4 and len(set(q["options"])) == 4,
                    f"{key}: four distinct options required")
            require(all(x.strip() for x in q["options"]), f"{key}: empty option")
            require(0 <= q["answer"] < 4, f"{key}: wrong answer index")
            for field in ("stem", "explanation", "paraphrase"):
                require(bool(q[field].strip()), f"{key}: missing {field}")
            cited_docs = set()
            for fragment in q["evidence"].split(" || "):
                doc_index = next((i for i, doc in enumerate(group["docs"])
                                  if fragment.strip() and fragment in doc), -1)
                require(doc_index >= 0, f"{key}: evidence not found verbatim: {fragment}")
                cited_docs.add(doc_index)
            if q["skill"] == "CROSS_DOCUMENT":
                require(len(cited_docs) >= 2, f"{key}: requires proof from two documents")

    # The active catalog excludes REVIEWED content. Publication requires explicit
    # signoff in the approval ledger and a corresponding PUBLISHED state.
    word_re = re.compile(
        rf'new ToeicVocabularyItem\((?P<id>{JSON_STRING}),(?P<word>{JSON_STRING}),'
        rf'(?P<pos>{JSON_STRING}),(?P<meaning>{JSON_STRING}),ToeicVocabularyLevel\.(?P<level>L[123]),'
        rf'(?P<scene>{JSON_STRING}),(?P<collocations>{JSON_OPTIONS}),(?P<synonyms>{JSON_OPTIONS}),'
        rf'"","en-US","",(?P<example>{JSON_STRING}),ToeicReviewStatus\.(?P<status>REVIEWED|PUBLISHED)\)'
    )
    words = []
    for m in word_re.finditer(word_source):
        item = m.groupdict()
        for field in ("id", "word", "pos", "meaning", "scene", "collocations", "synonyms", "example"):
            item[field] = json.loads(item[field])
        words.append(item)
    # Files are alphabetic (BatchFive, BatchFour, ...), not in ID order.
    words.sort(key=lambda w: int(w["id"].split("-")[1]))
    require(len(words) >= 180, f"expected at least 180 structured staged words, found {len(words)}")
    require([int(w["id"].removeprefix("V-")) for w in words] ==
            list(range(121, 121 + len(words))),
            "vocabulary IDs must remain consecutive from V-121")
    pronunciations = dict(re.findall(r"new ToeicPronunciationEntry\('(V-\d+)','([^']+)'", pronunciation))
    for word in words:
        key = word["id"]
        for field in ("word", "pos", "meaning", "scene", "example"):
            require(bool(word[field].strip()), f"{key}: missing {field}")
        for field in ("collocations", "synonyms"):
            require(len(word[field]) > 0 and all(x.strip() for x in word[field]),
                    f"{key}: missing {field}")
        require(word["status"] in ("REVIEWED", "PUBLISHED"), f"{key}: invalid editorial state")
        ipa = pronunciations.get(key, "")
        require(ipa.startswith("/") and ipa.endswith("/") and len(ipa) >= 5,
                f"{key}: missing en-US IPA")
        if word["status"] == "PUBLISHED":
            content_hash = vocabulary_fingerprint(word, ipa)
            require(approved("vocabulary", key, content_hash),
                    f"{key}: publication requires dated signoff for the exact word contentSha256")
    require(len({w["word"].casefold() for w in words}) == len(words), "duplicated staged English word")

    # Check the published inventory too; a new batch must teach genuinely new
    # headwords rather than silently creating a second ID for an existing term.
    existing_sources = [
        "PresetToeicContent.ets", "ToeicWeekOneContent.ets",
        "ToeicVocabularyExpansion.ets",
    ]
    existing_words = []
    for name in existing_sources:
        content = (CONTENT / name).read_text(encoding="utf-8")
        existing_words += re.findall(
            r"""new ToeicVocabularyItem\(['"]V-\d+['"],['"]([^'"]+)['"]""", content)
    known = {word.casefold() for word in existing_words}
    for word in words:
        require(word["word"].casefold() not in known,
                f'{word["id"]}: headword already exists in the published inventory')
    require(len(existing_words) == 120,
            f"published baseline headword list unexpectedly changed: {len(existing_words)}")
    require(len(pronunciations) == len(existing_words) + len(words) and
            {w["id"] for w in words}.issubset(set(pronunciations)),
            "every drafted and published term must keep a unique pronunciation ID")

    print(f"[toeic-editorial] PASS: {len(words)} authored words + "
          f"{len(questions)} P7 questions / {len(groups)} groups; approval ledger enforced")


if __name__ == "__main__":
    validate()
