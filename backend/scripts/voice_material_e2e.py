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
        f"--{boundary}".encode(),
        b'Content-Disposition: form-data; name="metadata"',
        b"Content-Type: application/json",
        b"",
        json.dumps(metadata, ensure_ascii=False).encode("utf-8"),
        f"--{boundary}".encode(),
        f'Content-Disposition: form-data; name="audio"; filename="{audio_name}"'.encode(),
        b"Content-Type: audio/mpeg",
        b"",
        AUDIO_BYTES,
        f"--{boundary}".encode(),
        f'Content-Disposition: form-data; name="images"; filename="{image_name}"'.encode(),
        b"Content-Type: image/png",
        b"",
        IMAGE_BYTES,
        f"--{boundary}--".encode(),
        b"",
    ]
    return b"\r\n".join(parts), f"multipart/form-data; boundary={boundary}"


def multipart_file(field: str, filename: str, content_type: str, content: bytes) -> tuple[bytes, str]:
    boundary = "----xiaoban-voice-material-e2e-" + uuid.uuid4().hex
    body = b"\r\n".join([
        f"--{boundary}".encode(),
        f'Content-Disposition: form-data; name="{field}"; filename="{filename}"'.encode(),
        f"Content-Type: {content_type}".encode(),
        b"",
        content,
        f"--{boundary}--".encode(),
        b"",
    ])
    return body, f"multipart/form-data; boundary={boundary}"


def create_student(base_url: str, token: str, student_id: str) -> None:
    expect(http(base_url, "PUT", "/api/v1/students", token=token, payload={
        "id": student_id,
        "name": "语音素材E2E学生",
        "grade": "二年级",
        "className": "语音素材班",
        "semester": "上学期",
        "textbookSummary": "E2E教材",
    }), (200,), "create voice-material student")


def create_batch(base_url: str, token: str, student_id: str) -> str:
    result = expect(
        http(base_url, "POST",
             f"/api/v1/students/{student_id}/voice-material-batches",
             token=token),
        (200,), "create voice-material batch",
    ).json()
    batch_id = result.get("id")
    require(isinstance(batch_id, str) and batch_id, "voice-material batch id missing")
    return batch_id


def register_package(
    base_url: str,
    token: str,
    batch_id: str,
    directory_name: str,
    subject_code: str,
) -> dict:
    response = expect(
        http(base_url, "POST",
             f"/api/v1/voice-material-batches/{batch_id}/packages",
             token=token,
             payload={
                 "directoryName": directory_name,
                 "subjectCode": subject_code,
                 "title": "",
                 "expectedMinutes": 15,
                 "dueAtEpochMs": 0,
                 "assignmentType": "EXTRA",
             }),
        (200,), f"register package {directory_name}",
    ).json()
    require(response.get("subjectCode") == subject_code,
            f"package subjectCode not persisted for {directory_name}")
    require(response.get("directoryName") == directory_name,
            f"package directoryName not persisted for {directory_name}")
    return response


def upload(
    base_url: str,
    token: str,
    package_id: str,
    resource_type: str,
    name: str,
    sort_order: int,
    content: bytes,
    content_type: str,
) -> dict:
    body, multipart_type = multipart_file("file", name, content_type, content)
    path = (
        f"/api/v1/voice-material-packages/{package_id}/files"
        f"?resourceType={quote(resource_type)}"
        f"&relativeName={quote(name)}"
        f"&sortOrder={sort_order}"
    )
    return expect(
        http(base_url, "POST", path, token=token, raw=body, content_type=multipart_type),
        (200,), f"upload {resource_type} {name}",
    ).json()


def package_by_name(items: list[dict], directory_name: str) -> dict:
    found = next((item for item in items if item.get("directoryName") == directory_name), None)
    require(found is not None, f"missing package {directory_name}")
    return found


def list_resources(
    base_url: str, token: str, assignment_id: str, expected_names: list[str] | None = None
) -> list[dict]:
    resources = expect(
        http(base_url, "GET", f"/api/v1/assignments/{assignment_id}/resources", token=token),
        (200,), f"list resources {assignment_id}",
    ).json()
    require(isinstance(resources, list) and len(resources) == 2,
            f"assignment {assignment_id} must have exactly 2 resources")
    require(resources[0].get("resourceType") == "AUDIO",
            "first voice resource must be AUDIO")
    require(resources[1].get("resourceType") == "IMAGE",
            "second voice resource must be IMAGE")
    if expected_names is not None:
        names = [item.get("originalName") for item in resources]
        require(names == expected_names,
                f"assignment resource names crossed shared-asset references: {names!r}")
    return resources


