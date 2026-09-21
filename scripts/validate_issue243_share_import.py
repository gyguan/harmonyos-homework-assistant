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


module = read("entry/src/main/module.json5")
extension = read("entry/src/main/ets/share/HomeworkShareExtensionAbility.ets")
receiver = read("entry/src/main/ets/application/import/HomeworkShareReceiveService.ets")
processor = read("entry/src/main/ets/application/import/HomeworkShareImportService.ets")
handoff = read("entry/src/main/ets/infrastructure/persistence/PreferencesHomeworkShareHandoffPersistence.ets")
models = read("entry/src/main/ets/domain/model/HomeworkShareModels.ets")
entry = read("entry/src/main/ets/entryability/EntryAbility.ets")
index = read("entry/src/main/ets/pages/Index.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
parent_import_navigator = read("entry/src/main/ets/app/navigation/ParentImportNavigator.ets")
status = read("entry/src/main/ets/features/parent/import/HomeworkShareImportStatusPage.ets")
receiving_page = read("entry/src/main/ets/pages/HomeworkShareReceivingPage.ets")
pages = read("entry/src/main/resources/base/profile/main_pages.json")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
inbox_service = read("entry/src/main/ets/application/import/HomeworkImportInboxService.ets")

require('"type": "share"' in module, "ShareExtensionAbility must be registered with type=share")
require('"exported": true' in module, "share target must be exported")
require('"ohos.want.action.sendData"' in module, "share target must register sendData action")
require('"utd": "general.text"' in module, "share target must accept general.text")
require('"utd": "general.image"' in module, "share target must accept general.image")
require('"maxFileSupported": 9' in module, "share target must support multiple image records")
require("HomeworkShareExtensionAbility.ets" in module, "share extension srcEntry missing")

require("extends ShareExtensionAbility" in extension, "share receiver must extend ShareExtensionAbility")
require("systemShare.getSharedData(want)" in extension, "share receiver must use Share Kit getSharedData")
require("data.getRecords()" in extension, "share receiver must consume SharedRecord list")
require("shareImportToken" in extension and "EntryAbility" in extension,
        "share extension must hand off a token to the main EntryAbility")
require("this.context.startAbility" in extension,
        "share extension must open the main app after durable handoff")
require("session.loadContent('pages/HomeworkShareReceivingPage')" in extension,
        "share extension must load a lightweight sharing details page")
require("session.terminateSelf()" in extension,
        "share extension must release its transient UI session")
require("HomeworkShareReceivingPage" in pages and "正在接收分享内容" in receiving_page,
        "sharing details receiving page must be registered and visible")

require("context.filesDir" in receiver, "shared images must be copied into app sandbox")
require("fileIo.openSync(sourceUri" in receiver, "receiver must read the temporary external URI")
require("OpenMode.TRUNC" in receiver, "sandbox copy must truncate reused destination files")
require("fileIo.readSync" in receiver and "fileIo.writeSync" in receiver,
        "receiver must copy shared image bytes before ShareExtension is destroyed")
require("sandboxUri: sandboxUri" in receiver,
        "handoff must persist sandbox URI rather than the external temporary URI")
require("PreferencesHomeworkShareHandoffPersistence" in receiver,
        "share extension must persist a cross-ability handoff")
require("cleanupRecords" in receiver and "unlinkSync" in receiver,
        "failed receive must clean copied sandbox files")

require("pending_share_imports_v1" in handoff and "homework_share_handoff_v1" in handoff,
        "share handoff must use isolated persistence")
require("MAX_AGE_MS" in handoff, "stale share handoffs must have an expiry boundary")
require("interface PendingHomeworkShareImport" in models and
        "interface PendingHomeworkShareRecord" in models,
        "share handoff domain model missing")

require("parseImportedSource" in import_service,
        "#243 must reuse the existing OCR/AI/local import pipeline")
require("HomeworkImportSourceType.SHARE" in processor,
        "processed share must create sourceType=SHARE evidence")
require("HomeworkImportSourceKind.SHARE" in processor,
        "shared text/image must use the existing RawHomeworkImport source kind")
require("parseImportedSource(rawImport)" in processor,
        "share processor must use the shared import parser pipeline")
require("HomeworkImportInboxService.instance.importBatch" in processor,
        "share result must enter #242 Import Inbox V2")
require("HomeworkImportInboxService.instance.activateBatch" in processor,
        "share candidates must continue through existing confirmation flow")
require("ImportBatchStatus.READY" in processor and "ImportBatchStatus.EMPTY" in processor,
        "share processing must represent both ready and empty outcomes")
require("persistence.remove(token)" in processor,
        "successful share handoff must be consumed")
require("async cancel(token" in processor and "cleanupPendingFiles" in processor,
        "failed/cancelled handoff must be explicitly cleanable")
require(processor.index("HomeworkImportInboxService.instance.importBatch") >
        processor.index("for (let i = 0; i < pending.records.length; i++)"),
        "ImportBatch must only be persisted after all records finish extraction/parsing")

require("onCreate(want: Want" in entry and "onNewWant(want: Want" in entry,
        "cold and warm app launches must both capture share handoff tokens")
require("shareImportToken" in entry and "shareImportForceParent" in entry,
        "EntryAbility must publish the handoff into UI state")
require("HomeworkShareImportService.instance.configure(this.context)" in entry,
        "main share processor must receive app context")
require("@StorageLink('shareImportForceParent')" in index,
        "system share must enter a parent-owned workflow")
require("@StorageLink('shareImportToken')" in shell,
        "AppShell must react to share handoff token changes")
require("HomeworkShareImportStatusPage" in shell,
        "share handoff must have an explicit processing surface")
require("ParentImportNavigator.openConfirmation(this.navPathStack)" in shell and
        "AppRoute.PARENT_IMPORT_CONFIRMATION" in parent_import_navigator,
        "successful share import must reuse HomeworkConfirmationPage route")
require("ParentImportNavigator.openInbox(this.navPathStack)" in shell and
        "AppRoute.PARENT_IMPORT_INBOX" in parent_import_navigator,
        "empty share import must remain inspectable in Import Inbox")

require("无法读取或识别分享图片，请重试" in status,
        "OCR failure must have an explicit retry message")
require("Button('重试'" in status and "this.retry()" in status,
        "failed share import must be retryable")
require("HomeworkShareImportService.instance.cancel" in status,
        "share handoff cancellation must clean pending data")
require("半成品作业" in status,
        "UI must make the all-or-nothing behavior explicit")

for source in [extension, receiver, processor]:
    require("AssignmentStateMachine" not in source and "AssignmentRepository" not in source,
            "#243 must not introduce a second Assignment lifecycle")

if errors:
    print("ISSUE_243_SHARE_IMPORT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_243_SHARE_IMPORT_GATE_PASS")
