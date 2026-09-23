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


asset_migration = read("backend/src/main/resources/db/migration/V15__voice_material_assets.sql")
link_migration = read("backend/src/main/resources/db/migration/V17__voice_material_task_links.sql")
assignment_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialAssignmentService.java")
query_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceTaskQueryService.java")
controller = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialController.java")
resource_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentResourceService.java")
delete_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
remote = read("entry/src/main/ets/application/remote/RemoteVoiceMaterialApi.ets")
auto = read("entry/src/main/ets/application/assignment/VoiceMaterialAutoCreateService.ets")
index = read("entry/src/main/ets/pages/Index.ets")
voice_page = read("entry/src/main/ets/features/parent/voice/ParentVoiceAssignmentPage.ets")
voice_vm = read("entry/src/main/ets/features/parent/voice/ParentVoiceAssignmentViewModel.ets")
dashboard = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
voice_e2e = read("backend/scripts/voice_material_e2e.py")

# Physical media remains reusable and AssignmentResource links shared assets.
require("create table media_asset" in asset_migration and
        "asset_id uuid references media_asset(id)" in asset_migration,
        "#298 must store reusable physical media in MediaAsset")
require("entity.assetId = asset.id" in resource_service and "entity.storagePath = null" in resource_service,
        "#298 new Assignment resources must reference shared MediaAsset")

# Folder and task instance are now separate durable concepts.
require("create table voice_material_task_link" in link_migration and
        "package_id uuid not null references voice_material_package" in link_migration and
        "assignment_id varchar(120) not null" in link_migration,
        "reusable voice folders must keep durable folder-to-task links")
require("uq_voice_material_task_link_request" in link_migration,
        "manual folder assignment creation must support request idempotency")
require("update voice_material_package" in link_migration and "status = 'READY'" in link_migration,
        "legacy consumed folders must migrate back to reusable READY state")
require("uq_voice_material_auto_daily" in asset_migration and
        "unique (family_id, student_id, business_date)" in asset_migration,
        "database must enforce at most one automatic voice creation record per student per business day")

# Manual creation and automatic creation have different concurrency rules.
require("VoiceMaterialTaskLinkRepository links" in assignment_service and
        "links.findByFamilyIdAndRequestId" in assignment_service,
        "manual folder creation must resolve idempotent retries through task links")
manual_block = assignment_service.split(
    "public VoiceMaterialDtos.CreateAssignmentResponse createManually(\n      UUID familyId, UUID packageId, VoiceMaterialDtos.CreateAssignmentRequest input)", 1)
require(len(manual_block) == 2, "manual voice creation method must exist")
if len(manual_block) == 2:
    manual_body = manual_block[1].split(
        "public VoiceMaterialDtos.AutoCreateResponse autoCreateNext", 1)[0]
    require("findFirstVoiceMaterialTask" not in manual_body and "当前已有语音任务" not in manual_body,
            "manual creation must allow multiple active voice tasks")
auto_block = assignment_service.split("public VoiceMaterialDtos.AutoCreateResponse autoCreateNext", 1)
require(len(auto_block) == 2 and
        "assignments.findFirstVoiceMaterialTask(familyId, studentId)" in auto_block[1],
        "automatic creation must stop when an effective voice task already exists")
if len(auto_block) == 2:
    auto_body = auto_block[1].split("private VoiceMaterialPackageEntity chooseAutoFolder", 1)[0]
    require("todayRecord" in auto_body and
            "autoRecords.findByFamilyIdAndStudentIdAndBusinessDate" in auto_body and
            "if (todayRecord != null)" in auto_body,
            "automatic creation must stop after the first automatic creation of the business day")
    require("new VoiceMaterialAutoCreateRecordEntity()" in auto_body and
            "orElseGet(VoiceMaterialAutoCreateRecordEntity::new)" not in auto_body,
            "daily automatic creation record must be one-shot and must not be overwritten")
require('String assignmentId = "a-voice-" + UUID.randomUUID()' in assignment_service,
        "folder reuse must create a distinct Assignment instance")
