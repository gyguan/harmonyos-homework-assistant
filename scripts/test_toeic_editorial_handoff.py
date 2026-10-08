#!/usr/bin/env python3
"""Exercise TOEIC human handoff with hostile and incomplete review sheets."""
from __future__ import annotations

import csv
from datetime import date, timedelta
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from toeic_editorial_handoff import COLUMNS, evaluate, prepare, verify
from validate_toeic_editorial_content import ROOT


class HandoffTests(unittest.TestCase):
    def setUp(self) -> None:
        self.today = date.today()
        self.snapshot = {"vocabulary:V-121": "a" * 64,
                         "readingGroups:P7-EX-VENUE": "b" * 64}
        self.accepted = [{
            "asset_type": key.split(":")[0], "asset_id": key.split(":")[1],
            "content_sha256": value, "decision": "APPROVE",
            "reviewer": "professional-reviewer",
            "reviewed_at": self.today.isoformat(), "notes": "Reviewed original and evidence",
        } for key, value in self.snapshot.items()]

    def evaluate(self, rows, current=None):
        return evaluate(self.snapshot, self.snapshot if current is None else current,
                        rows, self.today)

    def test_complete_handoff_only_means_ready_for_human_pr(self):
        result = self.evaluate(self.accepted)
        self.assertEqual("READY_FOR_HUMAN_PR", result["status"])
        self.assertIn("Not a GitHub approval", result["warning"])

    def test_pending_and_missing_items_do_not_pass(self):
        pending = [{**self.accepted[0], "decision": "PENDING"}, self.accepted[1]]
        self.assertEqual("BLOCKED", self.evaluate(pending)["status"])
        missing = self.evaluate(self.accepted[:1])
        self.assertTrue(any("Missing review row" in err for err in missing["errors"]))

    def test_duplicate_unknown_and_invalid_decision_rejected(self):
        self.assertIn("Duplicate row", " ".join(
            self.evaluate(self.accepted + [self.accepted[0]])["errors"]))
        extra = {**self.accepted[0], "asset_id": "V-999"}
        self.assertIn("Unexpected asset", " ".join(
            self.evaluate(self.accepted + [extra])["errors"]))
        bad = [{**self.accepted[0], "decision": "PUBLISHED"}, self.accepted[1]]
        self.assertIn("Invalid decision", " ".join(self.evaluate(bad)["errors"]))

    def test_digest_change_or_source_edit_blocks_approval(self):
        fake = [{**self.accepted[0], "content_sha256": "c" * 64}, self.accepted[1]]
        self.assertIn("Changed review digest", " ".join(self.evaluate(fake)["errors"]))
        fresh = {**self.snapshot, "vocabulary:V-121": "c" * 64}
        self.assertIn("Stale source", " ".join(self.evaluate(self.accepted, fresh)["errors"]))

    def test_fake_dates_and_reviewer_or_unexplained_rejection_block(self):
        for value in ("", "TODO", "unknown"):
            reviewed = [{**self.accepted[0], "reviewer": value}, self.accepted[1]]
            self.assertEqual("BLOCKED", self.evaluate(reviewed)["status"])
        future = (self.today + timedelta(days=1)).isoformat()
        reviewed = [{**self.accepted[0], "reviewed_at": future}, self.accepted[1]]
        self.assertEqual("BLOCKED", self.evaluate(reviewed)["status"])
        reviewed = [{**self.accepted[0], "decision": "REJECT", "notes": ""}, self.accepted[1]]
        self.assertIn("REJECT requires review notes", " ".join(self.evaluate(reviewed)["errors"]))

    def test_real_pack_is_scoped_and_never_updates_approvals(self):
        approval_file = ROOT / "docs/product/toeic-editorial-approvals.json"
        before = approval_file.read_bytes()
        with TemporaryDirectory() as temp:
            pack = Path(temp) / "review"
            counts = prepare(121, "P7-EX-VENUE", pack)
            self.assertEqual({"words": 30, "groups": 1, "decisions": 31}, counts)
            self.assertEqual("BLOCKED", verify(pack)["status"])
            self.assertEqual(31, len(list(csv.DictReader(
                (pack / "review-decisions.csv").open("r", encoding="utf-8-sig", newline="")
            ))))
            with self.assertRaisesRegex(ValueError, "Refusing to overwrite"):
                prepare(121, "P7-EX-VENUE", pack)
            source = json.loads((pack / "review-source.json").read_text(encoding="utf-8"))
            self.assertEqual(31, len(source))
            self.assertTrue(all(len(value) == 64 for value in source.values()))
            # Exercise the complete offline handoff: a fully populated verdict
            # sheet can be verified, but must never mutate the source approval ledger.
            decision_file = pack / "review-decisions.csv"
            with decision_file.open("r", newline="", encoding="utf-8-sig") as handle:
                decisions = list(csv.DictReader(handle))
            for decision in decisions:
                decision["decision"] = "APPROVE"
                decision["reviewer"] = "professional-reviewer"
                decision["reviewed_at"] = self.today.isoformat()
                decision["notes"] = "Original checked independently"
            with decision_file.open("w", newline="", encoding="utf-8-sig") as handle:
                writer = csv.DictWriter(handle, fieldnames=COLUMNS)
                writer.writeheader()
                writer.writerows(decisions)
            self.assertEqual("READY_FOR_HUMAN_PR", verify(pack)["status"])
            # Removing 29 items from the snapshot must not falsely pass.
            (pack / "review-source.json").write_text(
                json.dumps({"vocabulary:V-121": source["vocabulary:V-121"]}),
                encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "complete selected batch"):
                verify(pack)
        self.assertEqual(before, approval_file.read_bytes())

    def test_pack_requires_valid_selection(self):
        with TemporaryDirectory() as temp:
            target = Path(temp) / "invalid"
            with self.assertRaises(ValueError):
                prepare(None, None, target)
            with self.assertRaises(ValueError):
                prepare(122, None, target)
            with self.assertRaises(ValueError):
                prepare(None, "P7-EX-DOES-NOT-EXIST", target)


def run_tests() -> None:
    import io
    output = io.StringIO()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(HandoffTests)
    result = unittest.TextTestRunner(stream=output).run(suite)
    if not result.wasSuccessful():
        raise SystemExit("[toeic-handoff-tests] FAIL\n" + output.getvalue())
    print(f"[toeic-handoff-tests] PASS: {result.testsRun} tests")


if __name__ == "__main__":
    run_tests()
