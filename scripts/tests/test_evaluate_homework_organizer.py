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

class JointMetricsTest(unittest.TestCase):
    def test_latency_tokens_failures_and_missing_usage(self):
        from organizer_metrics import summarize
        report = summarize([
            dict(elapsedMs=10, tokensIn=100, tokensOut=50, reviewTriggered=False, success=True, callCount=1),
            dict(elapsedMs=100, tokensIn='unavailable', tokensOut='unavailable', reviewTriggered=True, success=False, callCount=2)])
        self.assertEqual(10, report['p50Ms'])
        self.assertEqual(100, report['p95Ms'])
        self.assertEqual(.5, report['failureRate'])
        self.assertEqual(1, report['usageUnavailableRequests'])
        self.assertEqual(1.5, report['averageCalls'])

    def test_duplicate_predictions_rejected_even_without_gold(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate prediction'):
            evaluate({'cases': []}, {'results': [{'caseId': 'a'}, {'caseId': 'a'}]})

    def test_field_error_and_fabricated_evidence_are_not_counted_correct(self):
        case = HomeworkEvaluationTest().fixture()
        case['cases'][0]['expected'][0].update(fields={'taskDate': '2026-10-19'}, sourceBlockIds=['b1'])
        pred = HomeworkEvaluationTest().prediction([
            dict(subject='语文', title='国学13页', taskDate='2026-10-20', sourceBlockIds=['fake']),
            dict(subject='数学', title='口算20题')])
        result = evaluate(case, pred)
        self.assertEqual(0, result['total']['keyFieldAccuracy'])
        self.assertEqual(0, result['total']['evidenceAccuracy'])
        self.assertEqual(0, result['total']['evidenceCoverage'])

    def test_gold_edits_invalidate_comparison(self):
        from evaluate_homework_organizer import compare
        with self.assertRaisesRegex(ValueError, 'identical fixture'):
            compare({'fixtureHash': 'old'}, {'fixtureHash': 'edited'})

    def test_missing_field_metric_is_regression(self):
        from evaluate_homework_organizer import compare
        result = compare(dict(fixtureHash='same', status='SCORED_KEYWORD_PROXY', total={'keyFieldAccuracy': 1}),
                         dict(fixtureHash='same', status='SCORED_KEYWORD_PROXY', total={}))
        self.assertTrue(result['regressed'])

    def test_image_replay_refuses_text_substitute(self):
        from run_homework_organizer_eval import replay
        from unittest.mock import patch
        with patch.dict('os.environ', {'ORGANIZER_EVAL_TOKEN': 'not-real'}):
            with self.assertRaisesRegex(ValueError, 'actual imagePath'):
                replay({'cases': [{'id': 'img', 'sourceType': 'IMAGE'}]}, 'http://localhost', 's', Path('.'))
