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
link_unique_migration = read("backend/src/main/resources/db/migration/V18__voice_material_task_link_assignment_unique.sql")
assignment_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialAssignmentService.java")
query_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceTaskQueryService.java")
controller = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialController.java")
resource_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentResourceService.java")
delete_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
attempt_service = read("backend/src/main/java/com/xiaoban/homework/scheduledassignment/ScheduledAssignmentAttemptService.java")
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
require("uq_voice_material_task_link_assignment" in link_unique_migration and
        "(family_id, assignment_id)" in link_unique_migration,
        "one Assignment must map to at most one source voice folder")
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
    require("requestId 已用于其他语音任务创建请求" in manual_body and
            "previous.packageId.equals(packageId)" in manual_body and
            "previous.studentId.equals(targetStudentId)" in manual_body,
            "idempotent retries must reject reuse across a different folder or student")
auto_block = assignment_service.split("public VoiceMaterialDtos.AutoCreateResponse autoCreateNext", 1)
require(len(auto_block) == 2 and
        "assignments.findFirstVoiceMaterialTaskForDate(familyId, studentId, businessDate)" in auto_block[1],
        "automatic creation must first reuse an effective voice task due on the current business day")
require("findFirstVoiceMaterialTaskForDate" in delete_service and
        "StatusNotAndTaskDateOrderByUpdatedAtDesc" in read(
            "backend/src/main/java/com/xiaoban/homework/assignment/AssignmentRepository.java"),
        "current-day active voice task lookup must be bounded by structured taskDate")
if len(auto_block) == 2:
    auto_body = auto_block[1].split("private VoiceMaterialPackageEntity chooseAutoFolder", 1)[0]
    require("todayRecord" in auto_body and
            "autoRecords.findByFamilyIdAndStudentIdAndBusinessDate" in auto_body and
            "if (todayRecord != null)" in auto_body,
            "automatic creation must stop after the first automatic creation of the business day")
    require("new VoiceMaterialAutoCreateRecordEntity()" in auto_body and
            "orElseGet(VoiceMaterialAutoCreateRecordEntity::new)" not in auto_body,
            "daily automatic creation record must be one-shot and must not be overwritten")

# Carry over: 昨天没做完的自动任务挪到今天，而不是再建一条新的。
carried_over = auto_block[1] if len(auto_block) == 2 else ""
require("findCarryOver(familyId, studentId, businessDate)" in carried_over and
        "carryOver.assignmentId" in carried_over and
        "carryOver.packageId" in carried_over,
        "automatic creation must carry over the unfinished auto task instead of creating another")
require("carryOverToBusinessDate(" in carried_over and
        "recordAutoCreate(familyId, studentId, businessDate, carryOver.packageId" in carried_over,
        "carry over must move the task date and consume the current business day quota")
if len(auto_block) == 2:
    auto_body = auto_block[1].split("private VoiceMaterialPackageEntity chooseAutoFolder", 1)[0]
    require(0 <= auto_body.find("findCarryOver(familyId, studentId, businessDate)")
            < auto_body.find("if (todayRecord != null)"),
            "carry over must run before the daily record check, otherwise the record written by "
            "the task's own creation would pin that task to the previous day forever")
    require('if (!"AUTO".equals(link.createMode)) continue;' in auto_body,
            "only automatically created tasks may be carried over; manual and legacy task dates "
            "must never be moved by the system")
    require("isSettled(item.status)" in auto_body, "settled tasks must not be carried over")

carry_over_split = delete_service.split(
    "public AssignmentDtos.Response carryOverToBusinessDate(", 1)
require(len(carry_over_split) == 2 and
        "e.taskDate = businessDate" in carry_over_split[1] and
        "nextVoiceMaterialTaskTitle(" in carry_over_split[1],
        "carry over must move taskDate and refresh the dated voice title")
if len(carry_over_split) == 2:
    carry_over_body = carry_over_split[1].split("\n  public ", 1)[0]
    require("e.status" not in carry_over_body and "e.startedAtEpochMs" not in carry_over_body and
            "e.elapsedSeconds" not in carry_over_body,
            "carry over must not reset status or in-progress timing")
    require("businessDate, materialTitle, e.id)" in carry_over_body,
            "carry over must exclude the task itself from the same-day title counter, "
            "otherwise a renamed task is needlessly suffixed with a sequence number")
require("AndCreatedAtLessThanAndIdNot(" in read(
            "backend/src/main/java/com/xiaoban/homework/assignment/AssignmentRepository.java"),
        "the same-day title counter needs an id-excluding variant for carry over")

settled_split = assignment_service.split(
    "private static boolean isSettled(String status)", 1)
