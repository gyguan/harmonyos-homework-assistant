#!/usr/bin/env python3
"""Collect private existing evidence, prepare DRAFT annotations, and record human review.
No model calls, database writes, automatic verification or automatic anonymization.
Token: ORGANIZER_EVAL_TOKEN. Output files are exclusive/private; summaries contain counts only.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
from urllib import request, error
from urllib.parse import quote, urlsplit
from organizer_eval_inputs import case_fingerprint, digest
from organizer_gold import CHECKS, FIELDS, annotation_digest, require, validate_receipt, verify_case


class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        raise ValueError('REDIRECT_REJECTED')


def collect(base, student, batch, publication, token):
    parsed = urlsplit(base)
    require(parsed.scheme == 'https' or parsed.scheme == 'http' and parsed.hostname in ('localhost', '127.0.0.1', '::1'), 'HTTPS_REQUIRED')
    require(bool(parsed.netloc) and not parsed.username and not parsed.password and not parsed.query and not parsed.fragment, 'INVALID_BASE_URL')
    require(bool(token), 'MISSING_SESSION_TOKEN')
    require(bool(re.fullmatch(r'[A-Za-z0-9_-]{1,140}', batch)), 'INVALID_BATCH_ID')
    require(publication.get('atomic') is True and isinstance(publication.get('results'), list)
            and publication.get('publishedCount') == len(publication['results']) and bool(publication['results']), 'INVALID_PUBLICATION_RECEIPT')
    opener = request.build_opener(NoRedirect())

    def get(path):
        req = request.Request(base.rstrip('/') + path, headers={'Authorization': 'Bearer ' + token, 'X-Client-Scene': 'organizer.gold.collect'})
        try:
            with opener.open(req, timeout=30) as response:
                return json.load(response)
        except error.HTTPError as exc:
            raise ValueError('COLLECTION_HTTP_' + str(exc.code)) from None
        except (error.URLError, TimeoutError):
            raise ValueError('COLLECTION_TRANSPORT_FAILED') from None

    route = '/api/v1/students/' + quote(student, safe='') + '/homework/'
    evidence = get(route + 'source-evidence/' + quote(batch, safe=''))
    snapshots = get(route + 'ai-snapshots/' + quote(batch, safe=''))
    original_ids = {row['candidateId'] for row in snapshots}
    require(len(original_ids) == len(snapshots), 'DUPLICATE_SNAPSHOT')
    require(original_ids == {row['candidateId'] for row in evidence['mappings']}, 'SNAPSHOT_EVIDENCE_MISMATCH')
    published, seen = [], set()
    for item in publication['results']:
        candidate = item['candidateId']
        require(candidate not in seen and (candidate in original_ids or candidate.startswith('manual-' + batch + '-')), 'INVALID_PUBLISHED_CANDIDATE')
        seen.add(candidate)
        actual_id = 'a-published-' + candidate
        require(item['assignment']['id'] == actual_id and item['assignment']['studentId'] == student, 'PUBLICATION_SCOPE_MISMATCH')
        current = get('/api/v1/assignments/' + quote(actual_id, safe=''))
        require(current['id'] == actual_id and current['studentId'] == student, 'ASSIGNMENT_SCOPE_MISMATCH')
        published.append({'candidateId': candidate, 'assignment': current})
    differences = get(route + 'review-differences')
    return {'schemaVersion': 1, 'collectedAt': datetime.now(timezone.utc).isoformat(),
        'batchId': batch, 'evidence': evidence, 'snapshots': snapshots, 'published': published,
        'reviewDifferences': [row for row in differences if row['batchId'] == batch],
        'warnings': ['Difference history is capped at 100 rows; absence is not proof of no changes.',
                     'Published tasks reflect collection time, not necessarily initial publication.',
                     'Source authenticity, completeness, privacy and correctness require manual review.']}


def draft(bundle, case_id, teacher_key):
    document = bundle['evidence']['sourceDocument']
    kind = document['inputKind']
    require(kind in ('TEXT', 'IMAGE'), 'UNSUPPORTED_SOURCE_KIND')
    tasks = []
    for row in bundle['published']:
        assignment = row['assignment']
        tasks.append({'subject': assignment['subject'], 'keywords': [],
                      'fields': {key: assignment[key] for key in FIELDS}, 'sourceEvidenceTexts': []})
    # No automatic source inference, keyword extraction, transcription, or privacy substitutions.
    case = {'id': case_id, 'teacherKey': teacher_key, 'reviewStatus': 'DRAFT', 'sourceType': kind,
        'sourceText': document.get('originalText', ''), 'sourceLabel': '', 'teacherName': '',
        'expected': tasks, 'modelVersion': 'UNMEASURED',
        'provenance': {'kind': 'EXISTING_PRIVATE_BATCH', 'batchFingerprint': digest(bundle['batchId'])},
        'notes': 'UNREVIEWED: redact source/tasks manually; verify real teacher provenance, complete task set, teacher scope, all fields and evidence. Published state is only an annotation aid.'}
    if kind == 'IMAGE':
        case.update(imagePath='', contentType='image/png')
    return {'schemaVersion': 2, 'cases': [case]}


def write_private(path, value):
    encoded = (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Refuse overwrite (including symlinks) and create without a public-permission window.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(encoded)


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    c = sub.add_parser('collect')
    c.add_argument('--base-url', default='http://localhost:8080')
    c.add_argument('--student-id', required=True)
    c.add_argument('--batch-id', required=True)
    c.add_argument('--publication', required=True, type=Path, help='Saved atomic batch publish response; no guessing from truncated history')
    c.add_argument('--output', required=True, type=Path)
    d = sub.add_parser('draft')
    d.add_argument('--bundle', required=True, type=Path)
    d.add_argument('--case-id', required=True)
    d.add_argument('--teacher-key', required=True)
    d.add_argument('--output', required=True, type=Path)
    for name in ('inspect', 'verify', 'check'):
        command = sub.add_parser(name)
        command.add_argument('--fixtures', required=True, type=Path)
        if name == 'inspect':
            command.add_argument('--output', required=True, type=Path)
        if name == 'verify':
            command.add_argument('--reviews', required=True, type=Path)
            command.add_argument('--output', required=True, type=Path)
    args = p.parse_args(argv)
    try:
        if args.command == 'collect':
            data = collect(args.base_url, args.student_id, args.batch_id, read(args.publication), os.environ.get('ORGANIZER_EVAL_TOKEN'))
        elif args.command == 'draft':
            data = draft(read(args.bundle), args.case_id, args.teacher_key)
        else:
            data = read(args.fixtures)
            cases = data['cases']
            require(len(cases) == len({case['id'] for case in cases}), 'DUPLICATE_CASE_ID')
            if args.command == 'inspect':
                data = {'reviews': [{ 'caseId': case['id'], 'annotationDigest': annotation_digest(case),
                    'inputFingerprint': case_fingerprint(case, args.fixtures.parent),
                    **{key: False for key in CHECKS}, 'reviewerKey': '', 'reviewedAt': ''} for case in cases]}
            elif args.command == 'verify':
                reviews = read(args.reviews)['reviews']
                require(len(reviews) == len({r['caseId'] for r in reviews}) and {r['caseId'] for r in reviews} == {c['id'] for c in cases}, 'REVIEW_CASE_COVERAGE_MISMATCH')
                by_id = {row['caseId']: row for row in reviews}
                require(args.output.parent.resolve() == args.fixtures.parent.resolve(), 'KEEP_FIXTURE_IMAGE_BASE_DIRECTORY')
                data = {**data, 'cases': [verify_case(case, by_id[case['id']], args.fixtures.parent) for case in cases]}
            else:
                require(bool(cases) and all(c.get('reviewStatus') == 'VERIFIED' and c.get('verification') for c in cases), 'MANAGED_VERIFIED_CASES_REQUIRED')
                for case in cases:
                    validate_receipt(case, root=args.fixtures.parent)
                print('GOLD_CHECK_PASS cases=' + str(len(cases)))
                return 0
        write_private(args.output, data)
        print('GOLD_' + args.command.upper() + '_PASS')
        return 0
    except (ValueError, KeyError, TypeError, OSError) as exc:
        # No exception values, filenames, URLs, source text or tokens in console output.
        code = str(exc) if isinstance(exc, ValueError) and re.fullmatch(r'[A-Z_0-9]{1,80}', str(exc)) else 'INVALID_INPUT_OR_OUTPUT'
        print('GOLD_' + args.command.upper() + '_FAILED code=' + code)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
