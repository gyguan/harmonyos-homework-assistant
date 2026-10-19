"""Deterministic tests for offline comparison; no AI credentials required."""
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from evaluate_homework_organizer import evaluate


class HomeworkEvaluationTest(unittest.TestCase):
    def fixture(self, status="VERIFIED"):
        return {"cases": [{
            "id": "case-1", "teacherKey": "t1", "reviewStatus": status,
            "expected": [
                {"subject": "语文", "keywords": ["国学", "13"]},
                {"subject": "数学", "keywords": ["口算", "20"]},
            ],
        }]}

    def prediction(self, assignments):
        return {"results": [{
            "caseId": "case-1", "model": "fixture-model",
            "promptVersion": "v1", "assignments": assignments,
        }]}

    def test_draft_samples_never_count_as_accuracy(self):
        result = evaluate(self.fixture("DRAFT"), self.prediction([]))
        self.assertEqual("NO_VERIFIED_GOLD", result["status"])
        self.assertNotIn("total", result)
        self.assertEqual(0, result["verifiedCount"])

    def test_verified_gold_scores_matched_and_missing(self):
        result = evaluate(self.fixture(), self.prediction([
            {"subject": "数学", "title": "口算20题"},
            {"subject": "语文", "title": "朗读国学13页"},
        ]))
        self.assertEqual(2, result["total"]["matched"])
        self.assertEqual(1.0, result["total"]["recallProxy"])
        self.assertEqual(1.0, result["total"]["precisionProxy"])
        self.assertEqual(1, result["total"]["exactTaskCountCases"])

    def test_wrong_subject_is_not_matched_as_correct(self):
        result = evaluate(self.fixture(), self.prediction([
            {"subject": "英语", "title": "国学13页"},
            {"subject": "数学", "title": "口算20题"},
        ]))
        self.assertEqual(1, result["total"]["matched"])
        self.assertEqual(0.5, result["total"]["recallProxy"])
        self.assertEqual(0.5, result["total"]["precisionProxy"])
        self.assertEqual(1, len(result["cases"][0]["missing"]))

    def test_duplicates_cannot_cover_one_gold_task_twice(self):
        result = evaluate(self.fixture(), self.prediction([
            {"subject": "语文", "title": "国学第13页"},
            {"subject": "语文", "title": "国学第13页"},
        ]))
        self.assertEqual(1, result["total"]["matched"])
        self.assertEqual(0.5, result["total"]["precisionProxy"])
        self.assertEqual(1, len(result["cases"][0]["unmatchedOutputs"]))

    def test_verified_case_without_prediction_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Missing model output"):
            evaluate(self.fixture(), {"results": []})

    def test_verified_case_without_keywords_is_rejected(self):
        fixture = self.fixture()
        fixture["cases"][0]["expected"][0]["keywords"] = []
        with self.assertRaisesRegex(ValueError, "empty expected"):
            evaluate(fixture, self.prediction([]))


if __name__ == "__main__":
    unittest.main()
