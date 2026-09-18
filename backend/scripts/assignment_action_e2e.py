#!/usr/bin/env python3
from __future__ import annotations

import sys
import time
import uuid

from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, require


def action(base_url: str, token: str, assignment_id: str, version: int, command: str) -> dict:
    result = expect(
        http(
            base_url,
            "POST",
            f"/api/v1/assignments/{assignment_id}/actions",
            token=token,
            payload={"action": command, "version": version},
        ),
        (200,),
        f"assignment action {command}",
    ).json()
    require(isinstance(result, dict), f"{command} did not return assignment JSON")
    return result


def main() -> int:
    base_url = DEFAULT_BASE_URL
    try:
        login = expect(
            http(base_url, "POST", "/api/v1/auth/login", payload={"loginName": "parent", "password": "parent123"}),
            (200,),
            "action e2e login",
        ).json()
        token = login["token"]
        run_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
        student_id = f"action-student-{run_id}"
        first_id = f"action-first-{run_id}"
        second_id = f"action-second-{run_id}"

        expect(
            http(base_url, "PUT", "/api/v1/students", token=token, payload={
                "id": student_id,
                "name": "Command学生",
                "grade": "三年级",
                "className": "Command班",
                "semester": "上学期",
                "textbookSummary": "Command教材",
            }),
            (200,),
            "create command student",
        )

        def create_assignment(assignment_id: str, title: str) -> dict:
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
                        "title": title,
                        "instruction": "验证服务端权威计时",
                        "textbookRef": "P1",
                        "dueText": "今天",
                        "dueAtEpochMs": int(time.time() * 1000) + 3600000,
                        "dueTimezone": "Asia/Shanghai",
                        "status": "NOT_STARTED",
                        "sourceLabel": "command e2e",
                        "sourceExcerpt": "",
                        "expectedMinutes": 10,
                        "startedAtEpochMs": 0,
                        "finishedAtEpochMs": 0,
                        "elapsedSeconds": 0,
                        "reviewNote": "",
                    },
                ),
                (200,),
                f"create {title}",
            ).json()

        first = create_assignment(first_id, "Command 作业 A")
        second = create_assignment(second_id, "Command 作业 B")

        first_started = action(base_url, token, first_id, int(first["version"]), "START")
        require(first_started.get("status") == "IN_PROGRESS", "START did not move first assignment to IN_PROGRESS")
        require(int(first_started.get("startedAtEpochMs", 0)) > 0, "START did not assign server start time")

        expect(
            http(
                base_url,
                "POST",
                f"/api/v1/assignments/{first_id}/actions",
                token=token,
                payload={"action": "PAUSE", "version": int(first["version"])},
            ),
            (409,),
            "stale action version conflict",
        )

        time.sleep(1.1)
        first_paused = action(base_url, token, first_id, int(first_started["version"]), "PAUSE")
        require(first_paused.get("status") == "PAUSED", "PAUSE did not move assignment to PAUSED")
        require(int(first_paused.get("startedAtEpochMs", -1)) == 0, "PAUSE did not clear active start time")
        require(int(first_paused.get("elapsedSeconds", 0)) >= 1, "PAUSE did not accumulate server elapsed time")

        first_resumed = action(base_url, token, first_id, int(first_paused["version"]), "START")
        require(first_resumed.get("status") == "IN_PROGRESS", "START did not resume PAUSED assignment")
        require(int(first_resumed.get("elapsedSeconds", -1)) >= int(first_paused.get("elapsedSeconds", 0)),
                "resume regressed accumulated elapsed time")

        second_started = action(base_url, token, second_id, int(second["version"]), "START")
        require(second_started.get("status") == "IN_PROGRESS", "second START failed")

        listed = expect(
            http(base_url, "GET", f"/api/v1/students/{student_id}/assignments", token=token),
            (200,),
            "list after second START",
        ).json()
        first_after_second = next((item for item in listed if item.get("id") == first_id), None)
        require(first_after_second is not None and first_after_second.get("status") == "PAUSED",
                "starting second assignment did not server-pause the first active assignment")

        time.sleep(1.1)
        ready = action(base_url, token, second_id, int(second_started["version"]), "READY_TO_SUBMIT")
        require(ready.get("status") == "READY_TO_SUBMIT", "READY_TO_SUBMIT action failed")
        require(int(ready.get("startedAtEpochMs", -1)) == 0, "READY_TO_SUBMIT did not close active timer")
        require(int(ready.get("finishedAtEpochMs", 0)) > 0, "READY_TO_SUBMIT did not set server finish time")
        require(int(ready.get("elapsedSeconds", 0)) >= 1,
                "READY_TO_SUBMIT did not preserve accumulated work time")

        second_resumed = action(base_url, token, second_id, int(ready["version"]), "START")
        require(second_resumed.get("status") == "IN_PROGRESS",
                "START did not return READY_TO_SUBMIT assignment to active work")
        require(int(second_resumed.get("elapsedSeconds", -1)) >= int(ready.get("elapsedSeconds", 0)),
                "continuing from submission preparation reset accumulated work time")
        ready_again = action(
            base_url, token, second_id, int(second_resumed["version"]), "READY_TO_SUBMIT")
        require(ready_again.get("status") == "READY_TO_SUBMIT",
                "second READY_TO_SUBMIT after continue failed")

        # Starting B auto-paused A and advanced A's optimistic version. Simulate the HarmonyOS
        # cache still holding A's pre-pause version, then recover with one single-assignment GET.
        expect(
            http(
                base_url,
                "POST",
                f"/api/v1/assignments/{first_id}/actions",
                token=token,
                payload={"action": "START", "version": int(first_resumed["version"])},
            ),
            (409,),
            "auto-paused assignment stale resume conflict",
        )
        first_latest = expect(
            http(base_url, "GET", f"/api/v1/assignments/{first_id}", token=token),
            (200,),
            "load single assignment for conflict recovery",
        ).json()
        require(first_latest.get("status") == "PAUSED",
                "single-assignment recovery read must observe server auto-pause")
        require(int(first_latest.get("version", 0)) > int(first_resumed["version"]),
                "server auto-pause must advance the assignment version")
        first_recovered = action(base_url, token, first_id, int(first_latest["version"]), "START")
        require(first_recovered.get("status") == "IN_PROGRESS",
                "retry with refreshed single-assignment version must succeed")

        expect(
            http(
                base_url,
                "POST",
                f"/api/v1/assignments/{second_id}/actions",
                token=token,
                payload={"action": "UNKNOWN_ACTION", "version": int(ready_again["version"])},
            ),
            (400,),
            "reject unsupported assignment action",
        )

        print(f"ASSIGNMENT_ACTION_E2E_PASS studentId={student_id} first={first_id} second={second_id}")
        return 0
    except SmokeFailure as exc:
        print(f"ASSIGNMENT_ACTION_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError) as exc:
        print(f"ASSIGNMENT_ACTION_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