def assert_downloads(base_url: str, token: str, resources: list[dict], label: str) -> None:
    for item in resources:
        path = item.get("downloadPath")
        require(isinstance(path, str) and path.startswith("/api/v1/assignment-resources/"),
                f"{label}: invalid resource download path")
        expect(http(base_url, "GET", path), (401,), f"{label} unauthenticated resource rejection")
        downloaded = expect(http(base_url, "GET", path, token=token), (200,),
                            f"{label} authenticated resource download")
        require(len(downloaded.body) > 0, f"{label}: downloaded resource is empty")


def main() -> int:
    base_url = DEFAULT_BASE_URL
    try:
        login = expect(
            http(base_url, "POST", "/api/v1/auth/login",
                 payload={"loginName": "parent", "password": "parent123"}),
            (200,), "voice-material login",
        ).json()
        token = login["token"]

        run_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
        student_id = f"voice-material-{run_id}"
        create_student(base_url, token, student_id)

        race_student_id = f"voice-material-race-{run_id}"
        create_student(base_url, token, race_student_id)
        with ThreadPoolExecutor(max_workers=2) as executor:
            create_future = executor.submit(
                http, base_url, "POST",
                f"/api/v1/students/{race_student_id}/voice-material-batches",
                token=token,
            )
            delete_future = executor.submit(
                http, base_url, "DELETE", f"/api/v1/students/{race_student_id}", token=token
            )
            race_create = create_future.result()
            race_delete = delete_future.result()
        race_statuses = (race_create.status, race_delete.status)
        require(
            race_statuses in ((200, 409), (404, 200), (404, 204)),
            f"student delete/material batch race escaped business boundary: {race_statuses!r}",
        )

        pending_student_id = f"voice-material-pending-{run_id}"
        create_student(base_url, token, pending_student_id)
        create_batch(base_url, token, pending_student_id)
        expect(
            http(base_url, "DELETE", f"/api/v1/students/{pending_student_id}", token=token),
            (409,), "reject student deletion while voice-material batch exists",
        )

        legacy_assignment_id = f"legacy-voice-{run_id}"
        legacy_metadata = {
            "id": legacy_assignment_id,
            "assignmentType": "EXTRA",
            "subject": "语文",
            "subjectCode": "CHINESE",
            "contentType": "NORMAL",
            "title": "旧版手工语音兼容验证",
            "instruction": "验证原有语音作业接口在共享媒体迁移后仍可使用",
            "textbookRef": "",
            "dueText": "",
            "dueAtEpochMs": 0,
            "dueTimezone": "Asia/Shanghai",
            "status": "NOT_STARTED",
            "sourceLabel": "legacy voice compatibility",
            "sourceExcerpt": "",
            "expectedMinutes": 10,
            "startedAtEpochMs": 0,
            "finishedAtEpochMs": 0,
            "elapsedSeconds": 0,
            "reviewNote": "",
        }
        legacy_body, legacy_type = multipart_voice_assignment(
            legacy_metadata, "legacy-voice.mp3", "legacy-scene.png")
        legacy_created = expect(
            http(
                base_url, "POST",
                f"/api/v1/students/{student_id}/assignments/voice",
                token=token, raw=legacy_body, content_type=legacy_type,
            ),
            (200,), "create legacy manual voice assignment",
        ).json()
        require((legacy_created.get("assignment") or {}).get("contentType") == "AUDIO_IMAGE",
                "legacy manual voice API must continue forcing AUDIO_IMAGE")
        legacy_resources = legacy_created.get("resources") or []
        require(len(legacy_resources) == 2,
                "legacy manual voice assignment must persist audio + image resources")
        require([item.get("originalName") for item in legacy_resources] ==
                ["legacy-voice.mp3", "legacy-scene.png"],
                "legacy manual voice resource metadata changed after MediaAsset migration")
        assert_downloads(base_url, token, legacy_resources, "legacy manual voice assignment")
        legacy_download_paths = [item.get("downloadPath") for item in legacy_resources]
        expect(
            http(base_url, "DELETE", f"/api/v1/assignments/{legacy_assignment_id}", token=token),
            (200, 204), "delete legacy manual voice assignment",
        )
        for path in legacy_download_paths:
            expect(http(base_url, "GET", path, token=token), (404,),
                   "legacy manual voice resource removed with assignment")

        batch_id = create_batch(base_url, token, student_id)

        # Register in reverse lexical order to prove consumption uses directoryName ordering.
        second = register_package(base_url, token, batch_id, "002-数学口算", "MATH")
        first = register_package(base_url, token, batch_id, "001-语文朗读", "CHINESE")

        shared_audio_asset_id = ""
        shared_image_asset_id = ""
        package_file_names = {
            second["id"]: ("math-voice.mp3", "math-scene.png"),
            first["id"]: ("chinese-voice.mp3", "chinese-scene.png"),
        }
        for package in (second, first):
            package_id = package["id"]
            audio_name, image_name = package_file_names[package_id]
            if package_id == first["id"]:
                with ThreadPoolExecutor(max_workers=2) as executor:
                    futures = [
                        executor.submit(
                            upload, base_url, token, package_id, "AUDIO", audio_name, 0,
                            AUDIO_BYTES, "audio/mpeg"
                        )
                        for _ in range(2)
                    ]
                    concurrent_audio = [future.result() for future in futures]
                require(concurrent_audio[0].get("id") == concurrent_audio[1].get("id"),
                        "concurrent retry created duplicate package file")
                audio = concurrent_audio[0]
            else:
                audio = upload(base_url, token, package_id, "AUDIO", audio_name, 0,
                               AUDIO_BYTES, "audio/mpeg")
            image = upload(base_url, token, package_id, "IMAGE", image_name, 1,
                           IMAGE_BYTES, "image/png")
            require(bool(audio.get("assetId")) and bool(image.get("assetId")),
                    "uploaded material file missing assetId")

            if not shared_audio_asset_id:
                shared_audio_asset_id = audio["assetId"]
                shared_image_asset_id = image["assetId"]
            else:
                require(audio.get("assetId") == shared_audio_asset_id,
                        "identical audio bytes were not deduplicated to one MediaAsset")
                require(image.get("assetId") == shared_image_asset_id,
                        "identical image bytes were not deduplicated to one MediaAsset")

            # Retrying the exact same file upload must resolve to the same package-file row.
            retry = upload(base_url, token, package_id, "AUDIO", audio_name, 0,
                           AUDIO_BYTES, "audio/mpeg")
            require(retry.get("id") == audio.get("id"),
                    "material file response-loss retry created a duplicate package file")

        completed = expect(
            http(base_url, "POST",
                 f"/api/v1/voice-material-batches/{batch_id}/complete",
                 token=token),
            (200,), "complete voice-material batch",
        ).json()
        require(int(completed.get("readyCount", -1)) == 2,
                "voice-material batch must have two READY packages")
        require(int(completed.get("invalidCount", -1)) == 0,
                "valid voice-material batch unexpectedly contains INVALID package")

        expect(
            http(
                base_url, "POST",
                f"/api/v1/voice-material-batches/{batch_id}/packages",
                token=token,
                payload={
                    "directoryName": "003-迟到目录",
                    "subjectCode": "CHINESE",
                    "title": "",
                    "expectedMinutes": 15,
                    "dueAtEpochMs": 0,
                    "assignmentType": "EXTRA",
                },
            ),
            (400,), "reject package registration after batch completion",
        )

        listed = expect(
            http(base_url, "GET",
                 f"/api/v1/students/{student_id}/voice-material-packages",
                 token=token),
            (200,), "list ready voice-material packages",
        ).json()
        names = [item.get("directoryName") for item in listed]
        require(names[:2] == ["001-语文朗读", "002-数学口算"],
                f"voice-material package list is not directory-name ordered: {names!r}")
        require(all(item.get("status") == "READY" for item in listed[:2]),
                "fresh packages must be READY")

        auto_first = expect(
            http(base_url, "POST",
                 f"/api/v1/students/{student_id}/voice-material-packages/auto-create-next",
                 token=token),
            (200,), "daily auto-create first voice task",
        ).json()
        require(auto_first.get("created") is True, "first daily auto-create must create one task")
        require(auto_first.get("packageId") == first.get("id"),
                "daily auto-create did not consume lexically first directory")
        first_assignment = auto_first.get("assignment") or {}
        first_assignment_id = auto_first.get("assignmentId")
        require(first_assignment_id == f"a-voicepkg-{first['id']}",
                "auto-created Assignment id must be deterministic from package id")
        require(first_assignment.get("subjectCode") == "CHINESE",
                "auto-created Assignment lost package subjectCode")
        require(first_assignment.get("contentType") == "AUDIO_IMAGE",
                "auto-created Assignment must keep AUDIO_IMAGE contentType")
        due_at_ms = int(first_assignment.get("dueAtEpochMs", 0))
        require(due_at_ms > 0, "daily auto-created Assignment must receive today's dueAt")
        due_date = datetime.fromtimestamp(
            due_at_ms / 1000, ZoneInfo("Asia/Shanghai")).date().isoformat()
        require(due_date == auto_first.get("businessDate"),
                "daily auto-created Assignment dueAt must fall on the business date")
        require(first_assignment.get("dueText") == "今天",
                "daily auto-created Assignment must expose 今天 as dueText")

        # Same student, same business day: no second automatic task may be consumed.
        auto_second = expect(
            http(base_url, "POST",
                 f"/api/v1/students/{student_id}/voice-material-packages/auto-create-next",
                 token=token),
            (200,), "same-day auto-create guard",
        ).json()
        require(auto_second.get("created") is False,
                "same-day second automatic check must not create another task")
        require(auto_second.get("assignmentId") == first_assignment_id,
                "same-day auto-create guard must resolve the already-created daily task")

        after_daily = expect(
            http(base_url, "GET",
                 f"/api/v1/students/{student_id}/voice-material-packages",
                 token=token),
            (200,), "list packages after daily auto-create",
        ).json()
        first_state = package_by_name(after_daily, "001-语文朗读")
        second_state = package_by_name(after_daily, "002-数学口算")
        require(first_state.get("status") == "CONSUMED",
                "first package not marked CONSUMED")
        require(second_state.get("status") == "READY",
                "same-day second automatic check consumed a second package")

        first_resources = list_resources(
            base_url, token, first_assignment_id,
            ["chinese-voice.mp3", "chinese-scene.png"])
        assert_downloads(base_url, token, first_resources, "first assignment")

        # Manual creation is independent of daily AUTO quota and can consume another READY package.
        manual = expect(
            http(base_url, "POST",
                 f"/api/v1/voice-material-packages/{second['id']}/create-assignment",
                 token=token),
            (200,), "manual create second voice task",
        ).json()
        require(manual.get("created") is True, "manual package creation must create READY package")
        second_assignment_id = manual.get("assignmentId")
        require(second_assignment_id == f"a-voicepkg-{second['id']}",
                "manual Assignment id must be deterministic")
        require((manual.get("assignment") or {}).get("subjectCode") == "MATH",
                "manual Assignment lost package subjectCode")

        manual_retry = expect(
            http(base_url, "POST",
                 f"/api/v1/voice-material-packages/{second['id']}/create-assignment",
                 token=token),
            (200,), "manual create idempotent retry",
        ).json()
        require(manual_retry.get("created") is False,
                "CONSUMED package manual retry must not create a second Assignment")
        require(manual_retry.get("assignmentId") == second_assignment_id,
                "manual retry did not return original Assignment id")

        second_resources = list_resources(
            base_url, token, second_assignment_id,
            ["math-voice.mp3", "math-scene.png"])
        assert_downloads(base_url, token, second_resources, "second assignment before shared delete")

        # Both packages uploaded identical media bytes, so MediaAsset dedup should share the
        # physical files. Deleting one unfinished Assignment must not remove media for the other.
        expect(
            http(base_url, "DELETE", f"/api/v1/assignments/{first_assignment_id}", token=token),
            (200, 204), "delete first shared-media assignment",
        )
        assert_downloads(base_url, token, second_resources, "second assignment after shared delete")

        final_packages = expect(
            http(base_url, "GET",
                 f"/api/v1/students/{student_id}/voice-material-packages",
                 token=token),
            (200,), "list final voice-material packages",
        ).json()
        require(package_by_name(final_packages, "001-语文朗读").get("status") == "CONSUMED",
                "deleting Assignment must not reset consumed package")
        require(package_by_name(final_packages, "002-数学口算").get("status") == "CONSUMED",
                "manual package must remain CONSUMED")

        print(
            "VOICE_MATERIAL_E2E_PASS "
            f"studentId={student_id} autoAssignment={first_assignment_id} "
            f"manualAssignment={second_assignment_id}"
        )
        return 0
    except SmokeFailure as exc:
        print(f"VOICE_MATERIAL_E2E_FAIL: {exc}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError) as exc:
        print(f"VOICE_MATERIAL_E2E_FAIL: unexpected response shape: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
