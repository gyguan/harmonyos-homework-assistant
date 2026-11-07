#!/usr/bin/env python3
"""Real PostgreSQL / HTTP smoke for organizer's transactional review outbox.

The CI backend has no AI API credentials: seed ONLY the AI snapshot table as a
known deterministic fixture, then publish through the REAL backend REST route.
Never mock the publication transaction, worker, or reconciliation database.
"""
from __future__ import annotations

import subprocess
import sys
import time
import uuid
from datetime import datetime, timedelta, timezone

from batch_publish_e2e import assignment, create_student
from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, require


def pg_container() -> str:
    command = ["docker", "ps", "--filter", "ancestor=postgres:17-alpine", "--format", "{{.ID}}"]
    ids = subprocess.check_output(command, text=True).strip().splitlines()
    if len(ids) != 1:
        raise SmokeFailure(f"expected one isolated PostgreSQL CI container; got {len(ids)}")
    return ids[0]


def sql(container: str, query: str) -> str:
    result = subprocess.run(
        ["docker", "exec", container, "psql", "-U", "homework", "-d", "homework",
         "-v", "ON_ERROR_STOP=1", "-Atq", "-c", query],
        text=True, capture_output=True, check=True)
    return result.stdout.strip()


def main() -> int:
    try:
        container = pg_container()
        login = expect(http(DEFAULT_BASE_URL, "POST", "/api/v1/auth/login",
                            payload={"loginName": "parent", "password": "parent123"}),
                       (200,), "organizer outbox login").json()
        token = login["token"]
        run_id = uuid.uuid4().hex[:14]
        student_id = "s-review-" + run_id
        batch_id = "e2e-" + run_id
        ai_one, ai_two = f"ai-{batch_id}-1", f"ai-{batch_id}-2"
        manual = f"manual-{batch_id}-3"
        create_student(DEFAULT_BASE_URL, token, student_id, "纠错队列测试学生")
        family = sql(container, f"select family_id from student where id='{student_id}'")
        require(bool(family), "student family_id is missing")
        day = (datetime.now(timezone(timedelta(hours=8))).date() + timedelta(days=1)).isoformat()
        excerpt = "老师通知：口算20题并抄写第13页"
        for candidate_id, title in [(ai_one, "口算20题原题"), (ai_two, "需删除的重复题")]:
            sql(container, f"""
              insert into homework_organizer_ai_snapshot(
                id,family_id,student_id,batch_id,candidate_id,teacher_name,subject,
                title,instruction,textbook_ref,task_date,expected_minutes,source_excerpt,created_at)
              values (
                '{uuid.uuid4()}', '{family}', '{student_id}', '{batch_id}', '{candidate_id}',
                '', '数学', '{title}', '{title}', 'P10', '{day}', 20,
                '{excerpt}', now())""")

        first = assignment(ai_one, "口算20题已核对")
        second = assignment(manual, "新增订正错题")
        first["assignment"]["instruction"] = "口算20题原题"
        response = expect(http(DEFAULT_BASE_URL, "POST",
                               f"/api/v1/students/{student_id}/assignments/batch",
                               token=token, payload={"batchId": batch_id, "items": [first, second]}),
                          (200,), "atomic publication with outbox").json()
        require(response.get("atomic") is True and response.get("publishedCount") == 2,
                "atomic batch publish response is incomplete")

        queue = sql(container, f"""
          select status || ':' || attempts from homework_review_outbox
          where family_id='{family}' and student_id='{student_id}' and batch_id='{batch_id}'""")
        require(queue.startswith("PENDING:") or queue.startswith("COMPLETED:"),
                "outbox row must be persisted with publishing transaction")

        # The worker is configured to poll every 30s by default; don't fake direct
        # invocation, so this also tests background scheduling and real SQL locking.
        result = queue
        for _ in range(65):
            if result.startswith("COMPLETED:"):
                break
            time.sleep(1)
            result = sql(container, f"""
              select status || ':' || attempts from homework_review_outbox
              where family_id='{family}' and student_id='{student_id}' and batch_id='{batch_id}'""")
        require(result.startswith("COMPLETED:"), "outbox worker did not complete: " + result)

        changes = sql(container, f"""
          select change_type || ':' || field_name || ':' || candidate_id
          from homework_organizer_review_difference
          where family_id='{family}' and student_id='{student_id}' and batch_id='{batch_id}'
          order by change_type,field_name,candidate_id""").splitlines()
        require(f"CHANGED:title:{ai_one}" in changes, "original title correction not recorded")
        require(f"REMOVED:task:{ai_two}" in changes, "removed AI candidate not recorded")
        require(f"ADDED:task:{manual}" in changes, "manual addition not recorded")

        # A retry must not create a second queue record or duplicate corrections.
        retry = expect(http(DEFAULT_BASE_URL, "POST",
                            f"/api/v1/students/{student_id}/assignments/batch",
                            token=token, payload={"batchId": batch_id, "items": [first, second]}),
                       (200,), "outbox idempotent replay").json()
        require(retry["publishedCount"] == 2, "replay changed batch count")
        count = sql(container, f"""
          select count(*) from homework_review_outbox
          where family_id='{family}' and student_id='{student_id}' and batch_id='{batch_id}'""")
        require(count == "1", "replay created duplicate outbox rows")
        print("HOMEWORK_REVIEW_OUTBOX_E2E_PASS")
        return 0
    except (SmokeFailure, subprocess.SubprocessError, KeyError, ValueError, TypeError) as error:
        print("HOMEWORK_REVIEW_OUTBOX_E2E_FAIL: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
