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

    def test_cache_buckets_preserve_missing_usage_and_do_not_hide_cold_regressions(self):
        from organizer_metrics import summarize
        from evaluate_homework_organizer import performance_gate
        cold = dict(cacheHit=False, elapsedMs=100, tokensIn=100, tokensOut=50, success=True)
        warm = dict(cacheHit=True, elapsedMs=1, tokensIn=0, tokensOut=0, success=True)
        report = summarize([cold, warm])
        self.assertEqual(.5, report['cacheHitRate'])
        self.assertEqual(0, report['cacheBuckets']['HIT']['averageTokensIn'])
        self.assertEqual(100, report['cacheBuckets']['MISS']['p95Ms'])
        prior = {'performance': summarize([cold])}
        faster_warm_slower_cold = {'performance': summarize([dict(cold, elapsedMs=150)] + [warm]*100)}
        self.assertEqual('REGRESSED', performance_gate(prior, faster_warm_slower_cold))
        self.assertEqual('UNAVAILABLE', performance_gate(prior, {'performance': summarize([warm])}))
        self.assertIsNone(summarize([dict(cacheHit=True)])['averageTokensIn'])

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

    def test_matching_reference_without_real_source_block_is_not_evidence_accuracy(self):
        case = HomeworkEvaluationTest().fixture()
        case['cases'][0]['expected'][0]['sourceBlockIds'] = ['b1']
        pred = HomeworkEvaluationTest().prediction([
            dict(subject='语文', title='国学13页', sourceBlockIds=['b1']),
            dict(subject='数学', title='口算20题')])
        result = evaluate(case, pred)
        self.assertEqual(0, result['total']['evidenceAccuracy'])

    def test_evidence_spans_do_not_depend_on_model_block_id_numbering(self):
        case = HomeworkEvaluationTest().fixture()
        case['cases'][0]['expected'][0]['sourceEvidenceTexts'] = ['国13']
        pred = HomeworkEvaluationTest().prediction([
            dict(subject='语文', title='国学13页', sourceBlockIds=['provider-block-9']),
            dict(subject='数学', title='口算20题')])
        pred['results'][0]['sourceDocument'] = {'blocks': [{'id':'provider-block-9','text':'语文：朗读国13'}]}
        self.assertEqual(1, evaluate(case, pred)['total']['evidenceAccuracy'])

    def test_literal_shorthand_echo_cannot_pass_expanded_experience_gold(self):
        case = {'cases': [{'id':'x','reviewStatus':'VERIFIED','expected':[{'subject':'语文','keywords':['摘抄','3个好词','2个好句']}]}]}
        pred = {'results':[{'caseId':'x','assignments':[{'subject':'语文','title':'完成摘抄（3+2）'}]}]}
        self.assertEqual(0, evaluate(case,pred)['total']['recallProxy'])

    def test_http_failure_without_model_metadata_is_counted_not_mixed_variant(self):
        fixture = HomeworkEvaluationTest().fixture()
        fixture['cases'].append(dict(id='blank', reviewStatus='VERIFIED', expected=[]))
        prediction = HomeworkEvaluationTest().prediction([])
        prediction['results'].append(dict(caseId='blank',success=False,assignments=[],httpStatus=400))
        result = evaluate(fixture,prediction)
        self.assertEqual(.5,result['performance']['failureRate'])
        self.assertEqual('fixture-model',result['model'])
        self.assertEqual(0,result['total']['recallProxy'])

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

class PerformanceGateTest(unittest.TestCase):
    def test_speed_cannot_hide_field_regression_or_missing_usage(self):
        from evaluate_homework_organizer import performance_gate, compare
        baseline = dict(fixtureHash='same', status='SCORED_KEYWORD_PROXY',
                        total={'recallProxy': 1, 'precisionProxy': 1, 'keyFieldAccuracy': 1},
                        performance=dict(p50Ms=100, p95Ms=200, failureRate=0, averageTokensIn=100, averageTokensOut=50, usageUnavailableRequests=0))
        candidate = dict(fixtureHash='same', status='SCORED_KEYWORD_PROXY',
                         total={'recallProxy': .5, 'precisionProxy': 1, 'keyFieldAccuracy': .5},
                         performance=dict(p50Ms=50, p95Ms=100, failureRate=0, averageTokensIn=80, averageTokensOut=40, usageUnavailableRequests=0))
        self.assertEqual('PASS', performance_gate(baseline, candidate))
        self.assertTrue(compare(baseline, candidate)['regressed'])
        candidate['performance']['usageUnavailableRequests'] = 1
        self.assertEqual('UNAVAILABLE', performance_gate(baseline, candidate))

    def test_latency_or_cost_regression_is_not_pass(self):
        from evaluate_homework_organizer import performance_gate
        baseline = {'performance': dict(p50Ms=10, p95Ms=100, failureRate=0, averageTokensIn=100, averageTokensOut=50)}
        candidate = {'performance': dict(p50Ms=10, p95Ms=101, failureRate=0, averageTokensIn=90, averageTokensOut=40)}
        self.assertEqual('REGRESSED', performance_gate(baseline, candidate))

if __name__ == "__main__":
    unittest.main()
