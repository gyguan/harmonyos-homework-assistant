#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
import time

from e2e_smoke import DEFAULT_BASE_URL, DEFAULT_TOKEN_FILE, SmokeFailure, expect, http, load_token, require

STUDENT_ID = "student-xiaoyu-001"
VOCABULARY_ID = "V-001"


def session_token() -> str:
    saved = load_token(DEFAULT_TOKEN_FILE)
    return str(saved["token"])


def find_recall(items: list[dict], vocabulary_id: str) -> dict | None:
    return next((item for item in items if item.get("vocabularyId") == vocabulary_id), None)


def verify_persisted(base_url: str, token: str) -> None:
    items = expect(
        http(
            base_url,
            "GET",
            f"/api/v1/students/{STUDENT_ID}/toeic/vocabulary-recalls",
            token=token,
        ),
        (200,),
        "reload persisted TOEIC vocabulary recalls",
    ).json()
    recall = find_recall(items, VOCABULARY_ID)
    require(recall is not None, "persisted TOEIC vocabulary recall missing")
    require(recall.get("remembered") is True, "latest remembered state was not persisted")
    require(int(recall.get("streak", -1)) == 2, "persisted TOEIC vocabulary streak mismatch")
    require(int(recall.get("totalReviews", -1)) == 2, "persisted TOEIC vocabulary review count mismatch")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    base_url = DEFAULT_BASE_URL
    try:
        token = session_token()
        if args.verify_only:
            verify_persisted(base_url, token)
            print("TOEIC_VOCABULARY_RECALL_E2E_PASS mode=verify-only")
            return 0

        now = int(time.time() * 1000)
        first = expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/students/{STUDENT_ID}/toeic/vocabulary-recalls/{VOCABULARY_ID}",
                token=token,
                payload={
                    "remembered": False,
                    "streak": 0,
                    "totalReviews": 1,
                    "nextDueAtEpochMs": now + 6 * 60 * 60 * 1000,
                    "lastReviewedAtEpochMs": now,
                },
            ),
            (200,),
            "persist TOEIC not-remembered state",
        ).json()
        require(first.get("remembered") is False, "not-remembered state mismatch")

        newer_at = now + 2000
        second = expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/students/{STUDENT_ID}/toeic/vocabulary-recalls/{VOCABULARY_ID}",
                token=token,
                payload={
                    "remembered": True,
                    "streak": 2,
                    "totalReviews": 2,
                    "nextDueAtEpochMs": newer_at + 3 * 24 * 60 * 60 * 1000,
                    "lastReviewedAtEpochMs": newer_at,
                },
            ),
            (200,),
            "persist newer TOEIC remembered state",
        ).json()
        require(second.get("remembered") is True, "remembered state mismatch")

        stale = expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/students/{STUDENT_ID}/toeic/vocabulary-recalls/{VOCABULARY_ID}",
                token=token,
                payload={
                    "remembered": False,
                    "streak": 0,
                    "totalReviews": 1,
                    "nextDueAtEpochMs": now + 1000 + 6 * 60 * 60 * 1000,
                    "lastReviewedAtEpochMs": now + 1000,
                },
            ),
            (200,),
            "reject stale TOEIC vocabulary overwrite",
        ).json()
        require(stale.get("remembered") is True, "stale write overwrote newer remembered state")
        require(int(stale.get("totalReviews", -1)) == 2, "stale write overwrote review count")

        verify_persisted(base_url, token)
        print("TOEIC_VOCABULARY_RECALL_E2E_PASS mode=write-and-read")
        return 0
    except SmokeFailure as exc:
        print(f"TOEIC_VOCABULARY_RECALL_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError) as exc:
        print(f"TOEIC_VOCABULARY_RECALL_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
