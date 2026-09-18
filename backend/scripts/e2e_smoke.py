#!/usr/bin/env python3
"""Real-environment E2E smoke for Xiaoban Homework backend.

Run once against a real PostgreSQL + Spring Boot backend, then restart Spring Boot
without recreating PostgreSQL and run with --session-only to verify persisted auth.
Uses Python standard library only.
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable
from urllib import error, request

DEFAULT_BASE_URL = "http://localhost:8080"
DEFAULT_TOKEN_FILE = Path(__file__).resolve().parent.parent / ".e2e-session.json"
PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZQmcAAAAASUVORK5CYII="
)


@dataclass
class Resp:
    status: int
    body: bytes
    headers: Any

    def text(self) -> str:
        return self.body.decode("utf-8", errors="replace")

    def json(self) -> Any:
        return None if not self.body else json.loads(self.body.decode("utf-8"))


class SmokeFailure(RuntimeError):
    pass


def fail(message: str) -> None:
    raise SmokeFailure(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def http(
    base_url: str,
    method: str,
    path: str,
    *,
    token: str | None = None,
    payload: Any | None = None,
    raw: bytes | None = None,
    content_type: str | None = None,
    timeout: float = 30.0,
    extra_headers: dict[str, str] | None = None,
) -> Resp:
    headers = {"Accept": "application/json"}
    if extra_headers:
        headers.update(extra_headers)
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = raw
    if payload is not None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
    elif content_type:
        headers["Content-Type"] = content_type
    req = request.Request(base_url.rstrip("/") + path, data=body, headers=headers, method=method)
    try:
        with request.urlopen(req, timeout=timeout) as response:
            return Resp(response.status, response.read(), response.headers)
    except error.HTTPError as exc:
        return Resp(exc.code, exc.read(), exc.headers)
    except error.URLError as exc:
        fail(f"无法访问 backend: {req.full_url}: {exc}")
    raise AssertionError("unreachable")


def expect(response: Resp, statuses: Iterable[int], label: str) -> Resp:
    allowed = tuple(statuses)
    if response.status not in allowed:
        body = response.text().strip().replace("\n", " ")[:500]
        fail(f"{label}: HTTP {response.status}, expected {allowed}; body={body!r}")
    print(f"PASS  {label} -> HTTP {response.status}")
    return response


def multipart_png() -> tuple[bytes, str]:
    boundary = "----xiaoban-e2e-" + uuid.uuid4().hex
    parts = [
        f"--{boundary}".encode(),
        b'Content-Disposition: form-data; name="photos"; filename="e2e-smoke.png"',
        b"Content-Type: image/png",
        b"",
        PNG_1X1,
        f"--{boundary}--".encode(),
        b"",
    ]
    return b"\r\n".join(parts), f"multipart/form-data; boundary={boundary}"


def save_token(path: Path, base_url: str, login: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {
                "baseUrl": base_url,
                "token": login["token"],
                "displayName": login.get("displayName", ""),
                "familyId": login.get("familyId", ""),
                "savedAtEpochMs": int(time.time() * 1000),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def load_token(path: Path) -> dict[str, Any]:
    if not path.exists():
        fail(f"session token file not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read session token file {path}: {exc}")
    require(isinstance(data, dict) and isinstance(data.get("token"), str) and bool(data["token"]),
            f"invalid session token file: {path}")
    return data


def session(base_url: str, token: str) -> dict[str, Any]:
    data = expect(http(base_url, "GET", "/api/v1/auth/session", token=token), (200,), "auth session").json()
    require(isinstance(data, dict) and bool(data.get("displayName")), "auth session missing displayName")
    return data


def patch_assignment(
    base_url: str, token: str, assignment_id: str, version: int, **changes: Any
) -> dict[str, Any]:
    payload = {"version": version, **changes}
    data = expect(
        http(base_url, "PATCH", f"/api/v1/assignments/{assignment_id}", token=token, payload=payload),
        (200,),
        f"patch assignment {changes}",
    ).json()
    require(isinstance(data, dict), "assignment PATCH did not return JSON object")
    return data


def run_session_only(args: argparse.Namespace) -> None:
    saved = load_token(args.token_file)
    base_url = args.base_url or saved.get("baseUrl") or DEFAULT_BASE_URL
    expect(http(base_url, "GET", "/api/v1/health"), (200,), "health")
    current = session(base_url, saved["token"])
    print(f"BACKEND_SESSION_RESUME_PASS displayName={current['displayName']} tokenFile={args.token_file}")


def run_full(args: argparse.Namespace) -> None:
    base_url = args.base_url or DEFAULT_BASE_URL
    expect(http(base_url, "GET", "/api/v1/health"), (200,), "health")

    login = expect(
        http(
            base_url,
            "POST",
            "/api/v1/auth/login",
            payload={"loginName": args.login_name, "password": args.password},
        ),
        (200,),
        "login",
    ).json()
    require(isinstance(login, dict) and bool(login.get("token")), "login response missing token")
    require(bool(login.get("familyId")), "login response missing familyId")
    token = login["token"]
    save_token(args.token_file, base_url, login)
    print(f"PASS  session token saved -> {args.token_file}")
    session(base_url, token)

    run_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
    student_id = f"e2e-student-{run_id}"
    delete_id = f"e2e-delete-{run_id}"
    assignment_id = f"e2e-assignment-{run_id}"

    student_payload = {
        "id": student_id,
        "name": "E2E学生",
        "grade": "三年级",
        "className": "E2E班",
        "semester": "上学期",
        "textbookSummary": "E2E教材",
    }
    created_student = expect(
        http(base_url, "PUT", "/api/v1/students", token=token, payload=student_payload),
        (200,),
        "create student",
    ).json()
    require(created_student.get("id") == student_id, "created student id mismatch")

    student_payload["className"] = "E2E班-已更新"
    updated_student = expect(
        http(base_url, "PUT", "/api/v1/students", token=token, payload=student_payload),
        (200,),
        "update student",
    ).json()
    require(updated_student.get("className") == "E2E班-已更新", "student update not persisted")

    disposable = dict(student_payload)
    disposable.update({"id": delete_id, "name": "E2E待删除学生"})
    expect(http(base_url, "PUT", "/api/v1/students", token=token, payload=disposable), (200,),
           "create disposable student")
    expect(http(base_url, "DELETE", f"/api/v1/students/{delete_id}", token=token), (200, 204),
           "delete disposable student")
    students = expect(http(base_url, "GET", "/api/v1/students", token=token), (200,), "list students").json()
    require(any(item.get("id") == student_id for item in students), "created student missing from list")
    require(not any(item.get("id") == delete_id for item in students), "deleted student still present")

    due_at_ms = int(time.time() * 1000) + 24 * 60 * 60 * 1000
    assignment_payload = {
        "id": assignment_id,
        "assignmentType": "SCHOOL",
        "subject": "数学",
        "subjectCode": "MATH",
        "title": "E2E 作业",
        "instruction": "完成 1 道 E2E 验证题",
        "textbookRef": "E2E P1",
        "dueText": "明天",
        "dueAtEpochMs": due_at_ms,
        "dueTimezone": "Asia/Shanghai",
        "status": "NOT_STARTED",
        "sourceLabel": "backend e2e smoke",
        "sourceExcerpt": "E2E source evidence",
        "expectedMinutes": 10,
        "startedAtEpochMs": 0,
        "finishedAtEpochMs": 0,
        "elapsedSeconds": 0,
        "reviewNote": "",
    }
    assignment = expect(
        http(
            base_url,
            "POST",
            f"/api/v1/students/{student_id}/assignments",
            token=token,
            payload=assignment_payload,
        ),
        (200,),
        "create assignment",
    ).json()
    require(assignment.get("id") == assignment_id, "created assignment id mismatch")
    require(assignment.get("assignmentType") == "SCHOOL", "assignmentType not persisted")
    require(assignment.get("subjectCode") == "MATH", "subjectCode not persisted")
    require(int(assignment.get("dueAtEpochMs", 0)) == due_at_ms, "dueAtEpochMs not persisted")

    filtered = expect(
        http(base_url, "GET",
             f"/api/v1/students/{student_id}/assignments?type=SCHOOL&subjectCode=MATH&status=NOT_STARTED",
             token=token),
        (200,),
        "filter assignments by type subject and status",
    ).json()
    require(any(item.get("id") == assignment_id for item in filtered),
            "combined assignment filter did not return matching assignment")

    excluded = expect(
        http(base_url, "GET", f"/api/v1/students/{student_id}/assignments?type=EXTRA", token=token),
        (200,),
        "filter assignments by non-matching type",
    ).json()
    require(not any(item.get("id") == assignment_id for item in excluded),
            "type filter returned a SCHOOL assignment for EXTRA")

    by_date = expect(
        http(base_url, "GET",
             f"/api/v1/students/{student_id}/assignments?from={due_at_ms - 1000}&to={due_at_ms + 1000}",
             token=token),
        (200,),
        "filter assignments by structured dueAt range",
    ).json()
    require(any(item.get("id") == assignment_id for item in by_date),
            "structured dueAt range filter did not return matching assignment")

    version0 = int(assignment["version"])

    updated = patch_assignment(base_url, token, assignment_id, version0, title="E2E 作业-已更新")
    version1 = int(updated["version"])
    require(version1 > version0, "assignment version did not advance after PATCH")

    expect(
        http(
            base_url,
            "PATCH",
            f"/api/v1/assignments/{assignment_id}",
            token=token,
            payload={"version": version0, "title": "stale write must fail"},
        ),
        (409,),
        "stale assignment version conflict",
    )

    in_progress = patch_assignment(base_url, token, assignment_id, version1, status="IN_PROGRESS")
    ready = patch_assignment(base_url, token, assignment_id, int(in_progress["version"]), status="READY_TO_SUBMIT")

    conversation = expect(
        http(base_url, "GET", f"/api/v1/assignments/{assignment_id}/tutor", token=token),
        (200,),
        "load Tutor conversation",
    ).json()
    require(isinstance(conversation, dict) and "available" in conversation,
            "Tutor conversation missing available flag")

    tutor = expect(
        http(
            base_url,
            "POST",
            f"/api/v1/assignments/{assignment_id}/tutor/messages",
            token=token,
            payload={
                "text": "我不知道怎么开始，请先给我一个提示。",
                "guidanceFirst": True,
                "directAnswerAllowed": False,
            },
            timeout=args.tutor_timeout,
        ),
        (200,),
        "ask Tutor",
    ).json()
    require(isinstance(tutor, dict) and "available" in tutor, "Tutor response missing available flag")
    if args.expect_tutor_available:
        require(tutor.get("available") is True, f"expected Tutor available=true, notice={tutor.get('notice')!r}")
        messages = tutor.get("messages") or []
        require(
            any(str(message.get("role", "")).upper() == "ASSISTANT" and message.get("content") for message in messages),
            "Tutor available but no assistant message returned",
        )
        print("PASS  Tutor real-model response available")
    elif args.expect_tutor_unavailable:
        require(tutor.get("available") is False, "expected Tutor fallback available=false")
        require(bool(tutor.get("notice")), "Tutor fallback missing notice")
        print(f"PASS  Tutor fallback -> {tutor.get('notice')}")
    else:
        print(f"PASS  Tutor mode observed -> available={tutor.get('available')} notice={tutor.get('notice')!r}")

    stale_body, stale_content_type = multipart_png()
    expect(
        http(
            base_url,
            "POST",
            f"/api/v1/assignments/{assignment_id}/submissions?version={int(in_progress['version'])}",
            token=token,
            raw=stale_body,
            content_type=stale_content_type,
        ),
        (409,),
        "stale submission version conflict",
    )

    body, content_type = multipart_png()
    create_response = expect(
        http(
            base_url,
            "POST",
            f"/api/v1/assignments/{assignment_id}/submissions?version={int(ready['version'])}",
            token=token,
            raw=body,
            content_type=content_type,
        ),
        (200,),
        "upload submission photo",
    ).json()
    require(isinstance(create_response, dict), "submission create response must be an object")
    submission = create_response.get("submission") or {}
    authoritative = create_response.get("assignment") or {}
    require(authoritative.get("status") == "SUBMITTED",
            "submission response must include authoritative SUBMITTED assignment")
    require(int(authoritative.get("version", -1)) > int(ready["version"]),
            "submission response assignment version did not advance")

    photos = submission.get("photos") or []
    require(len(photos) == 1, "submission did not return exactly one photo")
    download_path = photos[0].get("downloadPath")
    require(isinstance(download_path, str) and download_path.startswith("/api/v1/submission-photos/"),
            "submission photo missing authenticated downloadPath")

    expect(http(base_url, "GET", download_path), (401,), "photo download rejects unauthenticated request")
    downloaded = expect(http(base_url, "GET", download_path, token=token), (200,),
                        "photo download with bearer token")
    require(len(downloaded.body) > 0, "authenticated photo download returned empty body")

    submissions = expect(
        http(base_url, "GET", f"/api/v1/assignments/{assignment_id}/submissions", token=token),
        (200,),
        "list submissions",
    ).json()
    require(any(item.get("id") == submission.get("id") for item in submissions),
            "new submission missing from assignment submission list")

    assignments = expect(
        http(base_url, "GET", f"/api/v1/students/{student_id}/assignments", token=token),
        (200,),
        "list assignments",
    ).json()
    saved = next((item for item in assignments if item.get("id") == assignment_id), None)
    require(saved is not None, "created assignment missing from list")
    require(saved.get("status") == "SUBMITTED", "submission did not move assignment to SUBMITTED")
    require(int(saved.get("version", -1)) == int(authoritative["version"]),
            "persisted assignment version differs from authoritative submission response")

    print(f"BACKEND_E2E_SMOKE_PASS studentId={student_id} assignmentId={assignment_id} tokenFile={args.token_file}")
    print("NEXT  restart Spring Boot (keep PostgreSQL), then run with --session-only")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run real-environment Xiaoban backend E2E smoke checks")
    parser.add_argument("--base-url", default=None,
                        help=f"backend base URL; full mode defaults to {DEFAULT_BASE_URL}; session-only reuses token file")
    parser.add_argument("--login-name", default="parent", help="bootstrap/login account (default: parent)")
    parser.add_argument("--password", default="parent123", help="bootstrap/login password (default: parent123)")
    parser.add_argument("--token-file", type=Path, default=DEFAULT_TOKEN_FILE,
                        help=f"session token file (default: {DEFAULT_TOKEN_FILE})")
    parser.add_argument("--session-only", action="store_true",
                        help="only validate the saved bearer token; use after restarting backend")
    parser.add_argument("--tutor-timeout", type=float, default=90.0,
                        help="Tutor HTTP timeout in seconds (default: 90)")
    tutor = parser.add_mutually_exclusive_group()
    tutor.add_argument("--expect-tutor-available", action="store_true",
                       help="fail unless configured model returns an assistant message")
    tutor.add_argument("--expect-tutor-unavailable", action="store_true",
                       help="fail unless Tutor explicitly falls back with available=false")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.session_only:
            run_session_only(args)
        else:
            run_full(args)
        return 0
    except SmokeFailure as exc:
        print(f"BACKEND_E2E_SMOKE_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        print(f"BACKEND_E2E_SMOKE_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
