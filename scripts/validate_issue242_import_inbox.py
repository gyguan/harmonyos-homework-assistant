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


models = read("entry/src/main/ets/domain/model/ImportModels.ets")
homework_models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
persistence_port = read("entry/src/main/ets/domain/port/HomeworkImportInboxPersistence.ets")
repo_port = read("entry/src/main/ets/domain/port/HomeworkImportInboxRepository.ets")
persistence = read("entry/src/main/ets/infrastructure/persistence/PreferencesHomeworkImportInboxPersistence.ets")
store = read("entry/src/main/ets/data/local/HomeworkImportInboxStore.ets")
repo = read("entry/src/main/ets/data/repository/DefaultHomeworkImportInboxRepository.ets")
draft_repo = read("entry/src/main/ets/data/repository/DefaultHomeworkImportDraftRepository.ets")
service = read("entry/src/main/ets/application/import/HomeworkImportInboxService.ets")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
publish = read("entry/src/main/ets/application/import/HomeworkBatchPublishService.ets")
entry = read("entry/src/main/ets/entryability/EntryAbility.ets")
inbox_page = read("entry/src/main/ets/features/parent/import/HomeworkImportInboxPage.ets")
detail_page = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
fixture = read("entry/src/main/ets/experimental/importinbox/Issue242ImportInboxFixture.ets")
state_machine = read("entry/src/main/ets/domain/service/AssignmentStateMachine.ets")

for value in ["CLIPBOARD", "SCREENSHOT", "SHARE", "SCREEN_CAPTURE"]:
    require(value in models, f"Import V2 source type missing: {value}")
for value in ["ImportBatch", "ImportedMessage", "ImportSourceEvidence", "HomeworkImportInboxSnapshot"]:
    require(f"interface {value}" in models, f"Import V2 model missing: {value}")
for field in ["messageCount", "candidateCount", "sourceProfileId", "createdAtEpochMs", "status"]:
    require(field in models, f"ImportBatch missing field: {field}")

for field in ["batchId?: string", "sourceMessageIds?: string[]", "rawText?: string",
              "imageRef?: string", "capturedAtEpochMs?: number"]:
    require(field in homework_models, f"Candidate SourceEvidence missing trace field: {field}")

require("interface HomeworkImportInboxPersistence" in persistence_port,
        "Import Inbox persistence must stay behind a port")
require("interface HomeworkImportInboxRepository" in repo_port,
        "Import Inbox reads/writes must stay behind a repository port")
require("homework_import_inbox_v2" in persistence and "homework_import_inbox_snapshot_v1" in persistence,
        "Import Inbox must use isolated Preferences storage")
require("HomeworkSnapshot" not in persistence and "HomeworkStore" not in persistence,
        "Import Inbox persistence must not be embedded into the Assignment snapshot")
require("class HomeworkImportInboxStore" in store and "requestPersist" in store,
        "Import Inbox store must persist batch history")
require("listBatches" in store and "getMessages" in store and "getCandidates" in store,
        "Import Inbox store must support independently reading batch contents")
require("markPublished" in store and "ImportBatchStatus.PUBLISHED" in store,
        "published batch history must be retained")
require("abandon" in store and "ImportBatchStatus.ABANDONED" in store,
        "batch abandonment must be explicit")
require("AssignmentRepository" not in store and "AssignmentStateMachine" not in store,
        "Import Inbox store must never own Assignment lifecycle")

require("commitParsedImport" in service and "importBatch(" in service and "activateBatch(" in service,
        "Import Inbox service must support current imports and future multi-message sources")
require("sourceMessageIds" in service and "batchId:" in service,
        "Candidate snapshots must retain message-level provenance")
require("HomeworkImportSourceType.CLIPBOARD" in import_service,
        "text import must write through Import Inbox V2")
require("HomeworkImportSourceType.SCREENSHOT" in import_service,
        "screenshot import must write through Import Inbox V2")
require("commitParsedImport" in import_service,
        "existing text/image import flow must persist ImportBatch data")
require("syncInboxCandidates" in draft_repo,
        "Candidate edits must update the active ImportBatch snapshot")
require("markActiveBatchPublished" in publish and
        publish.index("markActiveBatchPublished") < publish.index("clearCandidates()"),
        "successful atomic publish must preserve and mark batch history before clearing active drafts")
require("PreferencesHomeworkImportInboxPersistence" in entry and "HomeworkImportInboxBootstrap" in entry,
        "EntryAbility must initialize Import Inbox persistence")

require("作业智能收件箱" in inbox_page and "messageCount" in inbox_page and "candidateCount" in inbox_page,
        "parent UI must expose batch history and counts")
require("原始消息" in detail_page and "候选作业" in detail_page and "sourceMessageIds" in detail_page,
        "batch detail must show source messages, candidates and provenance")
require("继续确认并发布" in detail_page and "activate(this.batchId)" in detail_page,
        "READY batch must restore the existing confirmation flow")
require("PARENT_IMPORT_INBOX" in routes and "PARENT_IMPORT_BATCH_DETAIL" in routes,
        "Import Inbox must use explicit navigation routes")
require("HomeworkImportInboxPage" in shell and "HomeworkImportBatchDetailPage" in shell,
        "AppShell must wire inbox and batch detail pages")

require("messageCount: 3" in fixture and "candidateCount: 2" in fixture,
        "#242 deterministic fixture must contain 3 messages and 2 candidates")
require(fixture.count("Issue242ImportInboxFixture.message(") == 3,
        "#242 fixture must create exactly 3 ImportedMessage records")
require(fixture.count("Issue242ImportInboxFixture.candidate(") == 2,
        "#242 fixture must create exactly 2 CandidateAssignment records")
require("HomeworkImportSourceType.CLIPBOARD" in fixture,
        "#242 fixture must validate the CLIPBOARD source type")
require("家长甲" in fixture and "sourceMessageIds" in fixture,
        "#242 fixture must prove non-homework source messages can coexist with candidate evidence")

require("enum AssignmentStatus" not in models,
        "Import V2 must not introduce a second Assignment state machine")
require("class AssignmentStateMachine" in state_machine,
        "existing AssignmentStateMachine must remain authoritative")

if errors:
    print("ISSUE_242_IMPORT_INBOX_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_242_IMPORT_INBOX_GATE_PASS")
