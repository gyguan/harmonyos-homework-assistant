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
require("HomeworkStore.instance.replaceCandidates([])" in client_service,
        "Candidate drafts may be cleared only after a validated atomic success response")
require(client_service.index("HomeworkStore.instance.replaceCandidates([])") > client_service.index("if (!response.atomic"),
        "Candidate drafts must not be cleared before atomic response validation")

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
