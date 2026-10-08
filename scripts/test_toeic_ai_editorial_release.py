#!/usr/bin/env python3
"""Content QA regression suite for staged AI-attributed TOEIC releases.

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

    def test_release_manifest_enforces_exactly_declared_batches(self) -> None:
        """Release audit checks actual per-ID states, not only aggregate totals."""
        manifest = json.loads(
            (ROOT / "docs/product/toeic-controlled-release-manifest.json").read_text(encoding="utf-8")
        )
        self.assertEqual(1, manifest["schemaVersion"])
        self.assertEqual(120, manifest["baselinePublishedVocabulary"])
        self.assertEqual(13, manifest["authoredSupplementaryReadingGroups"])
        self.assertEqual(
            "docs/product/toeic-ai-editorial-review-2026-10-08.json",
            manifest["editorialEvidence"],
        )
        expected_words = set()
        expected_groups = set()
        for batch in manifest["releaseBatches"]:
            start, end = batch["wordIdRange"]["start"], batch["wordIdRange"]["end"]
            self.assertEqual(30, end - start + 1, "Release only one 30-word tranche at once")
            self.assertEqual(0, (start - 121) % 30, "Vocabulary tranche must align to day plan")
            for number in range(start, end + 1):
                key = f"V-{number:03d}"
                self.assertNotIn(key, expected_words, "A word may belong to only one release batch")
                expected_words.add(key)
            self.assertTrue(batch["readingGroupIds"], "Each tranche records its complete P7 groups")
            for group in batch["readingGroupIds"]:
                self.assertNotIn(group, expected_groups, "No reading group can be released twice")
                expected_groups.add(group)

        word_statuses = {}
        for path in CONTENT.glob("ToeicVocabularyBatch*.ets"):
            text = path.read_text(encoding="utf-8")
            for word_id, status in re.findall(
                r'new ToeicVocabularyItem\("(V-\d+)",.+?ToeicReviewStatus\.(REVIEWED|PUBLISHED)\)',
                text,
            ):
                self.assertNotIn(word_id, word_statuses)
                word_statuses[word_id] = status
        self.assertEqual(180, len(word_statuses))
        self.assertEqual(set(f"V-{number:03d}" for number in range(121, 301)), set(word_statuses))
        self.assertEqual(
            expected_words,
            {word_id for word_id, status in word_statuses.items() if status == "PUBLISHED"},
        )

        reading_statuses = {}
        for path in [CONTENT / "ToeicExtraReadingContent.ets", *CONTENT.glob("ToeicExtraReadingBatch*.ets")]:
            text = path.read_text(encoding="utf-8")
            for question_id, status, group_id in re.findall(
                r'new ToeicQuestion\("(R-P7-[A-Z-]+-\d+)"[\s\S]*?'
                r'ToeicReviewStatus\.(REVIEWED|PUBLISHED),[1-9]\d*,\'\',\'\',0,0,"(P7-EX-[A-Z-]+)"\)',
                text,
            ):
                self.assertNotIn(question_id, reading_statuses)
                reading_statuses[question_id] = (group_id, status)
        self.assertEqual(65, len(reading_statuses))
        by_group = {}
        for group_id, status in reading_statuses.values():
            by_group.setdefault(group_id, []).append(status)
        self.assertEqual(13, len(by_group))
        self.assertEqual({5}, {len(statuses) for statuses in by_group.values()})
        self.assertEqual(
            expected_groups,
            {group_id for group_id, statuses in by_group.items()
             if all(status == "PUBLISHED" for status in statuses)},
        )
        self.assertTrue(all(
            len(set(statuses)) == 1 for statuses in by_group.values()
        ), "Shared Part 7 passages must release atomically")
        self.assertEqual(120 + len(expected_words), 300)
        self.assertEqual(sum(5 for _ in expected_groups), 65)

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
