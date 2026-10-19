#!/usr/bin/env python3
"""Replay fixed anonymized fixtures through the running backend, or summarize telemetry logs.
Credentials are read from ORGANIZER_EVAL_TOKEN, never from command arguments or reports.
This invokes the application's configured organizer; it does not bypass its prompt/policies.
"""
import argparse
import base64
import json
import os
import uuid
from pathlib import Path
from time import perf_counter
from urllib import request, error
from evaluate_homework_organizer import read_json
from organizer_metrics import summarize


def measurements(path):
    rows = []
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        marker = 'homework_import measurement data='
        if marker in line:
            rows.append(json.loads(line.split(marker, 1)[1]))
    return rows


def replay(fixtures, base, student, root):
    token = os.environ.get('ORGANIZER_EVAL_TOKEN')
    if not token:
        raise ValueError('Set ORGANIZER_EVAL_TOKEN to a parent session token')
    results = []
    for case in fixtures['cases']:
        kind = case.get('sourceType', 'TEXT')
        req_id = 'eval-' + uuid.uuid4().hex
        payload = dict(text=case.get('sourceText', ''), sourceLabel=case.get('sourceLabel', ''),
                       teacherName=case.get('teacherName', ''), importId=req_id)
        image = case.get('imagePath')
        if kind == 'IMAGE':
            if not image:
                raise ValueError('Image case requires actual imagePath: ' + case['id'])
            payload.update(imageBase64=base64.b64encode((root / image).read_bytes()).decode(),
                           contentType=case.get('contentType', 'image/png'))
        url = base.rstrip('/') + '/api/v1/students/' + student + '/homework/' + ('organize-image' if kind == 'IMAGE' else 'organize')
        req = request.Request(url, data=json.dumps(payload).encode(), headers={
            'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json',
            'X-Request-Id': req_id, 'X-Client-Scene': 'organizer.eval'})
        started = perf_counter()
        row = dict(caseId=case['id'], inputType=kind, requestId=req_id, importId=req_id)
        try:
            with request.urlopen(req, timeout=300) as response:
                result = json.load(response)
            row.update(assignments=result['assignments'], sourceDocument=result.get('sourceDocument', {}), success=True)
        except error.HTTPError as exc:
            # Do not persist exception bodies: upstreams can echo private source or credentials.
            row.update(assignments=[], success=False, httpStatus=exc.code)
        except (error.URLError, TimeoutError):
            row.update(assignments=[], success=False, errorCode='TRANSPORT_UNAVAILABLE')
        row['elapsedMs'] = round((perf_counter() - started) * 1000)
        results.append(row)
    return results


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--logs', type=Path)
    p.add_argument('--fixtures', type=Path)
    p.add_argument('--base-url', default='http://localhost:8080')
    p.add_argument('--student-id')
    p.add_argument('--predictions', type=Path, help='Enrich an existing replay file from --logs')
    p.add_argument('--prices', type=Path, help='Optional per-model configured price/currency table')
    p.add_argument('--output', required=True, type=Path)
    args = p.parse_args()
    if args.predictions:
        rows = read_json(args.predictions)['results']
    elif args.fixtures:
        if not args.student_id:
            p.error('--student-id is required with --fixtures')
        rows = replay(read_json(args.fixtures), args.base_url, args.student_id, args.fixtures.parent)
    else:
        rows = []
    observations = measurements(args.logs) if args.logs else []
    by_request = {r['requestId']: r for r in observations}
    for row in rows:
        observation = by_request.get(row.get('requestId'), {})
        # The replay wall time includes HTTP; retain it independently.
        row['httpElapsedMs'] = row.get('elapsedMs')
        row.update(observation)
    data = {'results': rows, 'performance': summarize(rows or observations, read_json(args.prices) if args.prices else None)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(data['performance'], ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
