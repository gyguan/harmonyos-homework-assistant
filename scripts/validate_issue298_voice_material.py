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


migration = read("backend/src/main/resources/db/migration/V15__voice_material_assets.sql")
assignment_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialAssignmentService.java")
material_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialService.java")
resource_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentResourceService.java")
delete_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
picker = read("entry/src/main/ets/application/assignment/VoiceMaterialDirectoryPicker.ets")
remote = read("entry/src/main/ets/application/remote/RemoteVoiceMaterialApi.ets")
auto = read("entry/src/main/ets/application/assignment/VoiceMaterialAutoCreateService.ets")
index = read("entry/src/main/ets/pages/Index.ets")
page = read("entry/src/main/ets/features/parent/voice/ParentVoiceMaterialPage.ets")
dashboard = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
context = read("CONTEXT.md")
voice_e2e = read("backend/scripts/voice_material_e2e.py")

require("create table media_asset" in migration and
        "asset_id uuid references media_asset(id)" in migration,
        "#298 must store reusable physical media in MediaAsset and link AssignmentResource by asset_id")
require("uq_voice_material_auto_daily unique (family_id, student_id, business_date)" in migration,
        "#298 daily automatic creation must be enforced by a database unique constraint")
require("subject_code varchar(64) not null" in migration,
        "#298 VoiceMaterialPackage must persist subjectCode instead of inferring subject from directory name")
require('private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai")' in assignment_service and
        "findByFamilyIdAndStudentIdAndBusinessDate" in assignment_service,
        "#298 automatic creation must use a server-authoritative Asia/Shanghai business day")
require("students.requireOwnedForUpdate(familyId, studentId)" in assignment_service and
        "packages.lockNextReady" in assignment_service,
        "#298 daily auto-create must serialize per student before consuming a READY package")
require("students.requireOwnedForUpdate(familyId, batch.studentId)" in material_service,
        "#298 batch completion must serialize per student before applying fingerprints and READY state")
require("students.requireOwnedForUpdate(familyId, snapshot.studentId)" in material_service and
        "packages.lockOwned(familyId, packageId)" in material_service,
        "#298 file upload retries must serialize with batch completion using Student -> Package lock order")
require("students.requireOwnedForUpdate(familyId, snapshot.studentId)" in assignment_service and
        "packages.lockOwned(familyId, packageId)" in assignment_service,
        "#298 manual package consumption must use the same Student -> Package lock order")
require("LocalTime.of(23, 59)" in assignment_service and
        'item.dueAt == null ? "今天" : ""' in assignment_service,
        "#298 an undated package auto-created for the day must appear in the student Today view")
require('"a-voicepkg-" + item.id' in assignment_service and
        "assignmentResources.linkAssets" in assignment_service,
        "#298 package consumption must use deterministic Assignment id and shared media links")
require("item.status = \"CONSUMED\"" in assignment_service and
        "item.consumedAssignmentId = assignment.id()" in assignment_service,
        "#298 package consumption must be durable and idempotent")
require("input.subjectCode().trim().toUpperCase" in material_service and
        "directoryName" in material_service,
        "#298 subjectCode must be explicit package metadata while directoryName stays a separate field")
require("normalizeSortOrder" in material_service and
        "relativeName.toLowerCase" in material_service,
        "#298 image ordering must be normalized by file name")
require("entity.assetId = asset.id" in resource_service and
        "entity.storagePath = null" in resource_service,
        "#298 new Assignment resources must reference MediaAsset without copying files")
require("families.lockById(familyId)" in read("backend/src/main/java/com/xiaoban/homework/media/MediaAssetService.java"),
        "#298 MediaAsset dedup must serialize same-family inserts instead of recovering from a rollback-only unique-key exception")
require("if (resource.assetId == null && resource.storagePath != null" in delete_service,
        "#298 deleting Assignment must not delete shared MediaAsset files")
require("allowsMulFolderSelection = true" in picker and
        "deviceInfo.sdkApiVersion >= 26" in picker and
        "if (!this.supportsMultiFolderPicker())" in picker and
        "this.context === null || !this.supportsMultiFolderPicker()" in picker and
        "getFullDirectoryUri()" in picker and
        "selectFilesFallback" in picker and
        "DocumentSelectMode.FILE" in picker,
        "#298 picker must guard API 26 multi-folder selection and fall back to file grouping on API 20-25")
require("createBatch(studentId" in remote and
        "uploadFile(packageId" in remote and
        "completeBatch(batchId" in remote,
        "#298 parent client must upload material packages through the dedicated batch API")
require("checkToday(studentId" in auto and
        "autoCreateNext(studentId)" in auto,
        "#298 student client must delegate daily creation policy to the backend")
require("VoiceMaterialAutoCreateService.instance.checkToday(studentId)" in index,
        "#298 student entry must trigger the server-authoritative daily check")
require("Text('语音素材库')" in dashboard and "onOpenVoiceMaterial" in dashboard,
        "#298 parent dashboard must expose the voice material library")
require("sys.symbol.exclamationmark_circle_fill" not in page,
        "#298 parent material page must not depend on a version-sensitive feedback system symbol")
require("private PendingSection()" in page and "private LibrarySection()" in page and
        "setPackageSubject" in page and
        "setPackageExpectedMinutes" in page and
        "registrationFailureCount" in read("entry/src/main/ets/features/parent/voice/ParentVoiceMaterialViewModel.ets"),
        "#298 parent material page must support staging, per-directory subject/duration override, partial-failure feedback and library status")
require("voiceMaterials.existsByFamilyIdAndStudentId" in read("backend/src/main/java/com/xiaoban/homework/student/StudentService.java"),
        "#298 student deletion must be rejected while voice-material batches still reference the student")
require("legacy manual voice assignment" in voice_e2e and
        "concurrent retry created duplicate package file" in voice_e2e,
        "#298 E2E must preserve legacy storage-path voice compatibility and concurrent retry idempotency")
require("Media Asset（媒体资产）" in context and
        "Daily Voice Auto Create（每日语音自动创建）" in context,
        "#298 domain language must be documented in CONTEXT.md")

if errors:
    print("ISSUE_298_VOICE_MATERIAL_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_298_VOICE_MATERIAL_GATE_PASS")
