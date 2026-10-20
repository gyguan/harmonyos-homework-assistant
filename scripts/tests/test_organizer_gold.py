"""Human review boundary, source drift, private collection and output tests; synthetic fixtures only."""
import copy
import io
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch
from urllib import error

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from organizer_gold import CHECKS, FIELDS, annotation_digest, verify_case, validate_receipt
from organizer_eval_inputs import case_fingerprint
from prepare_homework_organizer_gold import collect, draft, main, NoRedirect, write_private
from evaluate_homework_organizer import evaluate


def task():
    return dict(subject='数学', title='口算20题', instruction='口算20题', textbookRef='P13', taskDate='2026-10-19', expectedMinutes=10)


def case():
    return dict(id='anonymous-1', teacherKey='teacher-a', reviewStatus='DRAFT', sourceType='TEXT', sourceText='数学：口算20题',
                expected=[dict(subject='数学', keywords=['口算', '20'], fields=task(), sourceEvidenceTexts=['口算20题'])])


def declaration(item, root):
    return {**{key: True for key in CHECKS}, 'reviewerKey': 'parent-reviewer-1', 'reviewedAt': '2025-01-01T00:00:00Z',
            'annotationDigest': annotation_digest(item), 'inputFingerprint': case_fingerprint(item, root)}


class GoldAnnotationTest(unittest.TestCase):
    def test_explicit_review_roundtrip_and_evaluator_use_existing_scoring(self):
        item = case()
        verified = verify_case(item, declaration(item, '.'), '.')
        prediction = dict(caseId=item['id'], inputFingerprint=case_fingerprint(item, '.'), assignments=[
            dict(task(), sourceBlockIds=['t1'])], sourceDocument=dict(blocks=[dict(id='t1', text=item['sourceText'])]))
        report = evaluate(dict(cases=[verified]), dict(results=[prediction]))
        self.assertEqual(1, report['verifiedCount'])
        self.assertEqual(1, report['total']['recallProxy'])
        self.assertEqual('DRAFT', item['reviewStatus'])
        validate_receipt(json.loads(json.dumps(verified)), root='.')

    def test_each_human_declaration_is_required_as_literal_boolean(self):
        for key in CHECKS:
            for missing in (False, 'true', 1, None):
                item = case(); review = declaration(item, '.'); review[key] = missing
                with self.assertRaisesRegex(ValueError, 'INCOMPLETE_HUMAN_REVIEW'):
                    verify_case(item, review, '.')

    def test_invalid_dates_reviewer_and_stale_review_rejected(self):
        item = case()
        for change in ({'reviewerKey': '家长真实姓名'}, {'reviewedAt': '2099-01-01T00:00:00Z'}, {'reviewedAt': '2025-01-01'},
                       {'annotationDigest': 'stale'}, {'inputFingerprint': 'stale'}):
            with self.assertRaises(ValueError):
                verify_case(item, {**declaration(item, '.'), **change}, '.')

    def test_complete_fields_keywords_and_independent_source_spans_required(self):
        original = case()
        variants = []
        for key in FIELDS:
            item = copy.deepcopy(original); del item['expected'][0]['fields'][key]; variants.append(item)
        for update in ({'keywords': []}, {'sourceEvidenceTexts': []}, {'sourceEvidenceTexts': ['并未出现的文字']}):
            item = copy.deepcopy(original); item['expected'][0].update(update); variants.append(item)
        for item in variants:
            with self.assertRaises(ValueError):
                verify_case(item, declaration(item, '.'), '.')

    def test_modified_verified_fields_do_not_keep_old_approval(self):
        item = case(); verified = verify_case(item, declaration(item, '.'), '.')
        verified['expected'][0]['fields']['title'] = '口算99题'
        with self.assertRaisesRegex(ValueError, 'VERIFIED_ANNOTATION_CHANGED'):
            validate_receipt(verified)
        with self.assertRaises(ValueError):
            evaluate(dict(cases=[verified]), dict(results=[dict(caseId=item['id'], assignments=[])]))

    def test_actual_image_required_and_byte_changes_invalidate_review(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); image = root / 'private.png'; image.write_bytes(b'original-image-bytes')
            item = case(); item.update(sourceType='IMAGE', imagePath='private.png', contentType='image/png')
            review = declaration(item, root)
            image.write_bytes(b'changed-image-bytes')
            with self.assertRaisesRegex(ValueError, 'STALE_SOURCE_REVIEW'):
                verify_case(item, review, root)
            verified = verify_case(item, declaration(item, root), root)
            with self.assertRaisesRegex(ValueError, 'PREDICTION_SOURCE_MISMATCH'):
                validate_receipt(verified, prediction=dict(inputFingerprint=review['inputFingerprint']))
            image.unlink()
            with self.assertRaises(OSError):
                validate_receipt(verified, root=root)

    def test_reviewed_empty_source_can_have_explicitly_verified_zero_tasks(self):
        item = case(); item.update(sourceText='', expected=[])
        verified = verify_case(item, declaration(item, '.'), '.')
        self.assertEqual([], verified['expected'])

    def test_legacy_hand_curated_fixtures_remain_compatible(self):
        validate_receipt(dict(reviewStatus='VERIFIED', expected=[]))


