#!/usr/bin/env python3
"""Real Spring/PostgreSQL/Flyway with a local fake provider. NOT visual/semantic accuracy.
The fake is at the external HTTP boundary; no production test-only branches.
"""
import base64
import json
import os
from pathlib import Path
import subprocess
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from batch_publish_e2e import create_student
from e2e_smoke import expect, http, require, PNG_1X1
from homework_review_outbox_e2e import pg_container, sql

REPLY = {}
CALLS = 0


class Provider(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        global CALLS
        CALLS += 1
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        require('messages' in body, 'expected chat protocol')
        data = json.dumps({'choices': [{'message': {'role': 'assistant', 'content': json.dumps(REPLY, ensure_ascii=False)}}],
                           'usage': {'prompt_tokens': 120, 'completion_tokens': 80}}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(data)


def block(ident, text, category='TASK', image=False):
    return dict(id=ident, text=text, inputKind='IMAGE' if image else 'TEXT', page=None,
                imageIndex=0 if image else None, region=[], legibility='READABLE', classification=category)


def candidate(ref='t1'):
    return dict(subject='数学', title='口算20题', instruction='口算20题', textbookRef='待家长确认',
                taskDate='今天', expectedMinutes=10, sourceExcerpt='数学口算20题', confidence=.9, sourceBlockIds=[ref])


def start_backend(log):
    env = dict(os.environ, SERVER_PORT='8081', AI_PROVIDER='GENERIC', AI_PROTOCOL='chat-completions',
               AI_BASE_URL='http://127.0.0.1:8765', AI_API_KEY='', OPENAI_API_KEY='',
               AI_ALLOW_UNAUTHENTICATED='true', AI_ORGANIZER_MODEL='mock-organizer',
               AI_IMAGE_ORGANIZER_MODEL='mock-vision', AI_LOG_PAYLOADS='true', HTTP_LOG_PAYLOADS='true')
    proc = subprocess.Popen(['java', '-jar', 'backend/target/homework-backend-0.1.0.jar'],
                            env=env, stdout=log, stderr=subprocess.STDOUT)
    for _ in range(90):
        if proc.poll() is not None:
            raise RuntimeError('isolated backend exited')
        try:
            if http('http://localhost:8081', 'GET', '/api/v1/health').status == 200:
                return proc
        except OSError:
            pass
        time.sleep(1)
    proc.terminate()
    raise RuntimeError('isolated backend startup timed out')


def main():
    global REPLY
    provider = ThreadingHTTPServer(('127.0.0.1', 8765), Provider)
    threading.Thread(target=provider.serve_forever, daemon=True).start()
    proc = None
    log_path = Path('organizer-evidence-e2e.log')
    try:
        with log_path.open('w') as log:
            proc = start_backend(log)
            base = 'http://localhost:8081'
            token = expect(http(base, 'POST', '/api/v1/auth/login', payload={'loginName': 'parent', 'password': 'parent123'}), (200,), 'login').json()['token']
            run = uuid.uuid4().hex[:12]
            student, other, batch = 's-evidence-' + run, 's-other-' + run, 'ev-' + run
            create_student(base, token, student, '来源测试学生')
            create_student(base, token, other, '另一测试学生')
            route = f'/api/v1/students/{student}/homework'
            REPLY = dict(schemaVersion=2, sourceBlocks=[block('t1', '数学口算20题'), block('t2', '语文朗读13页'), block('t3', '周五家长会', 'NON_TASK')], assignments=[candidate()])
            payload = dict(text='数学口算20题\n语文朗读13页\n周五家长会', importId=batch)
            result = expect(http(base, 'POST', route + '/organize', token=token, payload=payload), (200,), 'organize source evidence').json()
            require(result['needsReview'], 'missing source task must be flagged')
            require(any(f['code'] == 'POSSIBLE_OMISSION' and f['sourceBlockIds'] == ['t2'] for f in result['qualityFlags']), 'independent missing block not flagged')
            require(not any('t3' in f['sourceBlockIds'] for f in result['qualityFlags']), 'notification misclassified as omission')
            saved = expect(http(base, 'GET', route + '/source-evidence/' + batch, token=token), (200,), 'persisted evidence').json()
            require(saved['sourceDocument']['originalText'] == payload['text'], 'raw text lost')
            require(saved['mappings'][0]['sourceBlockIds'] == ['t1'], 'mapping lost')
            expect(http(base, 'POST', route + '/organize', token=token, payload=payload), (200,), 'immutable identical retry')
            REPLY['sourceBlocks'][0]['classification'] = 'NON_TASK'
            expect(http(base, 'POST', route + '/organize', token=token, payload=payload), (400,), 'different batch evidence rejected')
            expect(http(base, 'GET', f'/api/v1/students/{other}/homework/source-evidence/{batch}', token=token), (404,), 'cross-student isolation')
            container = pg_container()
            foreign = str(uuid.uuid4())
            foreign_student = 's-foreign-' + run
            sql(container, f"insert into family values ('{foreign}','隔离家庭',now(),now()); insert into student select '{foreign_student}','{foreign}',name,grade,class_name,semester,textbook_summary,created_at,updated_at from student where id='{student}'")
            expect(http(base, 'GET', f'/api/v1/students/{foreign_student}/homework/source-evidence/{batch}', token=token), (404,), 'cross-family isolation')
            REPLY = dict(schemaVersion=2, sourceBlocks=[block('i1', '数学口算20题', image=True), block('i2', '语文朗读13页', image=True)], assignments=[candidate('i1')])
            image = expect(http(base, 'POST', route + '/organize-image', token=token,
                               payload=dict(imageBase64=base64.b64encode(PNG_1X1).decode(), contentType='image/png', importId='img-' + run)), (200,), 'vision evidence').json()
            require('语文朗读13页' in image['recognizedText'], 'vision source incorrectly rebuilt from generated tasks')
            REPLY = dict(assignments=[candidate('fake')])
            legacy = expect(http(base, 'POST', route + '/organize', token=token, payload={'text': '数学口算20题'}), (200,), 'legacy request/response compatibility').json()
            require(legacy['needsReview'] and len(legacy['assignments']) == 1, 'old API dropped candidate or concealed evidence gap')
            # Reboot keeps independent evidence. Read using the same persisted session.
            proc.terminate(); proc.wait(timeout=30)
            proc = start_backend(log)
            restored = expect(http(base, 'GET', route + '/source-evidence/' + batch, token=token), (200,), 'restart evidence').json()
            require(restored == saved, 'evidence changed across restart')
        contents = log_path.read_text()
        require('[AI-PAYLOAD]' not in contents, 'organizer leaked provider payload in debug mode')
        require('语文朗读13页' not in contents and '数学口算20题' not in contents, 'source content leaked to logs')
        print('HOMEWORK_SOURCE_EVIDENCE_E2E_PASS PostgreSQL/Flyway, HTTP fake-provider, isolation, compatibility, restart, privacy')
    finally:
        if proc and proc.poll() is None:
            proc.terminate(); proc.wait(timeout=30)
        provider.shutdown(); provider.server_close()


if __name__ == '__main__':
    main()