require(len(settled_split) == 2, "settled status helper must exist")
if len(settled_split) == 2:
    settled_body = settled_split[1].split("}", 1)[0]
    for settled in ("READY_TO_SUBMIT", "SUBMITTED", "COMPLETED"):
        require(f'"{settled}".equals(status)' in settled_body,
                f"child-submitted state {settled} must count as done and not be carried over")
    require("NOT_STARTED" not in settled_body and "PAUSED" not in settled_body and
            "NEEDS_REWORK" not in settled_body and "OVERDUE" not in settled_body,
            "unfinished states must stay carry-over eligible")

require('"CARRIED_OVER".equals(run.skipReason)' in attempt_service,
        "a carried over run must be recorded as a final skip so the scheduler stops retrying it")
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

# Task query must start from Assignment so local-upload voice tasks are not lost.
require("from assignment a" in query_service and
        "a.content_type = 'AUDIO_IMAGE'" in query_service and
        "left join voice_material_task_link l" in query_service,
        "voice task query must include AUDIO_IMAGE Assignments with or without source folders")
require("from assignment_resource" in query_service and
        '"本地上传"' in query_service,
        "voice task detail must expose local-upload resources and source label")

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
require("subjectCode?: string" in remote and "title?: string" in remote and
        "instruction?: string" in remote and "requestId?: string" in remote,
        "manual folder creation request must support selected subject, generated copy and idempotency")

require("VOICE_SOURCE_LOCAL" in voice_page and "VOICE_SOURCE_SERVER" in voice_page and
        "Button('从本机选择'" in voice_page and "Button('使用服务器素材'" in voice_page,
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
require("private generatedTitle(): string" in voice_page and
        "return `绘本-${folder.directoryName}`;" in voice_page and
        "this.title = this.generatedTitle();" in voice_page and
        "this.title = item.directoryName" not in voice_page,
        "folder reuse must use the current generated 绘本-目录 naming contract, never raw folder name")
require("Select([" in voice_page and "subjectFromIndex" in voice_page and
        "syncGeneratedTaskCopy()" in voice_page,
        "voice assignment subject must use a single selector and regenerate task copy")
require("titleCustomized" not in voice_page and "instructionCustomized" not in voice_page and
        "TextInput({ placeholder: '选择素材后自动生成" not in voice_page,
        "generated voice task name/instruction must not require manual editing")
require("Text('任务设置')" in voice_page and "Text('任务日期')" in voice_page and
        "Text('预计完成时长')" in voice_page,
        "voice assignment task metadata must use compact user-facing labels")
require("private MaterialSection()" in voice_page and
        voice_page.find("this.SourceSelector();") > voice_page.find("Text('作业素材')"),
        "material source selector must live inside the assignment material card")
require(voice_page.find("this.TaskSettingsSection()") <
        voice_page.find("this.MaterialSection()"),
        "task settings must appear before the assignment material card")
require("private PublishFooter()" in voice_page and
        voice_page.find("this.PublishFooter();") > voice_page.find(".scrollBar(BarState.Off);"),
        "publish action must remain fixed outside the scrolling content")
require("subjectCode: this.subjectCode(draft.subject)" in voice_vm and
        "input.subjectCode()" in assignment_service and
        "normalizeSubjectCode" in assignment_service,
        "server-folder task creation must preserve the subject selected in task settings")
require("subject: this.subject" in voice_page and
        "subject: this.sourceMode === VOICE_SOURCE_SERVER" not in voice_page and
        "this.viewModel.subjectFromCode(this.selectedFolder()!.subjectCode)" not in voice_page,
        "server-folder publishing must not overwrite the parent-selected subject with folder metadata")
require("instruction: draft.instruction.trim()" in voice_vm and
        "input.instruction()" in assignment_service and
        "requestedInstruction" in assignment_service,
        "server-folder task creation must persist the generated task instruction")

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
    # 顺延：把没做完的自动任务挪到今天，而不是再建一条。
    "auto create must carry the unfinished task over",
    "carry over must keep the same Assignment instance",
    "carried task must be dated today",
    "carry over must not create a second voice task",
    "carry over must regenerate the task name from the new business date",
    "carry over must not suffix the renamed task with a sequence number",
    "a carried over task must already consume the current business day quota",
    # 孩子已经交出去的（待提交/已提交）不再顺延。
    "a task the child already handed in must not be carried over",
    "a submitted task must stay on its own date and keep its status",
]:
    require(token in voice_e2e, f"voice material E2E missing lifecycle assertion: {token}")

if errors:
    print("ISSUE_298_VOICE_MATERIAL_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_298_VOICE_MATERIAL_GATE_PASS")