class GoldCollectionTest(unittest.TestCase):
    def bundle(self):
        return dict(batchId='batch-1', evidence=dict(sourceDocument=dict(inputKind='TEXT', originalText='数学：口算20题'), mappings=[dict(candidateId='ai-batch-1-1', sourceBlockIds=['t1'])]),
                    snapshots=[dict(candidateId='ai-batch-1-1', title='错误初稿')], published=[dict(candidateId='ai-batch-1-1', assignment=task())])

    def publication(self):
        return dict(atomic=True, publishedCount=1, results=[dict(candidateId='ai-batch-1-1', assignment=dict(id='a-published-ai-batch-1-1', studentId='student-1'))])

    def fake(self, scope='student-1'):
        bundle = self.bundle()
        rows = [bundle['evidence'], bundle['snapshots'], dict(task(), id='a-published-ai-batch-1-1', studentId=scope),
                [dict(batchId='other-private-batch', afterValue='private-other'), dict(batchId='batch-1', afterValue='correction')]]
        class Opener:
            def __init__(self): self.requests = []
            def open(self, req, timeout):
                self.requests.append(req)
                return io.StringIO(json.dumps(rows.pop(0)))
        return Opener()

    def test_collect_reuses_read_routes_filters_history_and_never_calls_model(self):
        opener = self.fake()
        with patch('prepare_homework_organizer_gold.request.build_opener', return_value=opener):
            bundle = collect('https://example.test', 'student-1', 'batch-1', self.publication(), 'secret-token')
        self.assertEqual(['GET'] * 4, [req.get_method() for req in opener.requests])
        self.assertEqual(['correction'], [row['afterValue'] for row in bundle['reviewDifferences']])
        self.assertNotIn('secret-token', json.dumps(bundle))
        self.assertEqual('Bearer secret-token', opener.requests[0].get_header('Authorization'))
        draft_case = draft(bundle, 'anonymous-1', 'teacher-a')['cases'][0]
        self.assertEqual('DRAFT', draft_case['reviewStatus'])
        self.assertEqual('口算20题', draft_case['expected'][0]['fields']['title'])
        self.assertEqual([], draft_case['expected'][0]['keywords'])
        self.assertEqual([], draft_case['expected'][0]['sourceEvidenceTexts'])
        self.assertNotIn('verification', draft_case)

    def test_scope_mismatch_cannot_export_sibling_assignment(self):
        with patch('prepare_homework_organizer_gold.request.build_opener', return_value=self.fake('sibling')):
            with self.assertRaisesRegex(ValueError, 'ASSIGNMENT_SCOPE_MISMATCH'):
                collect('https://example.test', 'student-1', 'batch-1', self.publication(), 'secret')

    def test_insecure_remote_or_redirect_never_receives_token(self):
        for base in ('http://remote.test', 'https://user:password@example.test', 'https://example.test?token=secret'):
            with patch('prepare_homework_organizer_gold.request.build_opener') as opener:
                with self.assertRaises(ValueError):
                    collect(base, 'student-1', 'batch-1', self.publication(), 'secret')
                opener.assert_not_called()
        with self.assertRaisesRegex(ValueError, 'REDIRECT_REJECTED'):
            NoRedirect().redirect_request(None, None, 302, '', {}, 'https://elsewhere.test')

    def test_duplicate_unrelated_or_unscoped_publication_rejected(self):
        for mode in ('duplicate', 'unrelated', 'student'):
            publication = self.publication()
            if mode == 'duplicate': publication['results'] *= 2; publication['publishedCount'] = 2
            if mode == 'unrelated': publication['results'][0]['candidateId'] = 'ai-other-batch-1'
            if mode == 'student': publication['results'][0]['assignment']['studentId'] = 'sibling'
            with patch('prepare_homework_organizer_gold.request.build_opener', return_value=self.fake()):
                with self.assertRaises(ValueError):
                    collect('https://example.test', 'student-1', 'batch-1', publication, 'secret')

    def test_draft_images_require_original_asset_and_stay_unverified(self):
        bundle = self.bundle(); bundle['evidence']['sourceDocument']['inputKind'] = 'IMAGE'
        item = draft(bundle, 'anonymous-1', 'teacher-a')['cases'][0]
        self.assertEqual('', item['imagePath'])
        with self.assertRaises(ValueError): case_fingerprint(item, '.')

    def test_output_private_no_overwrite_or_symlink_and_no_console_payload(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'private.json'; write_private(path, {'private': 'secret'})
            self.assertEqual(0, stat.S_IMODE(path.stat().st_mode) & 0o077)
            with self.assertRaises(FileExistsError): write_private(path, {})
            link = Path(tmp) / 'symlink.json'; link.symlink_to(path)
            with self.assertRaises(FileExistsError): write_private(link, {})
            output = io.StringIO()
            with redirect_stdout(output):
                status = main(['draft', '--bundle', str(path), '--case-id', 'anonymous-1', '--teacher-key', 'teacher-a', '--output', str(path)])
            self.assertEqual(1, status)
            self.assertNotIn('secret', output.getvalue())
            self.assertNotIn(tmp, output.getvalue())

    def test_cli_inspect_verify_and_check_bind_same_case_set(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); fixtures = root / 'draft.json'; reviews = root / 'reviews.json'; verified = root / 'verified.json'
            write_private(fixtures, dict(schemaVersion=2, cases=[case()]))
            with redirect_stdout(io.StringIO()):
                self.assertEqual(0, main(['inspect', '--fixtures', str(fixtures), '--output', str(reviews)]))
            data = json.loads(reviews.read_text()); review = data['reviews'][0]
            self.assertTrue(all(review[key] is False for key in CHECKS))
            review.update(declaration(case(), root)); reviews.write_text(json.dumps(data))
            with redirect_stdout(io.StringIO()):
                self.assertEqual(0, main(['verify', '--fixtures', str(fixtures), '--reviews', str(reviews), '--output', str(verified)]))
                self.assertEqual(0, main(['check', '--fixtures', str(verified)]))
            item = json.loads(verified.read_text()); item['cases'][0]['sourceText'] += '改'; verified.write_text(json.dumps(item))
            with redirect_stdout(io.StringIO()):
                self.assertEqual(1, main(['check', '--fixtures', str(verified)]))


if __name__ == '__main__':
    unittest.main()
