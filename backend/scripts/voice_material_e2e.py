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

AUDIO_BYTES = b"ID3\x04\x00\x00\x00\x00\x00\x00xiaoban-voice-material-e2e-audio"
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
                             "expectedMinutes": 15, "assignmentType": "EXTRA"}),
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
        task_date = datetime.now(ZoneInfo("Asia/Shanghai")).date().isoformat()
        run_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
        student_id = f"voice-material-{run_id}"
        create_student(base_url, token, student_id)

        # Existing compatibility boundary: legacy voice assignment still works.
        legacy_id = f"legacy-voice-{run_id}"
        metadata = {"id": legacy_id, "assignmentType": "EXTRA", "subject": "语文",
            "subjectCode": "CHINESE", "contentType": "NORMAL", "title": "旧版手工语音兼容验证",
            "instruction": "兼容验证", "textbookRef": "", "taskDate": task_date,
            "status": "NOT_STARTED", "sourceLabel": "legacy",
            "sourceExcerpt": "", "expectedMinutes": 10, "startedAtEpochMs": 0,
            "finishedAtEpochMs": 0, "elapsedSeconds": 0, "reviewNote": ""}
        body, ctype = multipart_voice_assignment(metadata, "legacy.mp3", "legacy.png")
        expect(http(base_url, "POST", f"/api/v1/students/{student_id}/assignments/voice",
                    token=token, raw=body, content_type=ctype), (200,), "legacy voice create")
        local_tasks = expect(http(base_url, "GET",
            f"/api/v1/voice-tasks?studentId={quote(student_id)}&page=0&size=20", token=token),
            (200,), "query local-upload voice task").json()
        require(local_tasks.get("totalElements") == 1,
                "voice task query must include local-upload AUDIO_IMAGE Assignment")
        local_item = local_tasks["items"][0]
        require(local_item.get("assignmentId") == legacy_id and local_item.get("packageId") == "" and
                local_item.get("directoryName") == "本地上传",
                "local-upload voice task must not require a source folder link")
        local_detail = expect(http(base_url, "GET", f"/api/v1/voice-tasks/{legacy_id}",
            token=token), (200,), "local-upload voice task detail").json()
        require([x.get("relativeName") for x in local_detail.get("files", [])] ==
                ["legacy.mp3", "legacy.png"],
                "local-upload voice task detail must expose assignment resources")
        require(all(x.get("id") for x in local_detail.get("files", [])),
                "local-upload resources must expose resource ids for Web preview")
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

        # Manual creation is independent from automatic creation: parents may create multiple
        # active voice tasks even while an automatically created task already exists.
        create_payload = {"studentId": student_id, "expectedMinutes": 15, "taskDate": task_date,
                          "title": "数学 · 手工语音作业", "requestId": f"manual-second-{run_id}"}
        manual_second = expect(http(base_url, "POST",
            f"/api/v1/voice-material-packages/{second['id']}/create-assignment",
            token=token, payload=create_payload), (200,), "manual create while auto task active").json()
        require(manual_second.get("created") is True,
                "manual creation must be allowed while another active voice task exists")
        manual_second_assignment = manual_second["assignmentId"]
        require(manual_second_assignment != first_assignment and manual_second_assignment.startswith("a-voice-"),
                "manual task must be a distinct Assignment instance")
        list_resources(base_url, token, manual_second_assignment, ["math-voice.mp3", "math-scene.png"])

        manual_second_retry = expect(http(base_url, "POST",
            f"/api/v1/voice-material-packages/{second['id']}/create-assignment",
            token=token, payload=create_payload), (200,), "manual second task idempotent retry").json()
        require(manual_second_retry.get("created") is False and
                manual_second_retry.get("assignmentId") == manual_second_assignment,
                "same manual requestId must resolve to the original task")

        second_folder = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders/{second['id']}", token=token),
            (200,), "second folder detail after manual create").json()
        require(second_folder["item"].get("usageCount") == 1, "second folder usage count must become 1")
        require(second_folder["item"].get("activeTaskCount") == 1, "second folder must have one active manual task")

        # Automatic creation must stop whenever any effective voice task exists, regardless of
        # whether that task was created automatically or manually.
        auto_blocked = expect(http(base_url, "POST",
            f"/api/v1/students/{student_id}/voice-material-packages/auto-create-next", token=token),
            (200,), "auto skip while active voice tasks exist").json()
        require(auto_blocked.get("created") is False,
                "automatic creation must not add a task while active voice tasks exist")

        # Deleting only one of multiple active tasks must still keep automatic creation blocked.
        expect(http(base_url, "DELETE", f"/api/v1/assignments/{first_assignment}", token=token),
               (200, 204), "delete first automatic voice task")
        after_delete = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders/{first['id']}", token=token),
            (200,), "folder detail after task deletion").json()
        require(after_delete["item"].get("usageCount") == 1, "deleted task must remain in folder usage history")
        require(after_delete["item"].get("activeTaskCount") == 0, "deleted task must not count as active")
        require(any(not x.get("assignmentExists") for x in after_delete.get("recentTasks", [])),
                "folder history must retain deleted task link")

        auto_still_blocked = expect(http(base_url, "POST",
            f"/api/v1/students/{student_id}/voice-material-packages/auto-create-next", token=token),
            (200,), "auto skip while manual task remains active").json()
        require(auto_still_blocked.get("created") is False,
                "automatic creation must remain blocked while a manual voice task is active")

        # Even after every effective task is cleared, the same business day must not auto-create again.
        expect(http(base_url, "DELETE", f"/api/v1/assignments/{manual_second_assignment}", token=token),
               (200, 204), "delete second manual voice task")
        auto_again = expect(http(base_url, "POST",
            f"/api/v1/students/{student_id}/voice-material-packages/auto-create-next", token=token),
            (200,), "enforce daily auto-create limit after all tasks cleared").json()
        require(auto_again.get("created") is False and auto_again.get("assignmentId") == first_assignment,
                "automatic creation must run at most once per business day")

        # Manual creation remains unrestricted by the daily automatic-create limit.
        request_id = f"reuse-{run_id}"
        reuse_payload = {"studentId": student_id, "expectedMinutes": 18, "taskDate": task_date,
                         "title": "语文 · 重复使用验证", "requestId": request_id}
        reused = expect(http(base_url, "POST",
            f"/api/v1/voice-material-packages/{first['id']}/create-assignment",
            token=token, payload=reuse_payload), (200,), "reuse same folder manually").json()
        require(reused.get("created") is True, "same folder must create another manual task instance")
        reused_assignment = reused["assignmentId"]

        parallel_request_id = f"reuse-parallel-{run_id}"
        parallel_payload = {"studentId": student_id, "expectedMinutes": 12, "taskDate": task_date,
                            "title": "语文 · 并行手工语音作业",
                            "requestId": parallel_request_id}
        parallel = expect(http(base_url, "POST",
            f"/api/v1/voice-material-packages/{first['id']}/create-assignment",
            token=token, payload=parallel_payload), (200,), "create parallel manual task from same folder").json()
        require(parallel.get("created") is True,
                "parent must be able to create multiple active manual voice tasks")
        parallel_assignment = parallel["assignmentId"]
        require(len({reused_assignment, parallel_assignment, first_assignment}) == 3,
                "every business create must produce a distinct Assignment id")

        retry = expect(http(base_url, "POST",
            f"/api/v1/voice-material-packages/{first['id']}/create-assignment",
            token=token, payload=reuse_payload), (200,), "manual create idempotent retry").json()
        require(retry.get("created") is False and retry.get("assignmentId") == reused_assignment,
                "same requestId must resolve to original Assignment")
        conflict_payload = {"studentId": student_id, "expectedMinutes": 18, "taskDate": task_date,
                            "title": "冲突幂等键", "requestId": request_id}
        expect(http(base_url, "POST",
            f"/api/v1/voice-material-packages/{second['id']}/create-assignment",
            token=token, payload=conflict_payload), (409,), "reject requestId reuse across folders")
        list_resources(base_url, token, reused_assignment, ["chinese-voice.mp3", "chinese-scene.png"])
        list_resources(base_url, token, parallel_assignment, ["chinese-voice.mp3", "chinese-scene.png"])

        reused_folder = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders/{first['id']}", token=token),
            (200,), "folder detail after parallel manual reuse").json()
        require(reused_folder["item"].get("usageCount") == 3, "reused folder usage count must include all task instances")
        require(reused_folder["item"].get("activeTaskCount") == 2,
                "same reusable folder may back multiple active manual tasks")
        require(len(reused_folder.get("recentTasks", [])) >= 3, "folder detail must preserve task history")

        used_page = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders?studentId={quote(student_id)}&usage=USED&page=0&size=20",
            token=token), (200,), "filter used folders").json()
        unused_page = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders?studentId={quote(student_id)}&usage=UNUSED&page=0&size=20",
            token=token), (200,), "filter unused folders").json()
        require({x.get("packageId") for x in used_page.get("items", [])} >= {first["id"], second["id"]},
                "both historically used folders must appear in USED filter")
        require(unused_page.get("totalElements") == 0,
                "no folder should remain unused after automatic and manual selections")

        task_by_folder = expect(http(base_url, "GET",
            f"/api/v1/voice-tasks?studentId={quote(student_id)}&packageId={first['id']}&page=0&size=20",
            token=token), (200,), "query tasks by source folder").json()
        require(task_by_folder.get("totalElements") == 2,
                "task list must expose both active manual tasks from the same source folder")
        active_ids = {x.get("assignmentId") for x in task_by_folder.get("items", [])}
        require(active_ids == {reused_assignment, parallel_assignment},
                "task list must preserve both active manual task instances")

        final_packages = expect(http(base_url, "GET",
            f"/api/v1/students/{student_id}/voice-material-packages", token=token),
            (200,), "legacy package list compatibility").json()
        first_legacy = next(x for x in final_packages if x.get("id") == first["id"])
        second_legacy = next(x for x in final_packages if x.get("id") == second["id"])
        require(first_legacy.get("status") == "READY" and second_legacy.get("status") == "READY",
                "used folders must remain reusable READY")
        require(first_legacy.get("hasCreatedBefore") is True and second_legacy.get("hasCreatedBefore") is True,
                "legacy response must derive historical usage from task links")
        require(first_legacy.get("hasActiveAssignment") is True,
                "first folder must expose active manually created tasks")
        require(second_legacy.get("hasActiveAssignment") is False,
                "deleted second automatic task must not remain active")

        # ---------- 管理台批量删除 ----------
        # 这一段是本次新增功能的回归重点。最容易踩的坑是
        # voice_material_auto_create_record.package_id 的外键没有 on delete cascade：
        # 不先删记录就删目录，PostgreSQL 会直接报外键冲突，整批回滚。
        expect(http(base_url, "POST", "/api/v1/voice-material-packages/batch-delete",
                    payload={"ids": [first["id"]]}), (401,), "batch delete must require auth")
        expect(http(base_url, "POST", "/api/v1/voice-material-packages/batch-delete",
                    token=token, payload={"ids": []}), (400,), "empty id list must be rejected")
        expect(http(base_url, "POST", "/api/v1/voice-tasks/batch-delete",
                    token=token, payload={"ids": []}), (400,), "empty id list must be rejected")

        # 独立批次放一个专属文件夹，用来验证"删素材不删任务"。
        batch2 = create_batch(base_url, token, student_id)
        third = register_package(base_url, token, batch2, "003-英语听力", "ENGLISH")
        upload(base_url, token, third["id"], "AUDIO", "english-voice.mp3", 0, AUDIO_BYTES, "audio/mpeg")
        upload(base_url, token, third["id"], "IMAGE", "english-scene.png", 1, IMAGE_BYTES, "image/png")
        third_completed = expect(http(base_url, "POST",
            f"/api/v1/voice-material-batches/{batch2}/complete", token=token),
            (200,), "complete third folder batch").json()
        require(third_completed.get("readyCount") == 1, "third folder must become READY")

        third_task = expect(http(base_url, "POST",
            f"/api/v1/voice-material-packages/{third['id']}/create-assignment",
            token=token, payload={"studentId": student_id, "expectedMinutes": 15,
                                  "taskDate": task_date, "title": "英语 · 素材保留验证",
                                  "requestId": f"third-{run_id}"}),
            (200,), "create task from third folder").json()
        third_assignment = third_task["assignmentId"]

        deleted_folder = expect(http(base_url, "POST", "/api/v1/voice-material-packages/batch-delete",
            token=token, payload={"ids": [third["id"]]}), (200,), "batch delete folder").json()
        require(deleted_folder.get("requested") == 1 and deleted_folder.get("deleted") == 1 and
                deleted_folder.get("skipped") == 0,
                "folder batch delete must remove the folder despite the auto-create record FK")
        require([x.get("id") for x in deleted_folder.get("items", [])] == [third["id"]],
                "folder batch delete result must echo the requested id")
        folders_after = expect(http(base_url, "GET",
            f"/api/v1/voice-material-folders?studentId={quote(student_id)}&page=0&size=50", token=token),
            (200,), "folder list after batch delete").json()
        require(third["id"] not in {x.get("packageId") for x in folders_after.get("items", [])},
                "deleted folder must not appear in the folder list")

        # 删素材必须保留任务本身：素材文件是独立引用的，任务要能照常打开和取素材。
        survivor = expect(http(base_url, "GET", f"/api/v1/voice-tasks/{third_assignment}", token=token),
                          (200,), "task must survive folder deletion").json()
        require(survivor["item"].get("assignmentId") == third_assignment,
                "voice task must survive deletion of its source folder")
        require(survivor["item"].get("packageId") == "" and
                survivor["item"].get("directoryName") == "本地上传",
                "task whose source folder was deleted must fall back to local-upload display")
        list_resources(base_url, token, third_assignment, ["english-voice.mp3", "english-scene.png"])

        # 批量删任务：未知 id 要跳过并给出原因，而不是整批失败。
        before_delete = expect(http(base_url, "GET", f"/api/v1/voice-material-folders/{first['id']}",
                                    token=token), (200,),
                               "folder usage before batch task delete").json()["item"]
        require(before_delete.get("usageCount") == 3,
                f"first folder must hold three task links before batch delete "
                f"(usageCount={before_delete.get('usageCount')})")

        unknown_id = f"missing-{run_id}"
        deleted_tasks = expect(http(base_url, "POST", "/api/v1/voice-tasks/batch-delete",
            token=token, payload={"ids": [reused_assignment, parallel_assignment, unknown_id]}),
            (200,), "batch delete voice tasks").json()
        require(deleted_tasks.get("deleted") == 2 and deleted_tasks.get("skipped") == 1,
                "batch task delete must skip unknown ids instead of failing the whole batch")
        skipped_item = next(x for x in deleted_tasks["items"] if not x.get("deleted"))
        require(skipped_item.get("id") == unknown_id and skipped_item.get("reason"),
                "skipped id must carry a reason")

        # 与单条删除保持一致：删任务不清 task_link，所以"已使用次数"历史必须原样保留，
        # 只是这些任务不再计入 activeTaskCount。
        history = expect(http(base_url, "GET", f"/api/v1/voice-material-folders/{first['id']}",
                              token=token), (200,), "folder usage history after batch task delete").json()
        detail = history["item"]
        require(detail.get("usageCount") == before_delete.get("usageCount"),
                "batch task delete must keep folder usage history like the single delete path "
                f"(before={before_delete.get('usageCount')} after={detail.get('usageCount')})")
        require(detail.get("activeTaskCount") == 0,
                "batch deleted tasks must not remain active "
                f"(activeTaskCount={detail.get('activeTaskCount')})")

        # 已完成任务：单条 DELETE 仍然拒绝，批量入口允许（管理台二次确认后走这条）。
        for step in ["IN_PROGRESS", "READY_TO_SUBMIT", "SUBMITTED", "COMPLETED"]:
            current = expect(http(base_url, "GET", f"/api/v1/assignments/{third_assignment}", token=token),
                             (200,), "load assignment before status patch").json()
            patched = expect(http(base_url, "PATCH", f"/api/v1/assignments/{third_assignment}",
                token=token, payload={"version": current["version"], "status": step}),
                (200,), f"patch assignment status {step}").json()
            require(patched.get("status") == step, f"assignment status must advance to {step}")

        expect(http(base_url, "DELETE", f"/api/v1/assignments/{third_assignment}", token=token),
               (400,), "single delete must still reject a completed assignment")
        completed_delete = expect(http(base_url, "POST", "/api/v1/voice-tasks/batch-delete",
            token=token, payload={"ids": [third_assignment]}), (200,), "batch delete completed task").json()
        require(completed_delete.get("deleted") == 1 and completed_delete.get("skipped") == 0,
                "batch delete must allow removing a completed voice task")
        expect(http(base_url, "GET", f"/api/v1/assignments/{third_assignment}", token=token),
               (404,), "completed task must be gone after batch delete")

        # 删掉目录后重新导入同一份内容不能被判重（package_fingerprint 已随目录释放）。
        batch3 = create_batch(base_url, token, student_id)
        reimported = register_package(base_url, token, batch3, "003-英语听力", "ENGLISH")
        upload(base_url, token, reimported["id"], "AUDIO", "english-voice.mp3", 0, AUDIO_BYTES, "audio/mpeg")
        upload(base_url, token, reimported["id"], "IMAGE", "english-scene.png", 1, IMAGE_BYTES, "image/png")
        reimported_done = expect(http(base_url, "POST",
            f"/api/v1/voice-material-batches/{batch3}/complete", token=token),
            (200,), "complete re-imported batch").json()
        require(reimported_done.get("readyCount") == 1 and reimported_done.get("invalidCount") == 0,
                "re-importing the same folder content after deletion must not be rejected as duplicate")

        print("VOICE_MATERIAL_E2E_PASS "
              f"studentId={student_id} firstAssignment={first_assignment} "
              f"reusedAssignment={reused_assignment} parallelAssignment={parallel_assignment}")
        return 0
    except SmokeFailure as exc:
        print(f"VOICE_MATERIAL_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError, StopIteration) as exc:
        print(f"VOICE_MATERIAL_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
