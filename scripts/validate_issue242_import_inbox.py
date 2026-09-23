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
legacy_store = read("entry/src/main/ets/data/HomeworkStore.ets")
repo = read("entry/src/main/ets/data/repository/DefaultHomeworkImportInboxRepository.ets")
draft_repo = read("entry/src/main/ets/data/repository/DefaultHomeworkImportDraftRepository.ets")
service = read("entry/src/main/ets/application/import/HomeworkImportInboxService.ets")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
publish = read("entry/src/main/ets/application/import/HomeworkBatchPublishService.ets")
entry = read("entry/src/main/ets/entryability/EntryAbility.ets")
inbox_page = read("entry/src/main/ets/features/parent/import/HomeworkImportInboxPage.ets")
inbox_vm = read("entry/src/main/ets/features/parent/import/HomeworkImportInboxViewModel.ets")
inbox_filters = read("entry/src/main/ets/features/parent/import/HomeworkImportInboxFilters.ets")
inbox_filter_dialog = read("entry/src/main/ets/features/parent/import/HomeworkImportInboxFilterDialog.ets")
detail_page = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")
dashboard = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
import_home = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
fixture = read("entry/src/test/fixtures/Issue242ImportInboxFixture.ets")
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
for field in ["batchId: source.sourceEvidence.batchId",
              "sourceMessageIds: source.sourceEvidence.sourceMessageIds",
              "rawText: source.sourceEvidence.rawText",
              "imageRef: source.sourceEvidence.imageRef"]:
    require(field in legacy_store,
            f"legacy HomeworkStore clone must preserve Import V2 provenance: {field}")
require("markActiveBatchPublished" in publish and
        publish.index("markActiveBatchPublished") < publish.index("clearCandidates()"),
        "successful atomic publish must preserve and mark batch history before clearing active drafts")
require("PreferencesHomeworkImportInboxPersistence" in entry and "HomeworkImportInboxBootstrap" in entry,
        "EntryAbility must initialize Import Inbox persistence")

require("title: '作业收件箱'" in inbox_page and "messageCount" in inbox_page and "candidateCount" in inbox_page,
        "parent UI must expose the shared homework inbox and batch counts")
for token in [
    "HomeworkImportInboxSourceFilter",
    "HomeworkImportInboxStatusFilter",
    "HomeworkImportInboxTimeFilter",
]:
    require(token in inbox_filters, f"Import Inbox filter model missing: {token}")
require("filterBatches(" in inbox_vm and "matchesSource(" in inbox_vm and
        "matchesStatus(" in inbox_vm and "earliestEpochMs(" in inbox_vm,
        "Import Inbox ViewModel must own source/status/time filtering")
require("FilterSummaryEntry" in inbox_page and "label: '来源'" in inbox_page and
        "label: '状态'" in inbox_page and "label: '时间'" in inbox_page,
        "Import Inbox page must expose the standard filter summary bar")
for token in ["Text('来源')", "Text('状态')", "Text('时间')", "Button('重置'", "Button('确定'"]:
    require(token in inbox_filter_dialog, f"Import Inbox filter dialog missing: {token}")
require("作业收件箱" in dashboard and "onOpenInbox" in dashboard,
        "parent dashboard must expose Import Inbox as an independent entry")
require("onOpenInbox: () => ParentImportNavigator.openInbox" in shell,
        "parent dashboard inbox entry must use ParentImportNavigator")
require("作业收件箱" not in import_home and "onOpenInbox" not in import_home,
        "manual import page must not own the shared Import Inbox entry")
require("原始消息" in detail_page and "候选作业" in detail_page and "sourceMessageIds" in detail_page,
        "batch detail must show source messages, candidates and provenance")
require("继续确认并发布" in detail_page and "activate(this.batchId)" in detail_page,
        "READY batch must restore the existing confirmation flow")
require("PARENT_IMPORT_INBOX" in routes and "PARENT_IMPORT_BATCH_DETAIL" in routes,
        "Import Inbox must use explicit navigation routes")
require("HomeworkImportInboxPage" in shell and "HomeworkImportBatchDetailPage" in shell,
        "AppShell must import inbox and batch detail pages")
require("name === AppRoute.PARENT_IMPORT_INBOX" in shell and
        "HomeworkImportInboxPage({" in shell and
        "onOpenBatch: (batchId: string) => ParentImportNavigator.openBatch(" in shell,
        "AppShell must register the inbox NavDestination and wire batch navigation")
require("name === AppRoute.PARENT_IMPORT_BATCH_DETAIL" in shell and
        "HomeworkImportBatchDetailPage({" in shell and
        "batchId: ParentImportNavigator.batchId(param)" in shell,
        "AppShell must register the batch detail NavDestination with its route parameter")
require("onOpenConfirmation: () => ParentImportNavigator.openConfirmation(this.navPathStack)" in shell,
        "batch detail must preserve navigation into the existing confirmation flow")

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
require("['m-1', 'm-3']" in fixture,
        "#242 fixture must prove one Candidate can reference multiple source messages")

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
