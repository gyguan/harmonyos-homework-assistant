#!/usr/bin/env python3
"""Canonical content fingerprints for human TOEIC editorial approval.

Fingerprints tie the signed approval to the exact reviewed content.
Changing REVIEWED -> PUBLISHED alone does not modify the fingerprint.
"""
from __future__ import annotations

import hashlib
import json
from datetime import date
import re


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


def is_valid_approval(entry: object, expected_hash: str, today: date | None = None) -> bool:
    """Check only recorded evidence shape and content identity, not reviewer authenticity.

    Human/organization approval authority must be enforced during PR review.
    """
    if not isinstance(entry, dict):
        return False
    reviewer = entry.get("reviewer", "")
    approved_at = entry.get("approvedAt", "")
    digest = entry.get("contentSha256", "")
    if not isinstance(reviewer, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]{0,38}", reviewer):
        return False
    if reviewer.lower() in {"unknown", "pending", "todo", "tbd"}:
        return False
    # AI-led reviews are allowed only with explicit provenance. Never
    # masquerade as a human approver or silently treat an AI label as human.
    mode = entry.get("reviewMode", "HUMAN")
    if mode == "AI_EDITORIAL":
        if reviewer != "AI-GPT6" or entry.get("reviewEvidence") != (
                "docs/product/toeic-ai-editorial-review-2026-10-08.json"):
            return False
    elif mode == "HUMAN":
        if reviewer.startswith("AI-"):
            return False
    else:
        return False
    if not isinstance(approved_at, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", approved_at):
        return False
    if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest) or digest != expected_hash:
        return False
    try:
        when = date.fromisoformat(approved_at)
    except ValueError:
        return False
    return when <= (today if today is not None else date.today())
