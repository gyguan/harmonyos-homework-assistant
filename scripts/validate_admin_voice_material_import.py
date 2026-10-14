#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

def read(path: str) -> str:
    p = ROOT / path
    if not p.exists():
        errors.append(f"missing required file: {path}")
        return ""
    return p.read_text(encoding="utf-8")

def require(ok: bool, msg: str) -> None:
    if not ok:
        errors.append(msg)

controller = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialController.java")
query_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceTaskQueryService.java")
assignment_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialAssignmentService.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialDtos.java")
migration = read("backend/src/main/resources/db/migration/V17__voice_material_task_links.sql")
index = read("backend/src/main/resources/static/admin/index.html")
css = read("backend/src/main/resources/static/admin/css/admin.css")
api = read("backend/src/main/resources/static/admin/js/api.js")
app = read("backend/src/main/resources/static/admin/js/app.js")
view = read("backend/src/main/resources/static/admin/js/voice-management-view.js")
voice = read("backend/src/main/resources/static/admin/js/voice-material.js")
admin_controller = read("backend/src/main/java/com/xiaoban/homework/admin/AdminPageController.java")

require('@GetMapping({"/admin", "/admin/"})' in admin_controller and
        'forward:/admin/index.html' in admin_controller,
        "admin root must deterministically forward to the static admin shell")
require('id="nav-voice-tasks"' in index and '<span>语音任务</span>' in index,
        "admin shell must expose the voice-task navigation entry")
require('voice-task-stats' not in index,
        "voice management must not regress to statistic cards")

# Tasks and folders must be separate Web views.
for element_id in [
    "tab-tasks", "tab-folders", "task-view", "folder-view",
    "task-search-form", "task-table-body", "task-pagination",
    "folder-search-form", "folder-table-body", "folder-pagination"
]:
    require(f'id="{element_id}"' in index, f"missing split voice management view: {element_id}")
require("switchTab('tasks')" in app and "switchTab('folders')" in app,
        "task and folder views must be independently navigable")

# Server-side paged task query is Assignment-based.
require('"/voice-tasks"' in controller and '"/voice-tasks/{assignmentId}"' in controller,
        "canonical voice task list/detail endpoints must exist")
require("from assignment a" in query_service and
        "a.content_type = 'AUDIO_IMAGE'" in query_service and
        "left join voice_material_task_link l" in query_service and
        "limit :limit offset :offset" in query_service,
        "voice task query must start from Assignment and remain server paged")
require("fetchAssignmentResource" in api and "APP 本地上传" in view,
        "Web task detail must preview local-upload assignment resources without a folder link")
require("renderTaskRows" in view and "renderFolderRows" in view and
        "renderTaskDetailContent" in view and "renderFolderDetailContent" in view and
        "voice-management-view.js" in app,
        "voice task/folder presentation must stay isolated from app orchestration")
require("/api/v1/voice-tasks" in api and "searchVoiceTasks" in app,
        "Web task list must use canonical paged task API")
require('value="READY"' not in index[index.find('id="task-status"'):index.find('id="task-subject"')],
        "folder lifecycle states must not leak into task status filter")

# Folder list is independent, paged, and exposes reuse metrics.
require('@GetMapping("/voice-material-folders")' in controller and
        '@GetMapping("/voice-material-folders/{packageId}")' in controller,
        "voice folder list/detail endpoints must exist")
require("VoiceFolderPageResponse" in dtos and "usageCount" in dtos and
        "activeTaskCount" in dtos and "lastUsedAtEpochMs" in dtos,
        "folder query contract must expose reuse information")
require("/api/v1/voice-material-folders" in api and
        "searchVoiceFolders" in app and "getVoiceFolderDetail" in app,
        "Web folder list/detail must use paged folder APIs")
require("使用次数" in index and "最近使用" in index,
        "folder result list must visibly expose reuse history")

# Folder -> N tasks relation and request idempotency.
require("create table voice_material_task_link" in migration and
        "assignment_id varchar(120) not null" in migration and
        "package_id uuid not null" in migration,
        "database must persist independent folder-task history")
