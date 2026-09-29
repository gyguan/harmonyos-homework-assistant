#!/usr/bin/env python3
from __future__ import annotations

import time
import uuid
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, require

ZONE = ZoneInfo("Asia/Shanghai")

def main() -> int:
    base_url = DEFAULT_BASE_URL
    try:
        token = expect(http(base_url, "POST", "/api/v1/auth/login",
            payload={"loginName": "parent", "password": "parent123"}),
            (200,), "scheduled assignment login").json()["token"]

        run_id = str(int(time.time())) + "-" + uuid.uuid4().hex[:8]
        student_id = "scheduled-" + run_id
        expect(http(base_url, "PUT", "/api/v1/students", token=token, payload={
            "id": student_id,
            "name": "定时作业E2E学生",
            "grade": "二年级",
            "className": "定时作业班",
            "semester": "上学期",
            "textbookSummary": "E2E教材",
        }), (200,), "create scheduled student")

        now = datetime.now(ZONE)
        add_minutes = 2 if now.second > 45 else 1
        target = now.replace(second=0, microsecond=0) + timedelta(minutes=add_minutes)

        plan = expect(http(base_url, "POST",
            "/api/v1/students/" + student_id + "/scheduled-assignment-plans",
            token=token, payload={
                "planType": "MANUAL_ASSIGNMENT",
                "name": "E2E 定时阅读",
                "scheduleType": "ONCE",
                "timeOfDay": target.strftime("%H:%M"),
                "weekdays": [],
                "startDate": target.strftime("%Y-%m-%d"),
                "endDate": "",
                "template": {
                    "assignmentType": "EXTRA",
                    "subject": "语文",
                    "subjectCode": "CHINESE",
                    "title": "E2E 定时阅读任务",
                    "instruction": "阅读后复述主要内容",
                    "expectedMinutes": 20,
                    "duePolicy": "AFTER_MINUTES",
                    "dueTime": "",
                    "dueOffsetMinutes": 60,
                },
            }), (200,), "create scheduled plan").json()

        require(plan.get("status") == "ENABLED", "new scheduled plan must be enabled")
        require(plan.get("nextFireAtEpochMs", 0) > 0, "new scheduled plan missing next fire time")

        deadline = time.time() + 95
        created = None
        while time.time() < deadline:
            assignments = expect(http(base_url, "GET",
                "/api/v1/students/" + student_id + "/assignments",
                token=token), (200,), "poll scheduled assignment").json()
            matches = [item for item in assignments
                       if item.get("title") == "E2E 定时阅读任务"
                       and item.get("sourceLabel") == "定时作业"]
            if matches:
                created = matches[0]
                break
            time.sleep(2)

        require(created is not None, "scheduler did not create assignment before timeout")
        require(created["id"].startswith("a-scheduled-"), "scheduled assignment id is not deterministic")
        require(created.get("status") == "NOT_STARTED", "scheduled assignment must start NOT_STARTED")
        require(created.get("assignmentType") == "EXTRA", "scheduled assignment must reuse Assignment EXTRA")
        require(created.get("dueAtEpochMs", 0) > plan["nextFireAtEpochMs"],
                "AFTER_MINUTES due time must be after scheduled fire time")

        plans = expect(http(base_url, "GET",
            "/api/v1/scheduled-assignment-plans?studentId=" + student_id,
            token=token), (200,), "list scheduled plans").json()
        current = next(item for item in plans if item["id"] == plan["id"])
        require(current.get("status") == "ENDED", "one-time plan must end after execution")

        runs = expect(http(base_url, "GET",
            "/api/v1/scheduled-assignment-plans/" + plan["id"] + "/runs",
            token=token), (200,), "list scheduled runs").json()
        require(len(runs) == 1 and runs[0].get("status") == "SUCCESS",
                "scheduled run must be recorded as SUCCESS")
        require(runs[0].get("assignmentId") == created["id"],
                "scheduled run must link created Assignment")

        time.sleep(2)
        assignments = expect(http(base_url, "GET",
            "/api/v1/students/" + student_id + "/assignments",
            token=token), (200,), "verify scheduled idempotency").json()
        matches = [item for item in assignments if item.get("title") == "E2E 定时阅读任务"]
        require(len(matches) == 1, "one scheduled fire created duplicate Assignments")

        print("PASS: scheduled assignment E2E")
        return 0
    except (SmokeFailure, KeyError, StopIteration) as error:
        print("FAIL:", error)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
