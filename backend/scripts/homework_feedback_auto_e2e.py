#!/usr/bin/env python3
"""Verify automatic parent feedback learning through real HTTP + PostgreSQL.

No AI key is required: insert an immutable AI snapshot fixture, then run the real
feedback endpoint (including transaction, foreign keys, and experience service).
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
                         (200,), "parent feedback auto-applied").json()
        require(receipt["processingStatus"] == "APPLIED",
                "verified feedback did not auto-apply: " + str(receipt))
        rule_rows = sql(container, f"""select cue || ':' || origin || ':' || active::text
            from homework_teacher_experience where family_id='{family}'
            and student_id='{student_id}' and source_feedback_id='{receipt["id"]}'""")
        require(rule_rows == "听读U*:FEEDBACK_AUTO:true",
                "feedback did not create a scoped active shorthand: " + rule_rows)

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
        require(details["experience"]["cue"] == "听读U*" and
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
            where family_id='{family}' and student_id='{student_id}' and origin='FEEDBACK_AUTO'""")
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

        print("HOMEWORK_FEEDBACK_AUTO_E2E_PASS effective scoped rule, idempotency, evidence gate")
        return 0
    except (SmokeFailure, subprocess.SubprocessError, KeyError, ValueError, TypeError) as err:
        print("HOMEWORK_FEEDBACK_AUTO_E2E_FAIL:", err, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
