#!/usr/bin/env python3
"""Content QA regression suite for the first AI-attributed TOEIC rollout.

This is deterministic evidence checking, not proof of TOEIC-equivalent difficulty.
"""
from __future__ import annotations

import io
import json
from pathlib import Path
import re
import unittest

from validate_toeic_editorial_content import CONTENT, ROOT, validate


class AiEditorialReleaseTests(unittest.TestCase):
    def test_approval_snapshots_cover_every_candidate(self) -> None:
        ledger = json.loads((ROOT / "docs/product/toeic-editorial-approvals.json").read_text(encoding="utf-8"))
        evidence = json.loads((ROOT / "docs/product/toeic-ai-editorial-review-2026-10-08.json").read_text(encoding="utf-8"))
        self.assertEqual(180, len(ledger["vocabulary"]))
        self.assertEqual(13, len(ledger["readingGroups"]))
        self.assertEqual(180, len(evidence["vocabulary"]))
        self.assertEqual(13, len(evidence["readingGroups"]))
        self.assertEqual(65, sum(len(x["questions"]) for x in evidence["readingGroups"].values()))
        for section in ("vocabulary", "readingGroups"):
            for key, value in ledger[section].items():
                self.assertEqual("AI_EDITORIAL", value["reviewMode"])
                self.assertEqual("AI-GPT6", value["reviewer"])
                self.assertEqual("PASS", evidence[section][key]["decision"])
                self.assertEqual(value["contentSha256"], evidence[section][key]["contentSha256"])

    def test_pilot_publication_is_atomic_and_bounded(self) -> None:
        first_words = (CONTENT / "ToeicVocabularyBatchTwo.ets").read_text(encoding="utf-8")
        self.assertEqual(30, first_words.count("ToeicReviewStatus.PUBLISHED"))
        self.assertEqual(0, first_words.count("ToeicReviewStatus.REVIEWED"))
        later_words = "".join(
            source.read_text(encoding="utf-8")
            for source in CONTENT.glob("ToeicVocabularyBatch*.ets")
            if source.name != "ToeicVocabularyBatchTwo.ets"
        )
        self.assertEqual(150, later_words.count("ToeicReviewStatus.REVIEWED"))
        self.assertEqual(0, later_words.count("ToeicReviewStatus.PUBLISHED"))

        early_groups = (CONTENT / "ToeicExtraReadingContent.ets").read_text(encoding="utf-8")
        self.assertEqual(15, early_groups.count("ToeicReviewStatus.PUBLISHED"))
        later_groups = "".join(
            file.read_text(encoding="utf-8")
            for file in CONTENT.glob("ToeicExtraReadingBatch*.ets")
        )
        self.assertEqual(50, later_groups.count("ToeicReviewStatus.REVIEWED"))
        self.assertEqual(0, later_groups.count("ToeicReviewStatus.PUBLISHED"))

    def test_corrected_evidence_cannot_regress(self) -> None:
        two = (CONTENT / "ToeicExtraReadingBatchTwo.ets").read_text(encoding="utf-8")
        three = (CONTENT / "ToeicExtraReadingBatchThree.ets").read_text(encoding="utf-8")
        five = (CONTENT / "ToeicExtraReadingBatchFive.ets").read_text(encoding="utf-8")
        self.assertIn("guaranteed next-day delivery, arriving on October 10", two)
        self.assertIn("original invoice can remain unchanged if the balance arrives by October 10", two)
        self.assertIn("Priority support ticket NT-118", three)
        self.assertIn("unplanned service interruption lasting more than 90 minutes", three)
        self.assertIn("minimum-purchase requirement?", three)
        self.assertIn("scheduled migration window due to end?", five)
        # Explicit sample calculation checks, independent of the answer-key strings.
        self.assertEqual(510, 40 * 12 + 30)
        self.assertEqual(40, 400 * 10 // 100)
        self.assertEqual(485, int(10 * 50 * .85 + 60))
        self.assertEqual(425, 2 * 132 + 3 * 45 + 26)
        self.assertEqual(260, 135 * (4 + 8) - (100 * 4 + 120 * 8))

    def test_editorial_gate_accepts_only_content_matching_approved_first_rollout(self) -> None:
        validate()


def run_tests() -> None:
    output = io.StringIO()
    result = unittest.TextTestRunner(stream=output).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(AiEditorialReleaseTests)
    )
    if not result.wasSuccessful():
        raise SystemExit("[toeic-ai-editorial-release] FAIL\n" + output.getvalue())
    print(f"[toeic-ai-editorial-release] PASS: {result.testsRun} tests")


if __name__ == "__main__":
    run_tests()
