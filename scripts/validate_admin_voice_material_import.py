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
require("fetchAssignmentResource" in api and "APP 本地上传" in app,
        "Web task detail must preview local-upload assignment resources without a folder link")
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
require("webkitdirectory" in index and "ondrop" in app and "collectDirectory" in app,
        "folder import must support directory selection and drag/drop")
require("parseVoiceMaterialPackages" in app and
        "audioCount === 0" in voice and "audioCount > 1" in voice and
        "imageCount === 0" in voice,
        "folder import must validate 1 audio + at least 1 image")
require("renderImportResults" in app and "可用于创建语音任务" in app,
        "import must finish with a per-folder reusable result list")
require("AdminVoiceMaterialService" not in controller + app + api,
        "admin refactor must not duplicate the voice material domain service")
require("#1456b8" in css and "#fff" in css and ".data-table" in css and ".drawer-panel" in css,
        "admin must keep the white/deep-blue Web management visual baseline")

if errors:
    print("ADMIN_VOICE_IMPORT_GATE_FAIL")
    for e in errors:
        print(f"- {e}")
    sys.exit(1)

print("ADMIN_VOICE_IMPORT_GATE_PASS")
