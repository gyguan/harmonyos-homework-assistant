#!/usr/bin/env python3
from __future__ import annotations

import sys
import time
import uuid

from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, require


def create_student(base_url: str, token: str, student_id: str, name: str) -> None:
    expect(http(base_url, "PUT", "/api/v1/students", token=token, payload={
        "id": student_id,
        "name": name,
        "grade": "三年级",
        "className": "Batch班",
        "semester": "上学期",
        "textbookSummary": "Batch教材",
    }), (200,), f"create student {student_id}")


def assignment(candidate_id: str, title: str) -> dict:
    return {
        "candidateId": candidate_id,
        "assignment": {
            "id": f"a-published-{candidate_id}",
            "assignmentType": "SCHOOL",
            "subject": "数学",
            "subjectCode": "MATH",
            "title": title,
            "instruction": title,
            "textbookRef": "P10",
            "dueText": "明天",
            "dueAtEpochMs": 0,
            "dueTimezone": "Asia/Shanghai",
            "status": "NOT_STARTED",
            "sourceLabel": "batch e2e",
            "sourceExcerpt": title,
            "expectedMinutes": 20,
            "startedAtEpochMs": 0,
            "finishedAtEpochMs": 0,
            "elapsedSeconds": 0,
            "reviewNote": "",
        },
    }


def main() -> int:
    base_url = DEFAULT_BASE_URL
    try:
        login = expect(http(base_url, "POST", "/api/v1/auth/login",
                            payload={"loginName": "parent", "password": "parent123"}),
                       (200,), "batch publish login").json()
        token = login["token"]
        run_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
        target_student = f"batch-target-{run_id}"
        other_student = f"batch-other-{run_id}"
        create_student(base_url, token, target_student, "批量发布学生")
        create_student(base_url, token, other_student, "冲突学生")

        first_candidate = f"batch-first-{run_id}"
        second_candidate = f"batch-second-{run_id}"
        response = expect(http(base_url, "POST",
                               f"/api/v1/students/{target_student}/assignments/batch",
                               token=token,
                               payload={"items": [assignment(first_candidate, "批量作业一"),
                                                  assignment(second_candidate, "批量作业二")]}),
                          (200,), "successful atomic batch publish").json()
        require(response.get("atomic") is True, "batch response must explicitly declare atomic semantics")
        require(int(response.get("publishedCount", 0)) == 2, "batch publish count mismatch")
        require(len(response.get("results", [])) == 2, "batch publish result count mismatch")

        # Repeating the exact same batch is idempotent because Assignment IDs are derived from Candidate IDs.
        retry = expect(http(base_url, "POST",
                            f"/api/v1/students/{target_student}/assignments/batch",
                            token=token,
                            payload={"items": [assignment(first_candidate, "批量作业一"),
                                               assignment(second_candidate, "批量作业二")]}),
                       (200,), "idempotent batch retry").json()
        require(int(retry.get("publishedCount", 0)) == 2, "idempotent retry did not resolve all candidates")

        conflict_candidate = f"batch-conflict-{run_id}"
        expect(http(base_url, "POST", f"/api/v1/students/{other_student}/assignments", token=token,
                    payload=assignment(conflict_candidate, "其他孩子已有作业")["assignment"]),
               (200,), "create cross-student conflict assignment")

        rollback_candidate = f"batch-rollback-{run_id}"
        expect(http(base_url, "POST", f"/api/v1/students/{target_student}/assignments/batch", token=token,
                    payload={"items": [assignment(rollback_candidate, "必须回滚的第一项"),
                                       assignment(conflict_candidate, "第二项触发冲突")]}),
               (409,), "batch conflict must reject whole transaction")

        listed = expect(http(base_url, "GET", f"/api/v1/students/{target_student}/assignments", token=token),
                        (200,), "list after failed atomic batch").json()
        ids = {item.get("id") for item in listed}
        require(f"a-published-{rollback_candidate}" not in ids,
                "failed batch leaked a partially published first assignment")
        require(f"a-published-{first_candidate}" in ids and f"a-published-{second_candidate}" in ids,
                "successful batch assignments disappeared")

        print(f"BATCH_PUBLISH_E2E_PASS studentId={target_student}")
        return 0
    except SmokeFailure as exc:
        print(f"BATCH_PUBLISH_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError) as exc:
        print(f"BATCH_PUBLISH_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
