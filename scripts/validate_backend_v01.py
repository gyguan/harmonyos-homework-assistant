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
sync = read("entry/src/main/ets/application/remote/HomeworkSyncService.ets")
settings = read("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
remote_submission = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")

require("<version>4.1.1</version>" in pom, "backend must pin Spring Boot 4.1.1")
require("<java.version>21</java.version>" in pom, "backend must target Java 21")
require("spring-boot-starter-data-jpa" in pom and "postgresql" in pom and "flyway-core" in pom,
        "backend must keep the simple Spring Boot + JPA + PostgreSQL + Flyway stack")
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
        "sync service must push/pull through HomeworkRemoteApi and update HomeworkStore")
require("云端连接" in settings and "BackendAuthService" in settings,
        "parent settings must provide an explicit backend connection surface")
require("request.uploadFile" in remote_submission and "internal://cache/" in remote_submission,
        "remote photo submission must use the HarmonyOS cache-backed upload API")

if errors:
    print("BACKEND_V01_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("BACKEND_V01_GATE_PASS")
