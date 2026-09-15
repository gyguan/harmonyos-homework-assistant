#!/usr/bin/env python3
"""Real-environment smoke test for the Xiaoban Homework backend.

This script intentionally uses only the Python standard library so it can run on the
same machines already used for the repository's static gates.

Typical flow:
  1. Start PostgreSQL and the Spring Boot backend.
  2. Run this script once. It logs in, exercises the main backend APIs, and stores
     the bearer token in backend/.e2e-session.json.
  3. Restart the Spring Boot process without recreating PostgreSQL.
  4. Run this script with --session-only to prove the opaque auth session survives
     a backend restart.
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
class HttpResponse:
    status: int
    body: bytes
    headers: Any

    def text(self) -> str:
        return self.body.decode("utf-8", errors="replace")

    def json(self) -> Any:
        if not self.body:
            return None
        return json.loads(self.body.decode("utf-8"))


class SmokeFailure(RuntimeError):
    pass


def log_pass(message: str) -> None:
    print(f"PASS  {message}")


def fail(message: str) -> None:
    raise SmokeFailure(message)


def call(
    base_url: str,
    method: str,
    path: str,
    *,
    token: str | None = None,
    json_body: Any | None = None,
    raw_body: bytes | None = None,
    content_type: str | None = None,
    timeout: float = 30.0,
) -> HttpResponse:
    url = base_url.rstrip("/") + path
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    body = raw_body
    if json_body is not None:
        body = json.dumps(json_body, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
    elif content_type:
        headers["Content-Type"] = content_type

    req = request.Request(url=url, data=body, headers=headers, method=method)
    try:
        with request.urlopen(req, timeout=timeout) as response:
            return HttpResponse(response.status, response.read(), response.headers)
    except error.HTTPError as exc:
        return HttpResponse(exc.code, exc.read(), exc.headers)
    except error.URLError as exc:
        fail(f"无法访问 backend: {url}: {exc}")
    raise AssertionError("unreachable")


def expect_status(response: HttpResponse, statuses: Iterable[int], label: str) -> HttpResponse:
    allowed = tuple(statuses)
    if response.status not in allowed:
        body = response.text().strip().replace("\n", " ")[:500]
        fail(f"{label}: HTTP {response.status}, expected {allowed}; body={body!r}")
    log_pass(f"{label} -> HTTP {response.status}")
    return response


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def multipart_photo(field_name: str, filename: str, content: bytes, media_type: str) -> tuple[bytes, str]:
    boundary = "----xiaoban-e2e-" + uuid.uuid4().hex
    crlf = b"\r\n"
    chunks = [
        f"--{boundary}".encode(),
        f'Content-Disposition: form-data; name="{field_name}"; filename="{filename}"'.encode(),
        f"Content-Type: {media_type}".encode(),
        b"",
        content,
        f"--{boundary}--".encode(),
        b"",
    ]
    return crlf.join(chunks), f"multipart/form-data; boundary={boundary}"


def save_session(path: Path, base_url: str, token: str, login: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {
                "baseUrl": base_url,
                "token": token,
                "displayName": login.get("displayName", ""),
                "familyId": login.get("familyId", ""),
                "savedAtEpochMs": int(time.time() * 1000),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def load_session(path: Path) -> dict[str, Any]:
    if not path.exists():
        fail(f"session token file not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read session token file {path}: {exc}")
    require(isinstance(data, dict) and isinstance(data.get("token"), str) and data["token"],
            f"invalid session token file: {path}")
    return data


def validate_session(base_url: str, token: str) -> dict[str, Any]:
    response = expect_status(
        call(base_url, "GET", "/api/v1/auth/session", token=token),
        (200,),
        "auth session",
    )
    data = response.json()
    require(isinstance(data, dict) and bool(data.get("displayName")), "auth session missing displayName")
    return data


def patch_assignment(base_url: str, token: str, assignment_id: str, version: int, **changes: Any) -> dict[str, Any]:
    payload = {"version": version}
    payload.update(changes)
    response = expect_status(
        call(base_url, "PATCH", f"/api/v1/assignments/{assignment_id}", token=token, json_body=payload),
        (200,),
        f"patch assignment {changes}",
    )
    data = response.json()
    require(isinstance(data, dict), "assignment PATCH did not return JSON object")
    return data


def run_session_only(args: argparse.Namespace) -> None:
    saved = load_session(args.token_file)
    base_url = args.base_url or saved.get("baseUrl") or DEFAULT_BASE_URL
    expect_status(call(base_url, "GET", "/api/v1/health"), (200,), "health")
    session = validate_session(base_url, saved["token"])
    print(f"BACKEND_SESSION_RESUME_PASS displayName={session['displayName']} tokenFile={args.token_file}")


def run_full(args: argparse.Namespace) -> None:
    base_url = args.base_url or DEFAULT_BASE_URL
    expect_status(call(base_url, "GET", "/api/v1/health"), (200,), "health")

    login_response = expect_status(
        call(
            base_url,
            "POST",
            "/api/v1/auth/login",
            json_body={"loginName": args.login_name, "password": args.password},
        ),
        (200,),
        "login",
    )
    login = login_response.json()
    require(isinstance(login, dict) and bool(login.get("token")), "login response missing token")
    require(bool(login.get("familyId")), "login response missing familyId")
    token = login["token"]
    save_session(args.token_file, base_url, token, login)
    log_pass(f"session token saved -> {args.token_file}")
    validate_session(base_url, token)

    run_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
    student_id = f"e2e-student-{run_id}"
    disposable_student_id = f"e2e-delete-{run_id}"
    assignment_id = f"e2e-assignment-{run_id}"

    student_payload = {
        "id": student_id,
        "name": "E2E学生",
        "grade": "三年级",
        "className": "E2E班",
        "semester": "上学期",
        "textbookSummary": "E2E教材",
    }
    student = expect_status(
        call(base_url, "PUT", "/api/v1/students", token=token, json_body=student_payload),
        (200,),
        "create student",
    ).json()
    require(student.get("id") == student_id, "created student id mismatch")

    student_payload["className"] = "E2E班-已更新"
    updated_student = expect_status(
        call(base_url, "PUT", "/api/v1/students", token=token, json_body=student_payload),
        (200,),
        "update student",
    ).json()
    require(updated_student.get("className") == "E2E班-已更新", "student update not persisted")

    disposable_payload = dict(student_payload)
    disposable_payload.update({"id": disposable_student_id, "name": "E2E待删除学生"})
    expect_status(
        call(base_url, "PUT", "/api/v1/students", token=token, json_body=disposable_payload),
        (200,),
        "create disposable student",
    )
    expect_status(
        call(base_url, "DELETE", f"/api/v1/students/{disposable_student_id}", token=token),
        (200, 204),
        "delete disposable student",
    )

    students = expect_status(call(base_url, "GET", "/api/v1/students", token=token), (200,), "list students").json()
    require(any(item.get("id") == student_id for item in students), "created student missing from list")
    require(not any(item.get("id") == disposable_student_id for item in students), "deleted student still present")

    assignment_payload = {
        "id": assignment_id,
        "subject": "数学",
        "title": "E2E 作业",
        "instruction": "完成 1 道 E2E 验证题",
        "textbookRef": "E2E P1",
        "dueText": "今天",
        "status": "NOT_STARTED",
        "sourceLabel": "backend e2e smoke",
        "sourceExcerpt": "E2E source evidence",
        "expectedMinutes": 10,
        "startedAtEpochMs": 0,
        "finishedAtEpochMs": 0,
        "elapsedSeconds": 0,
        "reviewNote": "",
    }
    assignment = expect_status(
        call(
            base_url,
            "POST",
            f"/api/v1/students/{student_id}/assignments",
            token=token,
            json_body=assignment_payload,
        ),
        (200,),
        "create assignment",
    ).json()
    require(assignment.get("id") == assignment_id, "created assignment id mismatch")
    version0 = int(assignment["version"])

    updated = patch_assignment(base_url, token, assignment_id, version0, title="E2E 作业-已更新")
    version1 = int(updated["version"])
    require(version1 > version0, "assignment version did not advance after PATCH")

    stale = call(
        base_url,
        "PATCH",
        f"/api/v1/assignments/{assignment_id}",
        token=token,
        json_body={"version": version0, "title": "stale write must fail"},
    )
    expect_status(stale, (409,), "stale assignment version conflict")

    in_progress = patch_assignment(base_url, token, assignment_id, version1, status="IN_PROGRESS")
    ready = patch_assignment(base_url, token, assignment_id, int(in_progress["version"]), status="READY_TO_SUBMIT")

    tutor_before = expect_status(
        call(base_url, "GET", f"/api/v1/assignments/{assignment_id}/tutor", token=token),
        (200,),
        "load Tutor conversation",
    ).json()
    require(isinstance(tutor_before, dict) and "available" in tutor_before, "Tutor conversation missing available flag")

    tutor = expect_status(
        call(
            base_url,
            "POST",
            f"/api/v1/assignments/{assignment_id}/tutor/messages",
            token=token,
            json_body={
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
        require(any(message.get("role") == "assistant" and message.get("content") for message in messages),
                "Tutor available but no assistant message returned")
        log_pass("Tutor real-model response available")
    elif args.expect_tutor_unavailable:
        require(tutor.get("available") is False, "expected Tutor fallback available=false")
        require(bool(tutor.get("notice")), "Tutor fallback missing notice")
        log_pass(f"Tutor fallback -> {tutor.get('notice')}")
    else:
        log_pass(f"Tutor mode observed -> available={tutor.get('available')} notice={tutor.get('notice')!r}")

    multipart_body, multipart_type = multipart_photo("photos", "e2e-smoke.png", PNG_1X1, "image/png")
    submission = expect_status(
        call(
            base_url,
            "POST",
            f"/api/v1/assignments/{assignment_id}/submissions",
            token=token,
            raw_body=multipart_body,
            content_type=multipart_type,
        ),
        (200,),
        "upload submission photo",
    ).json()
    photos = submission.get("photos") or []
    require(len(photos) == 1, "submission did not return exactly one photo")
    download_path = photos[0].get("downloadPath")
    require(isinstance(download_path, str) and download_path.startswith("/api/v1/submission-photos/"),
            "submission photo missing authenticated downloadPath")

    unauthenticated_photo = call(base_url, "GET", download_path)
    expect_status(unauthenticated_photo, (401,), "photo download rejects unauthenticated request")
    authenticated_photo = expect_status(
        call(base_url, "GET", download_path, token=token),
        (200,),
        "photo download with bearer token",
    )
    require(len(authenticated_photo.body) > 0, "authenticated photo download returned empty body")

    submissions = expect_status(
        call(base_url, "GET", f"/api/v1/assignments/{assignment_id}/submissions", token=token),
        (200,),
        "list submissions",
    ).json()
    require(any(item.get("id") == submission.get("id") for item in submissions),
            "new submission missing from assignment submission list")

    assignments = expect_status(
        call(base_url, "GET", f"/api/v1/students/{student_id}/assignments", token=token),
        (200,),
        "list assignments",
    ).json()
    saved_assignment = next((item for item in assignments if item.get("id") == assignment_id), None)
    require(saved_assignment is not None, "created assignment missing from list")
    require(saved_assignment.get("status") == "SUBMITTED", "submission did not move assignment to SUBMITTED")
    require(int(saved_assignment.get("version", -1)) >= int(ready["version"]), "assignment version regressed")

    print(
        "BACKEND_E2E_SMOKE_PASS "
        f"studentId={student_id} assignmentId={assignment_id} tokenFile={args.token_file}"
    )
    print("NEXT  restart Spring Boot (keep PostgreSQL), then run the same script with --session-only")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run real-environment Xiaoban backend E2E smoke checks")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help=f"backend base URL (default: {DEFAULT_BASE_URL})")
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
                       help="fail unless the configured model returns an assistant message")
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
