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


assignment_controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")
assignment_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
assignment_repository = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentRepository.java")
assignment_remote = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
assignment_sync = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")

require('@GetMapping("/students/{studentId}/assignments/page")' in assignment_controller,
        "Assignment API must expose a paged read endpoint")
require("JpaSpecificationExecutor<AssignmentEntity>" in assignment_repository and
        "repository.findAll(listSpecification(" in assignment_service,
        "Assignment filters must be pushed down to the database")
require("PageRequest.of(page, limit" in assignment_service and
        "limit < 1 || limit > 100" in assignment_service,
        "Assignment pagination must have bounded page sizes")
require("/assignments/page?" in assignment_remote and "limit=100" in assignment_remote and
        "while (page < 100)" in assignment_remote,
        "HarmonyOS Assignment reads must consume the paged endpoint with a safety bound")

require('@PostMapping("/students/{studentId}/assignments/sync")' in assignment_controller,
        "Assignment API must expose bounded batch dirty sync")
require("BatchSyncRequest" in assignment_service and "processedCount" in read(
        "backend/src/main/java/com/xiaoban/homework/assignment/AssignmentDtos.java"),
        "backend batch sync contract is incomplete")
require("HomeworkRemoteApi.instance.sync(studentId, chunk)" in assignment_sync and
        "offset += 50" in assignment_sync,
        "dirty assignments must be sent in bounded batches instead of one request per item")

submission_controller = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionController.java")
submission_repository = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionRepository.java")
submission_remote = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")
parent_evidence = read("entry/src/main/ets/application/submission/ParentSubmissionEvidenceService.ets")

require('@GetMapping("/assignments/{assignmentId}/submissions/latest")' in submission_controller and
        "findFirstByFamilyIdAndAssignmentIdOrderBySubmittedAtDesc" in submission_repository,
        "parent review must have an efficient latest-submission endpoint")
require("async latest(assignmentId: string)" in submission_remote and
        "RemoteSubmissionApi.instance.latest" in parent_evidence,
        "HarmonyOS parent review must call latest submission rather than list all history")

tutor_controller = read("backend/src/main/java/com/xiaoban/homework/tutor/TutorController.java")
tutor_service = read("backend/src/main/java/com/xiaoban/homework/tutor/TutorService.java")
tutor_repository = read("backend/src/main/java/com/xiaoban/homework/tutor/TutorMessageRepository.java")
tutor_remote = read("entry/src/main/ets/application/remote/TutorRemoteApi.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")

require("@RequestParam(required = false) Long before" in tutor_controller and
        '@RequestParam(defaultValue = "40") int limit' in tutor_controller,
        "Tutor history must support backward pagination")
require("MODEL_CONTEXT_MESSAGES = 20" in tutor_service and
        "recentHistory(session.id, MODEL_CONTEXT_MESSAGES)" in tutor_service,
        "Tutor model context must be bounded independently from persisted history")
require("findBySessionIdOrderByCreatedAtDesc" in tutor_repository and
        "findBySessionIdAndCreatedAtBeforeOrderByCreatedAtDesc" in tutor_repository,
        "Tutor repository must query bounded recent/older pages")
require("nextBeforeEpochMs" in tutor_remote and "loadOlderTutor" in study and
        "加载更早记录" in study,
        "HarmonyOS Tutor UI must consume paged history on demand")

if errors:
    print("API_EFFICIENCY_P1_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("API_EFFICIENCY_P1_GATE_PASS")
