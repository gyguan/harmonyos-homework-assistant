#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from zoneinfo import ZoneInfo
from urllib.parse import quote

from e2e_smoke import DEFAULT_BASE_URL, SmokeFailure, expect, http, require

AUDIO_BYTES = b"xiaoban-voice-material-e2e-audio"
IMAGE_BYTES = b"\x89PNG\r\n\x1a\nvoice-material-e2e-image"

def multipart_voice_assignment(metadata: dict, audio_name: str, image_name: str) -> tuple[bytes, str]:
    boundary = "----xiaoban-legacy-voice-e2e-" + uuid.uuid4().hex
    parts = [
        f"--{boundary}".encode(), b'Content-Disposition: form-data; name="metadata"',
        b"Content-Type: application/json", b"", json.dumps(metadata, ensure_ascii=False).encode("utf-8"),
        f"--{boundary}".encode(), f'Content-Disposition: form-data; name="audio"; filename="{audio_name}"'.encode(),
        b"Content-Type: audio/mpeg", b"", AUDIO_BYTES,
        f"--{boundary}".encode(), f'Content-Disposition: form-data; name="images"; filename="{image_name}"'.encode(),
        b"Content-Type: image/png", b"", IMAGE_BYTES, f"--{boundary}--".encode(), b"",
    ]
    return b"\r\n".join(parts), f"multipart/form-data; boundary={boundary}"

def multipart_file(field: str, filename: str, content_type: str, content: bytes) -> tuple[bytes, str]:
    boundary = "----xiaoban-voice-material-e2e-" + uuid.uuid4().hex
    body = b"\r\n".join([
        f"--{boundary}".encode(), f'Content-Disposition: form-data; name="{field}"; filename="{filename}"'.encode(),
        f"Content-Type: {content_type}".encode(), b"", content, f"--{boundary}--".encode(), b"",
    ])
    return body, f"multipart/form-data; boundary={boundary}"

def create_student(base_url: str, token: str, student_id: str) -> None:
    expect(http(base_url, "PUT", "/api/v1/students", token=token, payload={
        "id": student_id, "name": "语音素材E2E学生", "grade": "二年级",
        "className": "语音素材班", "semester": "上学期", "textbookSummary": "E2E教材",
    }), (200,), "create voice-material student")

def create_batch(base_url: str, token: str, student_id: str) -> str:
    result = expect(http(base_url, "POST", f"/api/v1/students/{student_id}/voice-material-batches", token=token),
                    (200,), "create voice-material batch").json()
    require(bool(result.get("id")), "voice-material batch id missing")
    return result["id"]

def register_package(base_url: str, token: str, batch_id: str, name: str, subject: str) -> dict:
    return expect(http(base_url, "POST", f"/api/v1/voice-material-batches/{batch_id}/packages",
        token=token, payload={"directoryName": name, "subjectCode": subject, "title": "",
                             "expectedMinutes": 15, "dueAtEpochMs": 0, "assignmentType": "EXTRA"}),
        (200,), f"register package {name}").json()

def upload(base_url: str, token: str, package_id: str, resource_type: str,
           name: str, sort_order: int, content: bytes, content_type: str) -> dict:
    body, multipart_type = multipart_file("file", name, content_type, content)
    path = (f"/api/v1/voice-material-packages/{package_id}/files"
            f"?resourceType={quote(resource_type)}&relativeName={quote(name)}&sortOrder={sort_order}")
    return expect(http(base_url, "POST", path, token=token, raw=body, content_type=multipart_type),
                  (200,), f"upload {resource_type} {name}").json()

def list_resources(base_url: str, token: str, assignment_id: str, names: list[str]) -> None:
    resources = expect(http(base_url, "GET", f"/api/v1/assignments/{assignment_id}/resources", token=token),
                       (200,), "list assignment resources").json()
    require([x.get("originalName") for x in resources] == names, "assignment resource names mismatch")
    for item in resources:
        path = item.get("downloadPath")
        expect(http(base_url, "GET", path), (401,), "resource auth guard")
        require(len(expect(http(base_url, "GET", path, token=token), (200,), "resource download").body) > 0,
                "resource download empty")

