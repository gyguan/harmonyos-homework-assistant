#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def read(path: str) -> str:
    file = ROOT / path
    if not file.exists():
        errors.append(f"missing required file: {path}")
        return ""
    return file.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


pom = read("backend/pom.xml")
yml = read("backend/src/main/resources/application.yml")
v1 = read("backend/src/main/resources/db/migration/V1__core_schema.sql")
v2 = read("backend/src/main/resources/db/migration/V2__submission_schema.sql")
assignment_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
submission_service = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionService.java")
module = read("entry/src/main/module.json5")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
sync = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
settings = read("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
remote_submission = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")
http_client = read("entry/src/main/ets/application/remote/BackendHttpClient.ets")

require("<version>4.1.1</version>" in pom, "backend must pin Spring Boot 4.1.1")
require("<java.version>21</java.version>" in pom, "backend must target Java 21")
require("spring-boot-starter-data-jpa" in pom and "postgresql" in pom and
        "spring-boot-starter-flyway" in pom and "flyway-database-postgresql" in pom,
        "backend must keep Spring Boot + JPA + PostgreSQL with Boot 4 Flyway auto-configuration")
for forbidden in ["spring-cloud", "kafka", "redis", "rabbitmq", "spring-modulith"]:
    require(forbidden not in pom.lower(), f"backend V0.1 must not introduce {forbidden}")
require("ddl-auto: validate" in yml, "database schema must be owned by Flyway, not Hibernate DDL")
for table in ["family", "account", "student", "assignment"]:
    require(f"create table {table}" in v1.lower(), f"missing core table: {table}")
for table in ["submission", "submission_photo"]:
    require(f"create table {table}" in v2.lower(), f"missing submission table: {table}")
require("e.version != input.version()" in assignment_service and "ApiExceptions.Conflict" in assignment_service,
        "assignment updates must reject stale remote versions")
require("files.size() > 6" in submission_service and "FileStorage" in submission_service,
        "submission service must keep 1-6 photos behind FileStorage")
require('"ohos.permission.INTERNET"' in module, "HarmonyOS module must declare INTERNET permission")
require("replaceAssignmentsForActiveStudent" in store,
        "HomeworkStore must expose a child-scoped remote snapshot replacement method")
require("HomeworkRemoteApi.instance.list" in sync and "replaceAssignmentsForActiveStudent" in sync,
        "Assignment Repository sync must push/pull through HomeworkRemoteApi and update the local cache")
require("assignment.syncDirty && assignment.remoteVersion === existing.version" in sync and
        "dirtyEntries.push({ assignment: assignment, version: assignment.remoteVersion })" in sync and
        "HomeworkRemoteApi.instance.sync(studentId, chunk)" in sync,
        "sync must batch only dirty assignments whose persisted version matches the server snapshot")
require("observedVersions" not in sync,
        "sync ownership metadata must survive process restarts instead of living in an in-memory map")
require("requestSync(): void" in sync and "syncRequested" in sync and "syncRunning" in sync,
        "Assignment Repository must preserve coalesced background sync semantics")
require(not (ROOT / "entry/src/main/ets/application/remote/HomeworkSyncService.ets").exists(),
        "legacy HomeworkSyncService must remain deleted after Repository migration")
require("assignment.candidateId.length === 0" in sync,
        "demo/seed assignments must remain local instead of polluting the backend")
require("云端连接" in settings and "BackendAuthService" in settings,
        "parent settings must provide an explicit backend connection surface")
require("request.uploadFile" not in remote_submission and "@kit.BasicServicesKit" not in remote_submission,
        "remote photo submission must not depend on the device-specific request.uploadFile capability")
require("http.RequestMethod.POST" in remote_submission and "multipart/form-data; boundary=" in remote_submission and
        "extraData: payload.body" in remote_submission and "buildMultipartPayload" in remote_submission,
        "remote photo submission must use NetworkKit HTTP multipart with an ArrayBuffer body")
require("name=\"photos\"" in remote_submission and "sourceUris.length > 6" in remote_submission,
        "multipart upload must preserve the backend photos field and 1-6 photo contract")
require("await client.request" in http_client and "catch {" in http_client and
        "后端请求失败，请检查网络或后端地址" in http_client,
        "BackendHttpClient must explicitly guard request exceptions with a stable error")

if errors:
    print("BACKEND_V01_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("BACKEND_V01_GATE_PASS")
