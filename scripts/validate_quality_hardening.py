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


app_config = read("entry/src/main/ets/common/config/AppConfig.ets")
application_yml = read("backend/src/main/resources/application.yml")
bootstrap = read("backend/src/main/java/com/xiaoban/homework/bootstrap/LocalBootstrap.java")
http_props = read("backend/src/main/java/com/xiaoban/homework/common/HttpLogProperties.java")
coordinator = read("backend/src/main/java/com/xiaoban/homework/storage/FileTransactionCoordinator.java")
submission = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionService.java")
assignment = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
resource = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentResourceService.java")
media_asset = read("backend/src/main/java/com/xiaoban/homework/media/MediaAssetService.java")
media_policy = read("backend/src/main/java/com/xiaoban/homework/assignment/VoiceMediaPolicy.java")
submission_client = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")
frontend_state = read("entry/src/main/ets/domain/service/AssignmentStateMachine.ets")
backend_state = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentStatePolicy.java")
migration = read("backend/src/main/resources/db/migration/V22__assignment_status_constraint.sql")
idempotency_migration = read("backend/src/main/resources/db/migration/V23__assignment_create_fingerprint.sql")
assignment_entity = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentEntity.java")
tutor_service = read("backend/src/main/java/com/xiaoban/homework/tutor/TutorService.java")
harmony_workflow = read(".github/workflows/harmony-client-build.yml")

require("BACKEND_BASE_URL: string = ''" in app_config and "http://" not in app_config,
        "release client config must not ship a hardcoded plaintext backend address")
require("enabled: ${BOOTSTRAP_ENABLED:false}" in application_yml and
        "login-name: ${BOOTSTRAP_LOGIN:}" in application_yml and
        "password: ${BOOTSTRAP_PASSWORD:}" in application_yml,
        "backend bootstrap must be disabled and credential-free by default")
require("log-payloads: ${HTTP_LOG_PAYLOADS:false}" in application_yml and
        "private boolean logPayloads = false;" in http_props,
        "HTTP payload logging must be explicit opt-in")
require("BOOTSTRAP_ENABLED=true" in bootstrap and
        "必须显式配置 BOOTSTRAP_LOGIN 和 BOOTSTRAP_PASSWORD" in bootstrap,
        "explicit bootstrap enablement must still require explicit credentials")

require("deleteOnRollback" in coordinator and "deleteAfterCommit" in coordinator and
        "TransactionSynchronizationManager" in coordinator,
        "file lifecycle must be coordinated with database transaction completion")
require("fileTransactions.deleteOnRollback(stored.storagePath())" in submission,
        "submission uploads must delete newly written files on transaction rollback")
require("fileTransactions.deleteAfterCommit(photo.storagePath)" in assignment and
        "fileTransactions.deleteAfterCommit(resource.storagePath)" in assignment,
        "assignment deletion must defer physical file deletion until commit")
require("fileTransactions.deleteOnRollback(stored.storagePath())" in resource and
        "fileTransactions.deleteOnRollback(stored.storagePath())" in media_asset,
        "all direct physical media writes must register rollback cleanup")

require("prefix(image)" in media_policy and "detectImageKind" in media_policy and
        "detectAudioKind" in media_policy and "Content-Type" in media_policy,
        "media policy must validate content signatures, not only extensions")
require("mediaPolicy.validateImage(file)" in submission,
        "submission photos must be validated server-side")
require("uploadContentType" in submission_client and "uploadExtension" in submission_client and
        "Content-Type: ${contentType}" in submission_client,
        "Harmony multipart uploads must preserve the selected image type")

for transition in [
    ("READY_TO_SUBMIT", ["AssignmentStatus.SUBMITTED", "AssignmentStatus.IN_PROGRESS"]),
    ("NEEDS_REWORK", ["AssignmentStatus.IN_PROGRESS", "AssignmentStatus.READY_TO_SUBMIT"]),
    ("OVERDUE", ["AssignmentStatus.IN_PROGRESS", "AssignmentStatus.READY_TO_SUBMIT"]),
]:
    state, targets = transition
    start = frontend_state.find(f"if (from === AssignmentStatus.{state})")
    require(start >= 0, f"frontend state policy missing state block: {state}")
    if start < 0:
        continue
    end = frontend_state.find("\n    if (from === AssignmentStatus.", start + 1)
    if end < 0:
        end = frontend_state.find("\n    return false;", start + 1)
    block = frontend_state[start:end]
    for target in targets:
        require(target in block, f"frontend state policy missing transition {state} -> {target}")
for transition in [
    '"READY_TO_SUBMIT", Set.of("SUBMITTED", "IN_PROGRESS")',
    '"NEEDS_REWORK", Set.of("IN_PROGRESS", "READY_TO_SUBMIT")',
    '"OVERDUE", Set.of("IN_PROGRESS", "READY_TO_SUBMIT")',
]:
    require(transition in backend_state, f"backend state policy missing transition contract: {transition}")
require("e.status = initialStatus(input.status());" in assignment and
        '!"NOT_STARTED".equals(normalized)' in assignment,
        "new assignments must start from NOT_STARTED")
for status in [
    "NOT_STARTED", "IN_PROGRESS", "PAUSED", "READY_TO_SUBMIT",
    "SUBMITTED", "COMPLETED", "NEEDS_REWORK", "OVERDUE",
]:
    require(f"'{status}'" in migration, f"database status constraint missing {status}")

require("createFingerprint" in assignment_entity and
        "createFingerprint(studentId, input)" in assignment and
        "创建内容与原请求不一致" in assignment,
        "assignment create retries must be protected by a stable creation fingerprint")
require("create_fingerprint varchar(64)" in idempotency_migration,
        "assignment create fingerprint must be persisted through a forward Flyway migration")
require("DataIntegrityViolationException" in tutor_service and
        "saveAndFlush(session)" in tutor_service and
        "findByFamilyIdAndAssignmentId" in tutor_service,
        "concurrent first Tutor questions must recover the unique-session race")

require("pull_request:" in harmony_workflow and "HARMONYOS_RUNNER_ENABLED" in harmony_workflow and
        "verify_harmony_client.ps1" in harmony_workflow,
        "real ArkTS compilation must be wired to PRs once the Harmony runner is enabled")

if errors:
    print("QUALITY_HARDENING_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("QUALITY_HARDENING_GATE_PASS")
