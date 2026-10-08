#!/usr/bin/env python3
"""Canonical content fingerprints for human TOEIC editorial approval.

Fingerprints tie the signed approval to the exact reviewed content.
Changing REVIEWED -> PUBLISHED alone does not modify the fingerprint.
"""
from __future__ import annotations

import hashlib
import json


def sha256_content(value: object) -> str:
    canonical = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def vocabulary_fingerprint(word: dict, ipa: str) -> str:
    fields = ("id", "word", "pos", "meaning", "level", "scene", "collocations",
              "synonyms", "example")
    return sha256_content({**{field: word[field] for field in fields}, "ipa": ipa})


def reading_fingerprint(group_id: str, group: dict, questions: list[dict]) -> str:
    fields = ("id", "skill", "stem", "options", "answer", "explanation",
              "evidence", "paraphrase", "seconds", "difficulty")
    by_id = {question["id"]: question for question in questions}
    ordered = [{field: by_id[qid][field] for field in fields}
               for qid in group["ids"]]
    return sha256_content({
        "groupId": group_id, "questionIds": group["ids"],
        "documents": group["docs"], "questions": ordered,
    })
