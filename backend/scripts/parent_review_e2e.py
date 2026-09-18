#!/usr/bin/env python3
from __future__ import annotations

import sys
import time
import uuid

from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, require


def create_assignment(base_url: str, token: str, student_id: str, assignment_id: str, status: str) -> dict:
    return expect(
        http(
            base_url,
            "POST",
            f"/api/v1/students/{student_id}/assignments",
            token=token,
            payload={
                "id": assignment_id,
                "assignmentType": "SCHOOL",
                "subject": "数学",
                "subjectCode": "MATH",
                "title": f"验收作业 {assignment_id[-4:]}",
                "instruction": "完成后提交，供家长验收",
                "textbookRef": "P1",
                "dueText": "今天",
                "dueAtEpochMs": int(time.time() * 1000) + 3600000,
                "dueTimezone": "Asia/Shanghai",
                "status": status,
                "sourceLabel": "parent review e2e",
                "sourceExcerpt": "",
                "expectedMinutes": 10,
                "startedAtEpochMs": 0,
                "finishedAtEpochMs": int(time.time() * 1000) if status == "SUBMITTED" else 0,
                "elapsedSeconds": 60,
                "reviewNote": "",
            },
        ),
        (200,),
        f"create {status} assignment",
    ).json()


def review(base_url: str, token: str, assignment_id: str, version: int, decision: str, note: str) -> dict:
    result = expect(
        http(
            base_url,
            "POST",
            f"/api/v1/assignments/{assignment_id}/review",
            token=token,
            payload={"decision": decision, "version": version, "note": note},
        ),
        (200,),
        f"review {decision}",
    ).json()
    require(isinstance(result, dict), f"{decision} did not return assignment JSON")
    return result


def main() -> int:
    base_url = DEFAULT_BASE_URL
    try:
        login = expect(
            http(base_url, "POST", "/api/v1/auth/login", payload={"loginName": "parent", "password": "parent123"}),
            (200,),
            "parent review login",
        ).json()
        token = login["token"]
        run_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
        student_id = f"review-student-{run_id}"
        approve_id = f"review-approve-{run_id}"
        rework_id = f"review-rework-{run_id}"
        invalid_id = f"review-invalid-{run_id}"

        expect(
            http(base_url, "PUT", "/api/v1/students", token=token, payload={
                "id": student_id,
                "name": "验收学生",
                "grade": "三年级",
                "className": "验收班",
                "semester": "上学期",
                "textbookSummary": "验收教材",
            }),
            (200,),
            "create review student",
        )

        approve_source = create_assignment(base_url, token, student_id, approve_id, "SUBMITTED")
        rework_source = create_assignment(base_url, token, student_id, rework_id, "SUBMITTED")
        invalid_source = create_assignment(base_url, token, student_id, invalid_id, "NOT_STARTED")

        edited = expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/assignments/{invalid_id}/details",
                token=token,
                payload={
                    "version": int(invalid_source["version"]),
                    "title": "家长已调整任务标题",
                    "instruction": "完成第 1-3 题，注意验算",
                    "textbookRef": "P18",
                    "dueText": "明天 20:30",
                    "dueAtEpochMs": int(time.time() * 1000) + 86400000,
                    "dueTimezone": "Asia/Shanghai",
                    "expectedMinutes": 35,
                },
            ),
            (200,),
            "parent edit assignment details",
        ).json()
        require(edited.get("title") == "家长已调整任务标题", "parent edit did not persist title")
        require(edited.get("instruction") == "完成第 1-3 题，注意验算", "parent edit did not persist instruction")
        require(edited.get("textbookRef") == "P18", "parent edit did not persist textbook ref")
        require(int(edited.get("expectedMinutes", 0)) == 35, "parent edit did not persist expected minutes")
        require(edited.get("status") == "NOT_STARTED", "parent edit must not alter assignment status")
        require(int(edited.get("version", -1)) > int(invalid_source["version"]),
                "parent edit did not advance optimistic version")

        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/assignments/{invalid_id}/details",
                token=token,
                payload={
                    "version": int(invalid_source["version"]),
                    "title": "过期版本",
                    "expectedMinutes": 20,
                },
            ),
            (409,),
            "stale parent assignment edit version conflict",
        )

        expect(
            http(
                base_url,
                "PUT",
                f"/api/v1/assignments/{approve_id}/details",
                token=token,
                payload={
                    "version": int(approve_source["version"]),
                    "title": "提交后不应允许修改",
                    "expectedMinutes": 20,
                },
            ),
            (400,),
            "reject parent edit after submission",
        )

        expect(
            http(
                base_url,
                "POST",
                f"/api/v1/assignments/{approve_id}/review",
                token=token,
                payload={"decision": "APPROVE", "version": int(approve_source["version"]) + 99, "note": ""},
            ),
            (409,),
            "stale parent review version conflict",
        )

        approved = review(base_url, token, approve_id, int(approve_source["version"]), "APPROVE", "完成得很好")
        require(approved.get("status") == "COMPLETED", "APPROVE did not move assignment to COMPLETED")
        require(approved.get("reviewNote") == "完成得很好", "APPROVE did not persist review note")
        require(int(approved.get("version", -1)) > int(approve_source["version"]), "APPROVE did not advance version")

        expect(
            http(
                base_url,
                "POST",
                f"/api/v1/assignments/{rework_id}/review",
                token=token,
                payload={"decision": "RETURN_REWORK", "version": int(rework_source["version"]), "note": "   "},
            ),
            (400,),
            "reject rework without reason",
        )

        reworked = review(
            base_url, token, rework_id, int(rework_source["version"]), "RETURN_REWORK", "第 3 题步骤不完整，请订正")
        require(reworked.get("status") == "NEEDS_REWORK", "RETURN_REWORK did not move assignment to NEEDS_REWORK")
        require(reworked.get("reviewNote") == "第 3 题步骤不完整，请订正", "rework reason was not persisted")
        require(int(reworked.get("startedAtEpochMs", -1)) == 0, "RETURN_REWORK did not clear active timing")
        require(int(reworked.get("finishedAtEpochMs", -1)) == 0, "RETURN_REWORK did not reopen finished timing")

        expect(
            http(
                base_url,
                "POST",
                f"/api/v1/assignments/{invalid_id}/review",
                token=token,
                payload={"decision": "APPROVE", "version": int(invalid_source["version"]), "note": ""},
            ),
            (400,),
            "reject review outside SUBMITTED",
        )

        print(f"PARENT_REVIEW_E2E_PASS studentId={student_id} approve={approve_id} rework={rework_id}")
        return 0
    except SmokeFailure as exc:
        print(f"PARENT_REVIEW_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError) as exc:
        print(f"PARENT_REVIEW_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
