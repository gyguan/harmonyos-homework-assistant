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
import struct
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from batch_publish_e2e import create_student
from e2e_smoke import expect, http, require, SmokeFailure
from homework_review_outbox_e2e import pg_container, sql

def valid_test_png(width=8, height=8):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress((b'\x00' + b'\xff\xff\xff' * width) * height)) + chunk(b'IEND', b''))


IMAGE_SIZES = []
REPLY = {}
CALLS = 0
REVIEW_REPLY = None
VISUAL_REPLY = None


class Provider(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        global CALLS
        CALLS += 1
        if self.headers.get('Transfer-Encoding', '').lower() == 'chunked':
            raw = bytearray()
            while True:
                size = int(self.rfile.readline().split(b';', 1)[0].strip(), 16)
                if size == 0:
                    while self.rfile.readline() not in (b'\r\n', b'\n', b''):
                        pass
                    break
                raw.extend(self.rfile.read(size))
                self.rfile.read(2)
        else:
            raw = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        body = json.loads(raw)
        require('messages' in body, 'expected chat protocol')
        for message in body['messages']:
            if not isinstance(message['content'], list):
                continue
            for part in message['content']:
                if part.get('type') == 'image_url':
                    raw_image = base64.b64decode(part['image_url']['url'].split(',',1)[1])
                    require(raw_image.startswith(b'\x89PNG'), 'expected a lossless PNG')
                    IMAGE_SIZES.append(struct.unpack('>II',raw_image[16:24]))
        reply = VISUAL_REPLY if 'visualReviewVersion=1' in body['messages'][0]['content'] and VISUAL_REPLY is not None else REVIEW_REPLY if 'reviewVersion=2' in body['messages'][0]['content'] and REVIEW_REPLY is not None else REPLY
        data = json.dumps({'choices': [{'message': {'role': 'assistant', 'content': json.dumps(reply, ensure_ascii=False)}}],
                           'usage': {'prompt_tokens': 120, 'completion_tokens': 80, 'prompt_tokens_details': {'cached_tokens': 0, 'image_tokens': 50 if isinstance(body['messages'][-1]['content'],list) else 0}}}).encode()
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
        except (OSError, SmokeFailure):
            pass
        time.sleep(1)
    proc.terminate()
    proc.wait(timeout=30)
    raise RuntimeError('isolated backend startup timed out')


def main():
    global REPLY, REVIEW_REPLY, VISUAL_REPLY
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
            # Low risk stays one call even when a relevant private experience is available.
            family = sql(container, f"select family_id from student where id='{student}'")
            experience = str(uuid.uuid4())
            sql(container, f"""insert into homework_teacher_experience(
                id,family_id,student_id,teacher_name,subject,cue,interpretation,example_source,example_result,origin,active,created_at,updated_at)
                values ('{experience}','{family}','{student}','学科归属:数学','数学','口算',
                '只使用本次原文的题量','口算20题','完成口算20题','FEEDBACK_AI',true,now(),now())""")
            REPLY = dict(schemaVersion=2,sourceBlocks=[block('t1','数学口算20题')],assignments=[candidate()],appliedExperienceIds=[experience])
            calls_before = CALLS
            low = expect(http(base,'POST',route+'/organize',token=token,payload={'text':'数学口算20题'}),(200,),'low risk with experience').json()
            require(CALLS-calls_before == 1 and not low['needsReview'],'low risk incurred extra inference')
            require(low['experiences']['appliedExperienceIds'] == [experience],'applied experience lost evidence provenance')
            # Exact retries in a new import batch hit cache but still persist independent evidence/snapshots.
            calls_before = CALLS
            cache_batch = 'cache-hit-' + run
            cached = expect(http(base,'POST',route+'/organize',token=token,
                                 payload={'text':'数学口算20题','importId':cache_batch}),(200,),'cached new batch').json()
            require(cached == low and CALLS == calls_before, 'identical text did not reuse accepted result')
            hit_evidence = expect(http(base,'GET',route+'/source-evidence/'+cache_batch,token=token),(200,),'cached batch evidence').json()
            require(hit_evidence['mappings'][0]['candidateId'] == 'ai-'+cache_batch+'-1','cached candidate retained old batch identity')
            require(sql(container,f"select count(*) from homework_organizer_ai_snapshot where student_id='{student}' and batch_id='{cache_batch}'") == '1','cached snapshot missing')
            # A direct committed DB change invalidates even without an application mutation hook.
            sql(container,f"update homework_teacher_experience set active=false,updated_at=now() where id='{experience}'")
            REPLY['appliedExperienceIds'] = []
            calls_before = CALLS
            disabled = expect(http(base,'POST',route+'/organize',token=token,payload={'text':'数学口算20题'}),(200,),'disabled experience invalidates cache').json()
            require(CALLS-calls_before == 1 and not disabled['experiences']['retrievedExperienceIds'],'deactivated experience revived cached output')
            # Identical rules with a newer explicit version also invalidate.
            rule_code = sql(container,"select code from homework_organizer_rule where enabled=true and scope='GLOBAL' order by code limit 1")
            require(bool(rule_code),'global migrated rules missing')
            sql(container,f"update homework_organizer_rule set version=version+1,updated_at=now() where code='{rule_code}'")
            calls_before = CALLS
            expect(http(base,'POST',route+'/organize',token=token,payload={'text':'数学口算20题'}),(200,),'rule version invalidates cache')
            require(CALLS-calls_before == 1,'rule version reused old output')
            calls_before = CALLS
            expect(http(base,'POST',f'/api/v1/students/{other}/homework/organize',token=token,payload={'text':'数学口算20题'}),(200,),'cache student isolation')
            require(CALLS-calls_before == 1,'sibling reused personalized cached output')
            calls_before = CALLS
            expect(http(base,'POST',f'/api/v1/students/{foreign_student}/homework/organize',token=token,payload={'text':'数学口算20题'}),(404,),'cache family authorization')
            require(CALLS == calls_before,'foreign request reached inference or cache')
            # A risk can trigger the second call without any experience matching this mixed source.
            REPLY = dict(schemaVersion=2,sourceBlocks=[block('t1','数学口算20题'),block('t2','语文朗读13页')],assignments=[candidate()])
            addition = dict(candidate('t2'),subject='语文',title='朗读13页',instruction='朗读13页',sourceExcerpt='语文朗读13页')
            REVIEW_REPLY = dict(reviewVersion=2,corrections=[],additions=[dict(assignment=addition,reason='原文含遗漏的朗读任务')],blockDecisions=[],appliedExperienceIds=[])
            calls_before = CALLS
            reviewed = expect(http(base,'POST',route+'/organize',token=token,payload={'text':'数学口算20题\n语文朗读13页','importId':'text-review-'+run}),(200,),'targeted risk review').json()
            require(CALLS-calls_before == 2 and len(reviewed['assignments']) == 2 and not reviewed['needsReview'],'targeted correction failed or exceeded two calls')
            revisions = reviewed['sourceDocument']['revisions']
            require(len(revisions) == 1 and revisions[0]['kind'] == 'TEXT_RISK_REVIEW','text review audit missing')
            require(revisions[0]['changes'][0]['before'] is None and revisions[0]['changes'][0]['reason'] == '原文含遗漏的朗读任务','addition reason or initial draft lost')
            saved_review = expect(http(base,'GET',route+'/source-evidence/text-review-'+run,token=token),(200,),'persisted text review audit').json()
            require(saved_review['sourceDocument'] == reviewed['sourceDocument'],'text review audit not persisted with evidence')
            expect(http(base,'GET',f'/api/v1/students/{other}/homework/source-evidence/text-review-'+run,token=token),(404,),'sibling review audit isolation')
            REVIEW_REPLY = None
            REPLY = dict(schemaVersion=2, sourceBlocks=[block('i1', '数学口算20题', image=True), block('i2', '语文朗读13页', image=True)], assignments=[candidate('i1')])
            image = expect(http(base, 'POST', route + '/organize-image', token=token,
                               payload=dict(imageBase64=base64.b64encode(valid_test_png()).decode(), contentType='image/png', importId='img-' + run)), (200,), 'vision evidence').json()
            require('语文朗读13页' in image['recognizedText'], 'vision source incorrectly rebuilt from generated tasks')
            # Image-only cache reads the entire private experience version before lookup.
            REPLY = dict(schemaVersion=2,sourceBlocks=[block('i1','数学口算20题',image=True)],assignments=[candidate('i1')])
            image_payload = dict(imageBase64=base64.b64encode(valid_test_png()).decode(),contentType='image/png')
            calls_before = CALLS
            first_image = expect(http(base,'POST',route+'/organize-image',token=token,payload=image_payload),(200,),'image cache fill').json()
            require(not first_image['needsReview'] and CALLS-calls_before == 1,'image initial inference failed')
            calls_before = CALLS
            warm_image = expect(http(base,'POST',route+'/organize-image',token=token,payload=dict(image_payload,importId='image-hit-'+run)),(200,),'image cache hit').json()
            require(warm_image == first_image and CALLS == calls_before,'image cache changed independent evidence or called AI')
            sql(container,f"update homework_teacher_experience set interpretation='更新后的确认说明',updated_at=now() where id='{experience}'")
            expect(http(base,'POST',route+'/organize-image',token=token,payload=image_payload),(200,),'image-only experience version invalidation')
            require(CALLS-calls_before == 1,'image-only cache ignored experience changes')
            REPLY = dict(assignments=[candidate('fake')])
            legacy = expect(http(base, 'POST', route + '/organize', token=token, payload={'text': '数学口算20题','sourceLabel':'旧接口兼容'}), (200,), 'legacy request/response compatibility').json()
            require(legacy['needsReview'] and len(legacy['assignments']) == 1, 'old API dropped candidate or concealed evidence gap')
            # One located unreadable block may consume the shared second-pass budget.
            unclear = dict(block('i2','看不清','UNRESOLVED',image=True),legibility='UNCLEAR',region=[.25,.25,.5,.5])
            REPLY = dict(schemaVersion=2,sourceBlocks=[block('i1','数学口算20题',image=True),unclear],assignments=[candidate('i1')])
            recovered = dict(candidate('i2'),subject='语文',title='朗读13页',instruction='朗读13页',sourceExcerpt='语文朗读13页')
            VISUAL_REPLY = dict(visualReviewVersion=1,reading=dict(blockId='i2',text='语文朗读13页',legibility='READABLE',classification='TASK',reason='局部文字可辨认'),
                                corrections=[],additions=[dict(assignment=recovered,reason='局部有遗漏任务')],appliedExperienceIds=[])
            vision_batch='vision-review-'+run
            calls_before=CALLS
            visual = expect(http(base,'POST',route+'/organize-image',token=token,payload=dict(image_payload,sourceLabel='局部复核',importId=vision_batch)),(200,),'targeted image review').json()
            require(CALLS-calls_before == 2 and IMAGE_SIZES[-2:] == [(8,8),(4,4)],'visual review did not use exactly one crop inference')
            require(len(visual['assignments']) == 2 and not visual['needsReview'],'visual correction failed')
            require(visual['sourceDocument']['schemaVersion'] == 3 and visual['sourceDocument']['revisions'][0]['before']['text'] == '看不清','original visual evidence lost')
            visual_saved=expect(http(base,'GET',route+'/source-evidence/'+vision_batch,token=token),(200,),'visual audit persistence').json()
            expect(http(base,'GET',f'/api/v1/students/{other}/homework/source-evidence/{vision_batch}',token=token),(404,),'visual audit student isolation')
            VISUAL_REPLY={'invalid':'review'}
            calls_before=CALLS
            failed_visual=expect(http(base,'POST',route+'/organize-image',token=token,payload=dict(image_payload,sourceLabel='局部失败')),(200,),'visual review failure retains draft').json()
            require(CALLS-calls_before == 2 and failed_visual['needsReview'] and len(failed_visual['assignments']) == 1,'visual failure retried or dropped draft')
            require(failed_visual['sourceDocument']['blocks'][-1]['text'] == '看不清','failed visual pass changed original evidence')
            VISUAL_REPLY=None
            # PNG eXIf uses the same TIFF orientation as JPEG APP1. Pixels reaching the
            # external provider are already upright; no second inference is needed.
            upright = valid_test_png(7,3)
            tiff = b'MM'+struct.pack('>HIHHHIHHI',42,8,1,0x0112,3,1,6,0,0)
            kind = b'eXIf'
            chunk = struct.pack('>I',len(tiff))+kind+tiff+struct.pack('>I',zlib.crc32(kind+tiff)&0xffffffff)
            oriented = upright[:33]+chunk+upright[33:]
            REPLY = dict(schemaVersion=2,sourceBlocks=[block('i1','数学口算20题',image=True)],assignments=[candidate('i1')])
            calls_before = CALLS
            expect(http(base,'POST',route+'/organize-image',token=token,
                        payload=dict(imageBase64=base64.b64encode(oriented).decode(),contentType='image/png',importId='orientation-'+run)),(200,),'orientation before inference')
            require(CALLS-calls_before == 1 and IMAGE_SIZES[-1] == (3,7),'orientation added inference or lost pixel dimensions')
            bad = bytearray(oriented); bad[33+8+18:33+8+20] = b'\x00\x09'
            # Recompute CRC so the invalid orientation (not CRC alone) is exercised.
            bad[33+8+26:33+12+26] = struct.pack('>I',zlib.crc32(bad[33+4:33+8+26])&0xffffffff)
            calls_before = CALLS
            expect(http(base,'POST',route+'/organize-image',token=token,
                        payload=dict(imageBase64=base64.b64encode(bad).decode(),contentType='image/png')),(400,),'invalid orientation rejected')
            require(CALLS == calls_before,'malformed orientation reached provider')
            # Reboot keeps independent evidence. Read using the same persisted session.
            proc.terminate(); proc.wait(timeout=30)
            proc = start_backend(log)
            restored = expect(http(base, 'GET', route + '/source-evidence/' + batch, token=token), (200,), 'restart evidence').json()
            require(restored == saved, 'evidence changed across restart')
            visual_restored=expect(http(base,'GET',route+'/source-evidence/'+vision_batch,token=token),(200,),'visual audit restart').json()
            require(visual_restored == visual_saved,'visual evidence revision changed across restart')
        contents = log_path.read_text()
        require('[AI-PAYLOAD]' not in contents, 'organizer leaked provider payload in debug mode')
        require('语文朗读13页' not in contents and '数学口算20题' not in contents, 'source content leaked to logs')
        measurements = [json.loads(line.split('homework_import measurement data=',1)[1]) for line in contents.splitlines()
                        if 'homework_import measurement data=' in line]
        for hit_id in ('cache-hit-'+run,'image-hit-'+run):
            hit = next(row for row in measurements if row['importId'] == hit_id)
            require(hit['cacheHit'] and hit['callCount'] == 0 and hit['tokensIn'] == 0 and hit['tokensOut'] == 0,
                    'cache telemetry fabricated calls or unavailable usage')
        orientation_row = next(row for row in measurements if row['importId'] == 'orientation-'+run)
        require(orientation_row['imagePreparation']['orientation'] == 6 and orientation_row['imagePreparation']['outputWidth'] == 3,
                'orientation measurement missing')
        visual_row=next(row for row in measurements if row['importId'] == vision_batch)
        require(visual_row['callCount'] == 2 and visual_row['reviewTriggered'] and visual_row['visualReview']['width'] == 4,
                'visual review measurement missing')
        require(visual_row['imageTokensIn'] == 100 and visual_row['cachedTokensIn'] == 0,'actual provider detail usage missing')
        require(all(len(call['promptVersion']) == 64 for call in visual_row['aiCalls'])
                and visual_row['aiCalls'][0]['promptVersion'] != visual_row['aiCalls'][1]['promptVersion'],
                'actual primary/review prompt fingerprints missing')
        print('HOMEWORK_SOURCE_EVIDENCE_E2E_PASS PostgreSQL/Flyway, HTTP fake-provider, isolation, compatibility, restart, privacy')
    finally:
        if proc and proc.poll() is None:
            proc.terminate(); proc.wait(timeout=30)
        provider.shutdown(); provider.server_close()


if __name__ == '__main__':
    main()
