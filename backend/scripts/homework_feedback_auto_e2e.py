#!/usr/bin/env python3
"""Verify feedback persistence and scoped experience details without AI credentials.

No AI key is configured in CI. A matching report must remain PENDING_AI,
never falsely claim APPLIED. Seed a separate representative AI experience row
only for the details/read-isolation contract; model output is covered by unit tests.
"""
from __future__ import annotations

import subprocess
import sys
import uuid

from batch_publish_e2e import create_student
from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, require
from homework_review_outbox_e2e import pg_container, sql


def main() -> int:
    try:
        container = pg_container()
        login = expect(http(DEFAULT_BASE_URL, "POST", "/api/v1/auth/login",
                            payload={"loginName": "parent", "password": "parent123"}),
                       (200,), "automatic-feedback login").json()
        token = login["token"]
        run = uuid.uuid4().hex[:14]
        student_id = "s-feedback-" + run
        batch = "auto-" + run
        candidate = "ai-" + batch + "-1"
        create_student(DEFAULT_BASE_URL, token, student_id, "自动学习测试学生")
        family = sql(container, f"select family_id from student where id='{student_id}'")
        require(bool(family), "family ID not found")

        source = "英语：听读U4"
        sql(container, f"""
          insert into homework_organizer_ai_snapshot(
            id,family_id,student_id,batch_id,candidate_id,teacher_name,subject,
            title,instruction,textbook_ref,task_date,expected_minutes,source_excerpt,created_at)
          values ('{uuid.uuid4()}','{family}','{student_id}','{batch}','{candidate}',
            '','英语','听读U4','听读U4','英语课本',current_date,10,'{source}',now())""")
        payload = {
            "clientRequestId": "feedback-" + run,
            "candidateId": candidate,
            "batchId": batch,
            "teacherName": "",
            "subject": "英语",
            "feedbackTypeCode": "SHORTHAND",
            "sourceLabel": "家长录入文字",
            "sourceExcerpt": source,
            "originalTitle": "听读U4",
            "currentTitle": "听读课本第4单元课文",
            "details": "听读U后面数字代表英语课本单元号，应该完整展开",
        }
        path = f"/api/v1/students/{student_id}/homework/feedback"
        receipt = expect(http(DEFAULT_BASE_URL, "POST", path, token=token, payload=payload),
                         (200,), "feedback saved when AI unavailable").json()
        require(receipt["processingStatus"] == "PENDING_AI",
                "unavailable model must not claim learning success: " + str(receipt))
        count = sql(container, f"""select count(*) from homework_teacher_experience
            where family_id='{family}' and student_id='{student_id}'
            and source_feedback_id='{receipt["id"]}'""")
        require(count == "0", "AI-disabled backend silently manufactured an experience")

        # Model-produced experience representation: seed a separate record to
        # verify detailed access and provenance without making external AI calls.
        seeded_id = str(uuid.uuid4())
        sql(container, f"""
          insert into homework_teacher_experience(
            id, family_id, student_id, teacher_name, subject, cue, interpretation,
            example_source, example_result, origin, active, source_feedback_id,
            created_at, updated_at)
          values ('{seeded_id}','{family}','{student_id}','学科归属:英语',
            '英语','听读','适用条件：听读课本的单元简写；整理要求：按本次出现的单元号展开作业',
            '{source}','听读课本第4单元课文','FEEDBACK_AI',true,
            '{receipt["id"]}',now(),now())""")

        # Complete experience detail must include the original untruncated
        # parent feedback, before/after titles, source and timestamps.
        experience_id = sql(container, f"""select id from homework_teacher_experience
            where family_id='{family}' and student_id='{student_id}'
            and source_feedback_id='{receipt["id"]}'""")
        require(bool(experience_id), "auto-learned experience id missing")
        detail_path = (f"/api/v1/students/{student_id}/homework/"
                       f"teacher-experiences/{experience_id}")
        details = expect(http(DEFAULT_BASE_URL, "GET", detail_path, token=token),
                         (200,), "full saved experience details").json()
        require(details["experience"]["id"] == experience_id,
                "detail endpoint returned another experience")
        require(details["experience"]["cue"] == "听读" and
                details["experience"]["exampleSource"] == source,
                "detail endpoint lost complete stored experience fields")
        require(bool(details["experience"].get("createdAt")) and
                bool(details["experience"].get("updatedAt")),
                "experience detail omitted timestamps")
        require(details["feedback"]["details"] == payload["details"] and
                details["feedback"]["originalTitle"] == payload["originalTitle"] and
                details["feedback"]["currentTitle"] == payload["currentTitle"],
                "linked parent feedback contents were truncated or missing")

        unrelated_student = "s-unrelated-" + run
        create_student(DEFAULT_BASE_URL, token, unrelated_student, "详情隔离测试学生")
        denied_path = (f"/api/v1/students/{unrelated_student}/homework/"
                       f"teacher-experiences/{experience_id}")
        expect(http(DEFAULT_BASE_URL, "GET", denied_path, token=token),
               (404,), "other student cannot read saved experience detail")

        replay = expect(http(DEFAULT_BASE_URL, "POST", path, token=token, payload=payload),
                        (200,), "idempotent feedback replay").json()
        require(replay["id"] == receipt["id"], "retry created another feedback")
        count = sql(container, f"""select count(*) from homework_teacher_experience
            where family_id='{family}' and student_id='{student_id}' and origin='FEEDBACK_AI'""")
        require(count == "1", "retry created duplicate learned rules")

        # No matching authoritative source means the report is preserved but not learned.
        missing = dict(payload)
        missing["clientRequestId"] = "feedback-no-snapshot-" + run
        missing["candidateId"] = "ai-" + batch + "-missing"
        pending = expect(http(DEFAULT_BASE_URL, "POST", path, token=token, payload=missing),
                         (200,), "feedback missing evidence").json()
        require(pending["processingStatus"] == "PENDING_EVIDENCE",
                "unverified candidate falsely reported effective")
        count = sql(container, f"""select count(*) from homework_teacher_experience
            where family_id='{family}' and student_id='{student_id}' and origin='FEEDBACK_AUTO'""")
        require(count == "1", "unverified feedback became a learning rule")

        print("HOMEWORK_FEEDBACK_AUTO_E2E_PASS unavailable AI status, saved feedback, detail isolation")
        return 0
    except (SmokeFailure, subprocess.SubprocessError, KeyError, ValueError, TypeError) as err:
        print("HOMEWORK_FEEDBACK_AUTO_E2E_FAIL:", err, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
