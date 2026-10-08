#!/usr/bin/env python3
"""Regression tests: reviewed source edits must invalidate publication approvals."""
from __future__ import annotations

from datetime import date
import copy
import io
import unittest

from toeic_review_integrity import (
    is_valid_approval, reading_fingerprint, vocabulary_fingerprint,
)


class ReviewIntegrityTests(unittest.TestCase):
    def test_word_digest_ignores_publish_status_but_not_content(self) -> None:
        word = {
            "id": "V-241", "word": "attachment", "pos": "n.",
            "meaning": "附件", "level": "L1", "scene": "邮件",
            "collocations": ["email attachment"], "synonyms": ["file"],
            "example": "The file was attached.", "status": "REVIEWED",
        }
        original = vocabulary_fingerprint(word, "/əˈtætʃmənt/")
        published = {**word, "status": "PUBLISHED"}
        self.assertEqual(original, vocabulary_fingerprint(published, "/əˈtætʃmənt/"))
        published["meaning"] = "另一个释义"
        self.assertNotEqual(original, vocabulary_fingerprint(published, "/əˈtætʃmənt/"))
        self.assertNotEqual(original, vocabulary_fingerprint(word, "/əˈtætʃməntx/"))

    def test_group_digest_invalidates_changed_answer_or_document(self) -> None:
        base = {
            "id": "R-P7-TEST-01", "skill": "CROSS_DOCUMENT", "stem": "Why?",
            "options": ["A", "B", "C", "D"], "answer": 2,
            "explanation": "E", "evidence": "fact 1 || fact 2",
            "paraphrase": "P", "seconds": 60, "difficulty": "HARD",
            "status": "REVIEWED",
        }
        group = {"ids": [base["id"]], "docs": ["fact 1", "fact 2"]}
        original = reading_fingerprint("P7-EX-TEST", group, [base])
        variant = copy.deepcopy(base)
        variant["status"] = "PUBLISHED"
        self.assertEqual(original, reading_fingerprint("P7-EX-TEST", group, [variant]))
        variant["answer"] = 1
        self.assertNotEqual(original, reading_fingerprint("P7-EX-TEST", group, [variant]))
        changed_docs = {"ids": group["ids"], "docs": ["fact 1 updated", "fact 2"]}
        self.assertNotEqual(original, reading_fingerprint("P7-EX-TEST", changed_docs, [base]))

    def test_approval_gate_rejects_stale_or_fake_signoffs(self) -> None:
        digest = "a" * 64
        valid = {"reviewer": "qualified-reviewer", "approvedAt": "2026-10-08",
                 "contentSha256": digest}
        today = date(2026, 10, 8)
        self.assertTrue(is_valid_approval(valid, digest, today))
        self.assertFalse(is_valid_approval(valid, "b" * 64, today))
        self.assertFalse(is_valid_approval({**valid, "contentSha256": ""}, digest, today))
        self.assertFalse(is_valid_approval({**valid, "approvedAt": "2026-10-09"}, digest, today))
        self.assertFalse(is_valid_approval({**valid, "approvedAt": "2026-02-30"}, digest, today))
        self.assertFalse(is_valid_approval({**valid, "reviewer": "TODO"}, digest, today))
        self.assertFalse(is_valid_approval({**valid, "reviewer": ""}, digest, today))
        self.assertFalse(is_valid_approval({}, digest, today))


def run_tests() -> None:
    stream = io.StringIO()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ReviewIntegrityTests)
    result = unittest.TextTestRunner(stream=stream).run(suite)
    if not result.wasSuccessful():
        raise SystemExit("[toeic-review-integrity] FAIL\n" + stream.getvalue())
    print(f"[toeic-review-integrity] PASS: {result.testsRun} tests")


if __name__ == "__main__":
    run_tests()
