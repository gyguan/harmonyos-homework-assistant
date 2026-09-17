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


dtos = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentDtos.java")
controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")
batch_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentBatchPublishService.java")
remote = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
client_service = read("entry/src/main/ets/application/import/HomeworkBatchPublishService.ets")
draft_port = read("entry/src/main/ets/domain/port/HomeworkImportDraftRepository.ets")
draft_repo = read("entry/src/main/ets/data/repository/DefaultHomeworkImportDraftRepository.ets")
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
mock_parser = read("entry/src/main/ets/infrastructure/ai/MockHomeworkAssignmentParser.ets")
e2e = read("backend/scripts/batch_publish_e2e.py")
workflow = read(".github/workflows/static-gate.yml")

require("BatchPublishRequest" in dtos and "BatchPublishResponse" in dtos and "boolean atomic" in dtos,
        "batch publish DTO must make atomic semantics explicit")
require('@PostMapping("/students/{studentId}/assignments/batch")' in controller and
        "batchPublishService.publish" in controller,
        "backend must expose the V2 batch publish endpoint")
require("@Transactional" in batch_service and "List<AssignmentDtos.BatchPublishResult>" in batch_service,
        "batch publish service must execute inside one transaction")
require('String expectedAssignmentId = "a-published-" + candidateId' in batch_service,
        "batch publish must derive deterministic Assignment IDs from Candidate IDs")
require("candidateIds.add" in batch_service and "assignmentIds.add" in batch_service,
        "batch publish must reject duplicate Candidate/Assignment IDs before writes")
require("new AssignmentDtos.BatchPublishResponse(true" in batch_service,
        "successful batch response must explicitly declare atomic=true")

require("async batchPublish" in remote and "/assignments/batch" in remote,
        "HarmonyOS remote API must expose batch publish")
require("class HomeworkBatchPublishService" in client_service,
        "Slice 5 must have a batch publish application service")
require("BackendSession.instance.isConnected()" in client_service,
        "real batch publish must require the authoritative family-cloud connection")
require("HomeworkRemoteApi.instance.batchPublish" in client_service,
        "application service must call the authoritative batch endpoint")
require("if (!response.atomic" in client_service and "response.publishedCount !== candidates.length" in client_service,
        "client must reject incomplete/non-atomic batch responses")
require("HomeworkImportDraftRepository" in client_service and "DefaultHomeworkImportDraftRepository" in client_service,
        "batch publish must access Candidate drafts through the draft repository boundary")
require("HomeworkStore" not in client_service,
        "batch publish application service must not access HomeworkStore directly")
require("this.drafts.clearCandidates()" in client_service,
        "Candidate drafts may be cleared only through the repository after validated atomic success")
if "this.drafts.clearCandidates()" in client_service and "if (!response.atomic" in client_service:
    require(client_service.index("this.drafts.clearCandidates()") > client_service.index("if (!response.atomic"),
            "Candidate drafts must not be cleared before atomic response validation")
require("clearCandidates(): void" in draft_port,
        "draft repository port must expose explicit Candidate cleanup")
require("clearCandidates(): void { HomeworkStore.instance.replaceCandidates([]); }" in draft_repo,
        "migration adapter must isolate legacy Candidate cleanup behind the repository")

# Delivery P0: Candidate relative/free-text due dates are normalized exactly once at the
# Candidate -> Assignment publication boundary. Downstream Home/filter/calendar continue to
# consume structured dueAtEpochMs instead of re-parsing dueText.
require("AssignmentDueDate" in client_service and "AssignmentDueDate.resolveDayStart" in client_service,
        "batch publish must use the shared due-date resolver at the Candidate -> Assignment boundary")
require("dueAtEpochMs: this.resolveCandidateDueAt(candidate)" in client_service,
        "published Assignments must materialize structured dueAtEpochMs")
require("dueAtEpochMs: 0" not in client_service,
        "batch publish must not discard Candidate due dates by hard-coding dueAtEpochMs=0")
require("candidateAnchor(candidate.id)" in client_service,
        "relative due dates must be anchored to Candidate/import creation time when available")

# Delivery P0: editing the title must preserve the independently editable teacher instruction.
require("this.copy(item, item.subject, title, item.instruction)" in confirmation,
        "confirmation title edit must preserve teacher instruction")
require("this.copy(item, item.subject, title, title)" not in confirmation,
        "confirmation title edit must never overwrite teacher instruction")

# Real ArkTS compilation catches interface completeness that Python string gates previously missed.
require("expectedMinutes: candidate.expectedMinutes" in mock_parser,
        "mock Candidate parser must populate required expectedMinutes before real ArkTS compilation")

for token in ["idempotent batch retry", "batch conflict must reject whole transaction",
              "failed batch leaked a partially published first assignment"]:
    require(token in e2e, f"real batch publish E2E missing coverage: {token}")
require("Run batch publish E2E" in workflow and "batch_publish_e2e.py" in workflow,
        "CI must run real PostgreSQL batch publish E2E")

if errors:
    print("V2_SLICE5_BATCH_PUBLISH_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE5_BATCH_PUBLISH_GATE_PASS")
