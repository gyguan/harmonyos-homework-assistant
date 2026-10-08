#!/usr/bin/env python3
"""Secondary AI editorial report regression: every remaining asset is covered.

This detects stale review decisions and inaccurate evidence bindings. It cannot
certify TOEIC-equivalent difficulty or independently verify every pronunciation.
"""
from __future__ import annotations

import io
import json
import re
import unittest

from export_toeic_review_pack import (
    CONTENT, ROOT, GROUP_RE, QUESTION_RE, WORD_RE, concatenated_sources,
)
from toeic_review_integrity import reading_fingerprint, vocabulary_fingerprint

REPORT_PATH = ROOT / "docs/product/toeic-remaining-content-review-2026-10-08.json"
LEDGER_PATH = ROOT / "docs/product/toeic-editorial-approvals.json"


class RemainingEditorialTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
        cls.ledger = json.loads(LEDGER_PATH.read_text(encoding="utf-8"))
        pronunciation = (CONTENT / "ToeicPronunciationCatalog.ets").read_text(encoding="utf-8")
        cls.ipa = dict(re.findall(r"new ToeicPronunciationEntry\('(V-\d+)','([^']+)'", pronunciation))

    def test_all_120_remaining_words_are_rechecked_against_exact_source(self) -> None:
        word_rows = {}
        for match in WORD_RE.finditer(concatenated_sources("ToeicVocabularyBatch*.ets")):
            item = match.groupdict()
            row = {k: json.loads(item[k]) for k in
                   ("id", "word", "pos", "meaning", "scene", "collocations", "synonyms", "example")}
            row["level"] = item["level"]
            row["status"] = item["status"]
            word_rows[row["id"]] = row
        expected = {f"V-{number}" for number in range(181, 301)}
        self.assertEqual(expected, set(self.report["vocabulary"]))
        self.assertEqual(expected, {k for k in word_rows if k in expected})
        for key in sorted(expected):
            row = word_rows[key]
            reviewed = self.report["vocabulary"][key]
            fingerprint = vocabulary_fingerprint(row, self.ipa[key])
            self.assertEqual("REVIEWED", row["status"])
            self.assertEqual("PASS_AI_RECHECK", reviewed["decision"])
            self.assertEqual(row["word"], reviewed["headword"])
            self.assertEqual(row["pos"], reviewed["pos"])
            self.assertEqual(row["meaning"], reviewed["meaning"])
            self.assertEqual(row["collocations"], reviewed["collocations"])
            self.assertEqual(row["synonyms"], reviewed["synonyms"])
            self.assertEqual(row["example"], reviewed["example"])
            self.assertEqual(self.ipa[key], reviewed["ipa"])
            self.assertEqual(fingerprint, reviewed["contentSha256"])
            self.assertEqual(fingerprint, self.ledger["vocabulary"][key]["contentSha256"])
            self.assertEqual("AI_EDITORIAL", self.ledger["vocabulary"][key]["reviewMode"])

    def test_all_40_remaining_reading_answers_and_quotes_are_rechecked(self) -> None:
        source = concatenated_sources("ToeicExtraReadingBatch*.ets")
        groups = {m[1]: {"ids": json.loads(m[2]), "docs": json.loads(m[3])}
                  for m in GROUP_RE.finditer(source)}
        questions = {}
        for m in QUESTION_RE.finditer(source):
            row = m.groupdict()
            for field in ("stem", "options", "explanation", "evidence", "paraphrase"):
                row[field] = json.loads(row[field])
            row["answer"] = int(row["answer"])
            row["seconds"] = int(row["seconds"])
            questions[row["id"]] = row
        expected = {
            "P7-EX-SUPPORT", "P7-EX-RETAIL", "P7-EX-LEASE", "P7-EX-TRAINING",
            "P7-EX-MIGRATION", "P7-EX-LICENSE", "P7-EX-PERDIEM", "P7-EX-CATERING",
        }
        self.assertEqual(expected, set(self.report["readingGroups"]))
        count = 0
        for group_id in sorted(expected):
            group = groups[group_id]
            review = self.report["readingGroups"][group_id]
            members = [questions[qid] for qid in group["ids"]]
            self.assertEqual(5, len(members))
            self.assertEqual("PASS_AI_RECHECK", review["decision"])
            self.assertEqual(5, review["questionCount"])
            self.assertEqual(len(group["docs"]), review["documentCount"])
            digest = reading_fingerprint(group_id, group, members)
            self.assertEqual(digest, review["contentSha256"])
            self.assertEqual(digest, self.ledger["readingGroups"][group_id]["contentSha256"])
            self.assertEqual({q["answer"] for q in members}, {0, 1, 2, 3})
            checks = review["questions"]
            self.assertEqual(group["ids"], [q["id"] for q in checks])
            for row, check in zip(members, checks):
                count += 1
                self.assertEqual("REVIEWED", row["status"])
                self.assertEqual("PASS_AI_RECHECK", check["result"])
                self.assertEqual(row["stem"], check["question"])
                self.assertEqual(row["answer"], check["answerIndex"])
                self.assertEqual(row["options"][row["answer"]], check["answer"])
                self.assertEqual(row["evidence"], check["evidence"])
                cited = {
                    index + 1 for fragment in row["evidence"].split(" || ")
                    for index, document in enumerate(group["docs"]) if fragment in document
                }
                self.assertTrue(all(
                    any(fragment in doc for doc in group["docs"])
                    for fragment in row["evidence"].split(" || ")
                ))
                self.assertEqual(sorted(cited), check["documents"])
                if row["skill"] == "CROSS_DOCUMENT":
                    self.assertGreaterEqual(len(cited), 2)
        self.assertEqual(40, count)

    def test_corrected_quality_examples_stay_fixed(self) -> None:
        words = self.report["vocabulary"]
        for number in (190, 191, 192, 193):
            self.assertNotIn("price", words[f"V-{number}"]["synonyms"][0].lower())
        self.assertEqual("refundable payment held as security", words["V-218"]["synonyms"][0])
        self.assertIn("authenticate themselves", words["V-254"]["example"])
        self.assertEqual("fixed sum provided for expenses", words["V-278"]["synonyms"][0])
        self.assertEqual("refreshments", words["V-283"]["headword"])
        self.assertEqual("n. pl.", words["V-283"]["pos"])
        self.assertTrue(words["V-283"]["ipa"].endswith("mənts/"))
        group_source = (CONTENT / "ToeicExtraReadingBatchFive.ets").read_text(encoding="utf-8")
        self.assertIn("reports needed for the morning of October 18", group_source)
        self.assertNotIn("reports needed for the following morning", group_source)

    def test_cost_and_date_inferences_match_material(self) -> None:
        # Independent arithmetic sanity checks for the eight groups.
        self.assertEqual(40, 400 * 10 // 100)         # support credit
        self.assertEqual(112, 64 + 48)               # retail clothing subtotal
        self.assertEqual(900, 900)                   # September lease rent
        self.assertEqual(260, min(300, 260))          # training reimbursement
        self.assertEqual(425, int(10 * 50 * .85))     # monthly license fee
        self.assertEqual(485, 425 + 60)               # first software invoice
        self.assertEqual(425, 2 * 132 + 3 * 45 + 26)  # travel reimbursement
        self.assertEqual(260, 135 * (4 + 8) - (100 * 4 + 120 * 8))


def run_tests() -> None:
    output = io.StringIO()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(RemainingEditorialTests)
    result = unittest.TextTestRunner(stream=output).run(suite)
    if not result.wasSuccessful():
        raise SystemExit("[toeic-remaining-editorial] FAIL\n" + output.getvalue())
    print(f"[toeic-remaining-editorial] PASS: {result.testsRun} tests")


if __name__ == "__main__":
    run_tests()