require("update voice_material_package" in migration and
        "status = 'READY'" in migration and "status = 'CONSUMED'" in migration,
        "legacy consumed folders must be migrated back to reusable READY")
require('"a-voice-" + UUID.randomUUID()' in assignment_service and
        'link.packageId = item.id' in assignment_service and
        'links.saveAndFlush(link)' in assignment_service,
        "task creation must create a new Assignment and independent folder link")
require('item.status = "CONSUMED"' not in assignment_service,
        "new task creation must not consume a reusable folder")
require("requestId" in dtos and "findByFamilyIdAndRequestId" in assignment_service,
        "manual task creation must have request-level idempotency")
require('id="open-create-task"' in index and 'id="create-drawer"' in index and
        "prepareCreateSettings" in app and "submitCreate" in app,
        "Web must provide explicit create-task workflow over reusable folders")

# Folder import remains separate with per-directory result list.
for element_id in [
    "open-import", "import-drawer", "folder-input", "folder-picker",
    "import-table-body", "start-import", "import-result-stage", "import-result-body"
]:
    require(f'id="{element_id}"' in index, f"missing folder import UI: {element_id}")
require('id="folder-input" type="file" webkitdirectory directory multiple' in index and
        'id="add-folder-picker"' in index and "共同上级目录" in index and
        "Ctrl/Shift" not in index and "ondrop" in app and "collectDirectory" in app,
        "folder import must provide browser-safe parent-folder, repeated-add and drag/drop paths")
require("openFolderInput" in app and "继续添加文件夹" in app and
        "state.importPackages.map" in app and "mergeFiles" in app,
        "repeated directory picks must accumulate in the same pending import list")

# Browsers only allow one directory per pick, so one pick must expand into a directory tree the
# user can multi-select: every level is a candidate row, default selection keeps only the
# deepest directories that already form a valid package.
for element_id in ["import-only-selected", "reset-import-selection", "import-list-hint"]:
    require(f'id="{element_id}"' in index, f"missing multi-folder selection control: {element_id}")
require("analyzeVoiceMaterialSelection" in voice and "defaultSelectionPaths" in voice and
        "parts.slice(0, depth).join('/')" in voice and "parts.slice(depth).join('/')" in voice and
        "unassignedSupportedCount" in voice,
        "voice parser must enumerate every directory level and keep nested relative names")
require("analyzeVoiceMaterialSelection" in app and "buildVoiceMaterialRows" in app and
        "importChoices" in app and "rememberImportChoice" in app and
        "renderImportRows" in app and
        "import-select" in view and "toggle-import" in view and "importRowStatus" in view,
        "each identified directory must be independently selectable so several folders import in one pass")
require("parseVoiceMaterialPackages" not in voice and
        "audioCount === 0" in voice and "audioCount > 1" in voice and
        "imageCount === 0" in voice,
        "folder import must validate exactly 1 audio + at least 1 image per selected directory")
require("renderImportResults" in app and "可用于创建语音任务" in app,
        "import must finish with a per-folder reusable result list")
require("AdminVoiceMaterialService" not in controller + app + view + api,
        "admin refactor must not duplicate the voice material domain service")
require("#1456b8" in css and "#fff" in css and ".data-table" in css and ".drawer-panel" in css,
        "admin must keep the white/deep-blue Web management visual baseline")

# ---------- 批量删除语音素材 / 语音任务 ----------
# 删除是不可逆操作，闸门要盯住三件事：只接受显式 id 列表、素材与任务的引用关系不被误删、
# 以及"已完成"任务的二次确认不能被绕过。
material_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialService.java")
auto_record_repo = read(
    "backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialAutoCreateRecordRepository.java")
assignment_core = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
e2e = read("backend/scripts/voice_material_e2e.py")

require('@PostMapping("/voice-material-packages/batch-delete")' in controller and
        '@PostMapping("/voice-tasks/batch-delete")' in controller,
        "batch delete endpoints must exist for both voice folders and voice tasks")
