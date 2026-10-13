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
draft_local = read("entry/src/main/ets/data/local/HomeworkImportLocalDataSource.ets")
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
confirmation_components = read("entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
assignment_edit_form = read("entry/src/main/ets/components/assignment/AssignmentEditForm.ets")
task_date_picker = read("entry/src/main/ets/components/assignment/TaskDatePickerField.ets")
mock_parser = read("entry/src/main/ets/infrastructure/ai/MockHomeworkAssignmentParser.ets")
task_date_service = read("entry/src/main/ets/domain/service/AssignmentTaskDate.ets")
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
require("HomeworkStore" not in draft_repo and "HomeworkImportLocalDataSource" in draft_repo and
        "clearCandidates(): void { this.local.replaceCandidates([]); }" in draft_repo,
        "draft repository must isolate legacy Candidate cleanup behind HomeworkImportLocalDataSource")
require("HomeworkStore.instance.replaceCandidates(candidates)" in draft_local,
        "legacy import local adapter must preserve Candidate persistence")

# Delivery P0: Candidate task dates are normalized before publication. The publication
# boundary must preserve the absolute YYYY-MM-DD value without inventing a time-of-day.
require("taskDate: candidate.taskDate" in client_service,
        "batch publish must preserve the Candidate absolute taskDate at the publication boundary")
require("dueAtEpochMs" not in client_service and "dueTimezone" not in client_service and
        "dueText" not in client_service,
        "batch publish must not reintroduce legacy deadline fields")
require("SHANGHAI_OFFSET_HOURS: number = 8" in task_date_service and
        "static resolve(value: string" in task_date_service,
        "task-date normalization must remain centralized and Asia/Shanghai based")
require("AssignmentTaskDate.resolve" not in client_service,
        "batch publication must not re-parse relative dates after Candidate confirmation")

# Delivery P0: editing the title must preserve the independently editable teacher instruction.
require("title: this.titleDraft" in confirmation_components and
        "instruction: this.instructionDraft" in confirmation_components,
        "staged confirmation save must preserve title and teacher instruction independently")
require("instruction: this.titleDraft" not in confirmation_components,
        "confirmation title edit must never overwrite teacher instruction")

# Parent-edited task dates must use the same native picker as manually created assignments.
require("AssignmentEditForm" in confirmation_components and
        "TaskDatePickerField" in assignment_edit_form and
        "onChange: (value: string) => this.onTaskDateChange(value)" in assignment_edit_form,
        "confirmation task-date edit must reuse the shared assignment form and native date picker")
require("TextInput({ text: this.item.taskDate })" not in confirmation_components and
        "TextInput({ text: this.taskDate })" not in assignment_edit_form,
        "confirmation task date must not regress to free-text input")
require("DatePicker({" in task_date_picker and "TimePicker({" not in task_date_picker,
        "shared confirmation task-date picker must expose a date control without time-of-day semantics")

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