require("link.packageId = item.id" in assignment_service and
        "link.assignmentId = assignment.id()" in assignment_service and
        'link.createMode = createMode' in assignment_service,
        "each created voice task must retain its source folder and creation mode")
require("chooseAutoFolder" in assignment_service and "usageCount" in assignment_service and
        "lastUsedAt" in assignment_service,
        "automatic creation must rotate reusable folders by usage history")
require('if ("CONSUMED".equals(item.status))' in assignment_service and
        'item.status = "READY"' in assignment_service,
        "legacy CONSUMED folders must remain reusable")

# Query contract must expose reusable-folder state directly.
for token in ["USAGE_FILTERS", "usage_count", "active_task_count", "last_used_at",
              "VoiceFolderTaskHistoryItem", "recentTasks"]:
    require(token in query_service or token in read(
        "backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialDtos.java"),
        f"voice folder query contract missing reusable-folder state: {token}")
require('"/voice-material-folders"' in controller and
        '"/voice-material-folders/{packageId}"' in controller,
        "backend must expose paged folder query and folder detail endpoints")

# App voice creation uses one page with two material sources; no standalone material-library route.
require("RemoteVoiceFolderItem" in remote and "RemoteVoiceFolderPage" in remote and
        "async queryFolders(" in remote and "/api/v1/voice-material-folders" in remote,
        "APP must query the reusable server-folder API")
require("'status=READY'" in remote and "usage=" in remote and "page=" in remote,
        "APP folder query must request reusable READY folders with server-side filters/paging")
require("title?: string" in remote and "requestId?: string" in remote,
        "manual folder creation request must support editable title and idempotency")

require("VOICE_SOURCE_LOCAL" in voice_page and "VOICE_SOURCE_SERVER" in voice_page and
        "Button('本地文件'" in voice_page and "Button('服务器文件夹'" in voice_page,
        "voice assignment page must unify local and server material sources")
require("folderUsageText" in voice_page and "已使用" in voice_page and "未使用" in voice_page,
        "server folder picker must expose historical usage without treating used folders as unavailable")
require("activeVoiceAssignment()" not in voice_vm and "activeVoiceAssignment()" not in voice_page and
        "当前已有语音作业，请先完成或处理现有任务" not in voice_page,
        "parent manual voice creation UI must not block multiple active tasks")
require("createRequestId" in voice_page and "createFromFolder" in voice_vm,
        "server-folder creation must use an idempotent request id")
require("queryFolders(" in voice_vm,
        "voice assignment ViewModel must use the reusable-folder query boundary")

require("Text('语音素材库')" not in dashboard and "onOpenVoiceMaterial" not in dashboard,
        "Parent Home must not expose the implementation concept 'voice material library'")
require("Text('语音作业')" in dashboard and "onOpenVoice" in dashboard,
        "Parent Home must expose the user task 'voice assignment'")
require("PARENT_VOICE_MATERIAL" not in routes and "PARENT_VOICE_MATERIAL" not in shell,
        "standalone voice-material APP route must not reappear")
require("PARENT_VOICE_CREATE" in routes and "ParentVoiceAssignmentPage" in shell,
        "voice assignment creation must use one explicit deep route")

# Automatic creation and server lifecycle remain intact.
require("checkToday(studentId" in auto and "autoCreateNext(studentId)" in auto,
        "student client must keep the server-authoritative automatic creation check")
require("VoiceMaterialAutoCreateService.instance.checkToday(studentId)" in index,
        "student entry must trigger the daily voice check")
require("if (resource.assetId == null && resource.storagePath != null" in delete_service,
        "deleting Assignment must not delete shared MediaAsset files")

# Real E2E protects manual multi-create, automatic guard, reuse and idempotent retry.
for token in [
    "valid batch must have two reusable READY folders",
    "manual create while auto task active",
    "auto skip while active voice tasks exist",
    "auto skip while manual task remains active",
    "enforce daily auto-create limit after all tasks cleared",
    "create parallel manual task from same folder",
    "manual create idempotent retry",
]:
    require(token in voice_e2e, f"voice material E2E missing lifecycle assertion: {token}")

if errors:
    print("ISSUE_298_VOICE_MATERIAL_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_298_VOICE_MATERIAL_GATE_PASS")