require("record BatchDeleteRequest(" in dtos and "record BatchDeleteItem(" in dtos and
        "record BatchDeleteResponse(" in dtos and "min = 1, max = 500" in dtos,
        "batch delete must take an explicit bounded id list and report per-item results")
require("batchDeletePackages" in material_service and "batchDeleteTasks" in assignment_service,
        "batch delete must be implemented in the voice material services")
# 调用方必须显式给出 id，服务端不接受按条件全删，避免筛选条件写错时清空整个家庭的素材。
require("selectAllMatching" in app and "selectionListHtml" in app,
        "Web must resolve select-all into explicit ids and show them before deleting")

# voice_material_auto_create_record.package_id 没有 on delete cascade：
# 不先删记录就删目录会整批撞外键。顺序必须保留。
require("deleteByFamilyIdAndPackageIdIn" in material_service and
        "autoRecords.deleteByFamilyIdAndPackageIdIn" in material_service and
        "autoRecords.flush()" in material_service and
        "deleteByFamilyIdAndPackageIdIn" in auto_record_repo,
        "folder batch delete must purge auto-create records before deleting the folder")
require("deleteByFamilyIdAndAssignmentId" not in assignment_service + auto_record_repo,
        "batch task delete must keep folder-task history and the daily auto-create limit")

# 删任务允许"已完成"，单条删除保持原有拒绝语义。
require("deleteAllowingCompleted" in assignment_core and
        "deleteInternal(familyId, id, false)" in assignment_core and
        "deleteInternal(familyId, id, true)" in assignment_core and
        '"已完成作业不能删除"' in assignment_core,
        "batch task delete must allow completed tasks while single delete keeps rejecting them")
require("completed" in app and "requirePhrase" in app and "CONFIRM_WORD" in app and
        "syncConfirmOk" in app,
        "Web must require a typed confirmation before deleting completed voice tasks")
require("由这些素材生成的语音任务<strong>会保留</strong>" in app,
        "folder delete copy must state that generated voice tasks are kept")

require("data-select-task" in view and "data-select-folder" in view and
        "selectedIds" in view and "selected-row" in view,
        "voice list rows must expose an independently selectable checkbox")
for element_id in [
    "task-select-all", "folder-select-all", "task-select-all-matching", "folder-select-all-matching",
    "task-bulk-bar", "folder-bulk-bar", "task-batch-delete", "folder-batch-delete",
    "task-clear-selection", "folder-clear-selection",
    "confirm-dialog", "confirm-body", "confirm-phrase-field", "confirm-phrase-input",
    "confirm-cancel", "confirm-ok"
]:
    require(f'id="{element_id}"' in index, f"missing batch delete UI: {element_id}")
require("batchDeleteVoiceTasks" in api and "batchDeleteVoiceMaterialPackages" in api and
        "batchDeleteVoiceTasks" in app and "batchDeleteVoiceMaterialPackages" in app,
        "Web must use the canonical batch delete APIs")
require("confirmDeleteTasks" in app and "confirmDeleteFolders" in app and
        "submitBatchDelete" in app,
        "Web must route bulk deletion through explicit confirm flows")
require(".bulk-bar" in css and ".danger-button" in css and ".confirm-panel" in css and
        ".row-select" in css,
        "batch delete UI must be styled with the shared admin baseline")
# 真实数据库回归：外键级联、已完成可删、重建后不判重，只有 E2E 能覆盖。
require("/api/v1/voice-material-packages/batch-delete" in e2e and
        "/api/v1/voice-tasks/batch-delete" in e2e and
        "must survive deletion of its source folder" in e2e and
        "must not be rejected as duplicate" in e2e,
        "voice material E2E must cover batch delete semantics against a real database")

if errors:
    print("ADMIN_VOICE_IMPORT_GATE_FAIL")
    for e in errors:
        print(f"- {e}")
    sys.exit(1)

print("ADMIN_VOICE_IMPORT_GATE_PASS")
