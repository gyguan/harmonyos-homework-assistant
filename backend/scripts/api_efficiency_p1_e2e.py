#!/usr/bin/env python3
from __future__ import annotations

import sys
import time
import uuid

from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, multipart_png, require


def create_assignment(base_url: str, token: str, student_id: str, assignment_id: str,
                      title: str, subject: str, subject_code: str, status: str = "NOT_STARTED") -> dict:
    return expect(
        http(
            base_url,
            "POST",
            f"/api/v1/students/{student_id}/assignments",
            token=token,
            payload={
                "id": assignment_id,
                "assignmentType": "SCHOOL",
                "subject": subject,
                "subjectCode": subject_code,
                "title": title,
                "instruction": "P1 API efficiency E2E",
                "textbookRef": "P1",
                "dueText": "今天",
                "dueAtEpochMs": int(time.time() * 1000) + 3600000,
                "dueTimezone": "Asia/Shanghai",
                "status": status,
                "sourceLabel": "api efficiency p1 e2e",
                "sourceExcerpt": "",
                "expectedMinutes": 10,
                "startedAtEpochMs": 0,
                "finishedAtEpochMs": 0,
                "elapsedSeconds": 0,
                "reviewNote": "",
            },
        ),
        (200,),
        f"create assignment {assignment_id}",
    ).json()


def main() -> int:
    base_url = DEFAULT_BASE_URL
    try:
        login = expect(
            http(base_url, "POST", "/api/v1/auth/login",
                 payload={"loginName": "parent", "password": "parent123"}),
            (200,), "P1 efficiency login",
        ).json()
        token = login["token"]
        run_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
        student_id = f"p1-student-{run_id}"

        expect(
            http(base_url, "PUT", "/api/v1/students", token=token, payload={
                "id": student_id,
                "name": "P1学生",
                "grade": "三年级",
                "className": "P1班",
                "semester": "上学期",
                "textbookSummary": "P1教材",
            }),
            (200,), "create P1 student",
        )

        first = create_assignment(base_url, token, student_id, f"p1-math-a-{run_id}", "数学A", "数学", "MATH")
        second = create_assignment(base_url, token, student_id, f"p1-math-b-{run_id}", "数学B", "数学", "MATH")
        create_assignment(base_url, token, student_id, f"p1-english-{run_id}", "英语A", "英语", "ENGLISH")

        page0 = expect(
            http(base_url, "GET",
                 f"/api/v1/students/{student_id}/assignments/page?subjectCode=MATH&page=0&limit=1",
                 token=token),
            (200,), "paged assignment query page 0",
        ).json()
        require(isinstance(page0, dict), "assignment page response must be an object")
        require(len(page0.get("items") or []) == 1, "assignment page 0 must contain one item")
        require(page0.get("hasMore") is True, "assignment page 0 must indicate another page")
        require(int(page0.get("total", 0)) == 2, "database subject filter must return exactly two MATH rows")

        page1 = expect(
            http(base_url, "GET",
                 f"/api/v1/students/{student_id}/assignments/page?subjectCode=MATH&page=1&limit=1",
                 token=token),
            (200,), "paged assignment query page 1",
        ).json()
        require(len(page1.get("items") or []) == 1, "assignment page 1 must contain one item")
        require(page1.get("hasMore") is False, "assignment page 1 must be the last page")

        sync = expect(
            http(
                base_url,
                "POST",
                f"/api/v1/students/{student_id}/assignments/sync",
                token=token,
                payload={"items": [
                    {"id": first["id"], "assignment": {
                        "version": int(first["version"]),
                        "title": "数学A-批量更新",
                    }},
                    {"id": second["id"], "assignment": {
                        "version": int(second["version"]),
                        "title": "数学B-批量更新",
                    }},
                ]},
            ),
            (200,), "batch dirty assignment sync",
        ).json()
        require(int(sync.get("processedCount", 0)) == 2, "batch sync must process two assignments")
        results = sync.get("results") or []
        require(len(results) == 2 and all(item.get("applied") is True for item in results),
                "batch sync must apply both current-version updates")

        ready = create_assignment(
            base_url, token, student_id, f"p1-submit-{run_id}",
            "提交最新证据", "数学", "MATH", status="READY_TO_SUBMIT")
        body, content_type = multipart_png()
        created = expect(
            http(
                base_url,
                "POST",
                f"/api/v1/assignments/{ready['id']}/submissions?version={int(ready['version'])}",
                token=token, raw=body, content_type=content_type,
            ),
            (200,), "create P1 submission",
        ).json()
        submission_id = (created.get("submission") or {}).get("id")
        latest = expect(
            http(base_url, "GET", f"/api/v1/assignments/{ready['id']}/submissions/latest", token=token),
            (200,), "load latest submission",
        ).json()
        require(latest.get("id") == submission_id, "latest submission endpoint returned the wrong submission")

        tutor = expect(
            http(base_url, "GET", f"/api/v1/assignments/{first['id']}/tutor?limit=40", token=token),
            (200,), "paged Tutor conversation",
        ).json()
        require("hasMore" in tutor and "nextBeforeEpochMs" in tutor,
                "Tutor conversation must expose paging metadata")

        print(f"API_EFFICIENCY_P1_E2E_PASS studentId={student_id}")
        return 0
    except SmokeFailure as exc:
        print(f"API_EFFICIENCY_P1_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError) as exc:
        print(f"API_EFFICIENCY_P1_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