def main() -> int:
    base_url = DEFAULT_BASE_URL
    try:
        token = expect(http(base_url, "POST", "/api/v1/auth/login",
            payload={"loginName": "parent", "password": "parent123"}), (200,), "voice login").json()["token"]
        run_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
        student_id = f"voice-material-{run_id}"
        create_student(base_url, token, student_id)

        # Existing compatibility boundary: legacy voice assignment still works.
        legacy_id = f"legacy-voice-{run_id}"
        metadata = {"id": legacy_id, "assignmentType": "EXTRA", "subject": "语文",
            "subjectCode": "CHINESE", "contentType": "NORMAL", "title": "旧版手工语音兼容验证",
            "instruction": "兼容验证", "textbookRef": "", "dueText": "", "dueAtEpochMs": 0,
            "dueTimezone": "Asia/Shanghai", "status": "NOT_STARTED", "sourceLabel": "legacy",
            "sourceExcerpt": "", "expectedMinutes": 10, "startedAtEpochMs": 0,
            "finishedAtEpochMs": 0, "elapsedSeconds": 0, "reviewNote": ""}
        body, ctype = multipart_voice_assignment(metadata, "legacy.mp3", "legacy.png")
        expect(http(base_url, "POST", f"/api/v1/students/{student_id}/assignments/voice",
                    token=token, raw=body, content_type=ctype), (200,), "legacy voice create")
        expect(http(base_url, "DELETE", f"/api/v1/assignments/{legacy_id}", token=token),
               (200, 204), "legacy voice delete")

        batch = create_batch(base_url, token, student_id)
        second = register_package(base_url, token, batch, "002-数学口算", "MATH")
        first = register_package(base_url, token, batch, "001-语文朗读", "CHINESE")

        for package, audio_name, image_name in [
            (second, "math-voice.mp3", "math-scene.png"),
            (first, "chinese-voice.mp3", "chinese-scene.png"),
        ]:
            audio = upload(base_url, token, package["id"], "AUDIO", audio_name, 0, AUDIO_BYTES, "audio/mpeg")
            image = upload(base_url, token, package["id"], "IMAGE", image_name, 1, IMAGE_BYTES, "image/png")
            require(bool(audio.get("assetId")) and bool(image.get("assetId")), "material asset id missing")

        completed = expect(http(base_url, "POST", f"/api/v1/voice-material-batches/{batch}/complete", token=token),
                           (200,), "complete material batch").json()
        require(completed.get("readyCount") == 2 and completed.get("invalidCount") == 0,
                "valid batch must have two reusable READY folders")

        # Folder list is the source-of-truth for available reusable materials.
        folder_page = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders?studentId={quote(student_id)}&status=READY&page=0&size=20",
            token=token), (200,), "query reusable folders").json()
        require(folder_page.get("totalElements") == 2, "folder list must expose two READY folders")
        by_id = {x.get("packageId"): x for x in folder_page.get("items", [])}
        require(by_id[first["id"]].get("usageCount") == 0 and by_id[second["id"]].get("usageCount") == 0,
                "fresh folders must be unused")

        empty_tasks = expect(http(base_url, "GET",
            f"/api/v1/voice-tasks?studentId={quote(student_id)}&page=0&size=20", token=token),
            (200,), "query empty task list").json()
        require(empty_tasks.get("totalElements") == 0, "folder rows must not appear as tasks")

        # Automatic creation chooses the first unused folder but does not consume it.
        auto = expect(http(base_url, "POST",
            f"/api/v1/students/{student_id}/voice-material-packages/auto-create-next", token=token),
            (200,), "auto create first task").json()
        require(auto.get("created") is True and auto.get("packageId") == first["id"],
                "auto creation must choose first unused folder")
        first_assignment = auto["assignmentId"]
        require(first_assignment.startswith("a-voice-"), "voice task id must be unique per task instance")
        list_resources(base_url, token, first_assignment, ["chinese-voice.mp3", "chinese-scene.png"])

        active_tasks = expect(http(base_url, "GET",
            f"/api/v1/voice-tasks?studentId={quote(student_id)}&status=NOT_STARTED&page=0&size=20",
            token=token), (200,), "query created task").json()
        require(active_tasks.get("totalElements") == 1, "task list must contain one real Assignment")
        require(active_tasks["items"][0].get("packageId") == first["id"], "task must retain source folder")

        first_folder = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders/{first['id']}", token=token),
            (200,), "folder detail after first use").json()
        require(first_folder["item"].get("usageCount") == 1, "folder usage count must be 1")
        require(first_folder["item"].get("activeTaskCount") == 1, "folder active task count must be 1")
        require(first_folder["item"].get("folderStatus") == "READY", "used folder must remain reusable READY")

        # A student still has only one active voice task.
        create_payload = {"studentId": student_id, "expectedMinutes": 15, "dueAtEpochMs": 0,
                          "dueText": "", "title": "数学 · 语音作业", "requestId": f"blocked-{run_id}"}
        expect(http(base_url, "POST", f"/api/v1/voice-material-packages/{second['id']}/create-assignment",
                    token=token, payload=create_payload), (409,), "reject second active voice task")

        # Delete first task. Link history must survive, and the same folder can be reused.
        expect(http(base_url, "DELETE", f"/api/v1/assignments/{first_assignment}", token=token),
               (200, 204), "delete first voice task")
        after_delete = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders/{first['id']}", token=token),
            (200,), "folder detail after task deletion").json()
        require(after_delete["item"].get("usageCount") == 1, "deleted task must remain in folder usage history")
        require(after_delete["item"].get("activeTaskCount") == 0, "deleted task must not count as active")
        require(any(not x.get("assignmentExists") for x in after_delete.get("recentTasks", [])),
                "folder history must retain deleted task link")

        request_id = f"reuse-{run_id}"
        reuse_payload = {"studentId": student_id, "expectedMinutes": 18, "dueAtEpochMs": 0,
                         "dueText": "", "title": "语文 · 重复使用验证", "requestId": request_id}
        reused = expect(http(base_url, "POST",
            f"/api/v1/voice-material-packages/{first['id']}/create-assignment",
            token=token, payload=reuse_payload), (200,), "reuse same folder manually").json()
        require(reused.get("created") is True, "same folder must create a second task instance")
        second_assignment = reused["assignmentId"]
        require(second_assignment != first_assignment and second_assignment.startswith("a-voice-"),
                "folder reuse must create a distinct Assignment id")

        retry = expect(http(base_url, "POST",
            f"/api/v1/voice-material-packages/{first['id']}/create-assignment",
            token=token, payload=reuse_payload), (200,), "manual create idempotent retry").json()
        require(retry.get("created") is False and retry.get("assignmentId") == second_assignment,
                "same requestId must resolve to original Assignment")
        list_resources(base_url, token, second_assignment, ["chinese-voice.mp3", "chinese-scene.png"])

        reused_folder = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders/{first['id']}", token=token),
            (200,), "folder detail after reuse").json()
        require(reused_folder["item"].get("usageCount") == 2, "reused folder usage count must become 2")
        require(reused_folder["item"].get("activeTaskCount") == 1, "reused folder must have one active task")
        require(len(reused_folder.get("recentTasks", [])) >= 2, "folder detail must show task history")

        used_page = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders?studentId={quote(student_id)}&usage=USED&page=0&size=20",
            token=token), (200,), "filter used folders").json()
        unused_page = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders?studentId={quote(student_id)}&usage=UNUSED&page=0&size=20",
            token=token), (200,), "filter unused folders").json()
        require(any(x.get("packageId") == first["id"] for x in used_page.get("items", [])),
                "reused folder must appear in USED filter")
        require(any(x.get("packageId") == second["id"] for x in unused_page.get("items", [])),
                "never-used folder must appear in UNUSED filter")

        task_by_folder = expect(http(base_url, "GET",
            f"/api/v1/voice-tasks?studentId={quote(student_id)}&packageId={first['id']}&page=0&size=20",
            token=token), (200,), "query tasks by source folder").json()
        require(task_by_folder.get("totalElements") == 1 and
                task_by_folder["items"][0].get("assignmentId") == second_assignment,
                "task list must include only existing Assignments while preserving folder relation")

        final_packages = expect(http(base_url, "GET",
            f"/api/v1/students/{student_id}/voice-material-packages", token=token),
            (200,), "legacy package list compatibility").json()
        first_legacy = next(x for x in final_packages if x.get("id") == first["id"])
        require(first_legacy.get("status") == "READY", "reused folder must remain READY")
        require(first_legacy.get("hasCreatedBefore") is True, "legacy response must derive historical usage")
        require(first_legacy.get("hasActiveAssignment") is True, "legacy response must derive active link")

        print("VOICE_MATERIAL_E2E_PASS "
              f"studentId={student_id} firstAssignment={first_assignment} reusedAssignment={second_assignment}")
        return 0
    except SmokeFailure as exc:
        print(f"VOICE_MATERIAL_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError, StopIteration) as exc:
        print(f"VOICE_MATERIAL_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
