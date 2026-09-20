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


models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
persistence_models = read("entry/src/main/ets/domain/model/PersistenceModels.ets")
migrator = read("entry/src/main/ets/domain/service/HomeworkSnapshotMigrator.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
service = read("entry/src/main/ets/application/submission/HomeworkSubmissionService.ets")
submission_local = read("entry/src/main/ets/data/local/SubmissionLocalDataSource.ets")
parent_evidence = read("entry/src/main/ets/application/submission/ParentSubmissionEvidenceService.ets")
remote_api = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")
repository = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
review_pane = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")
entry_ability = read("entry/src/main/ets/entryability/EntryAbility.ets")
controller = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionController.java")
backend_service = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionService.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionDtos.java")
e2e = read("backend/scripts/e2e_smoke.py")

require("photoUris: string[]" in models, "Submission must persist photoUris")
require("IMAGE = 'IMAGE'" in models and "MOCK_IMAGE" not in models, "Submission type must be real IMAGE only")
require("submitImages" in store and "submitMockImage" not in store, "Store must use real image submission")
require("submissions: Submission[]" in persistence_models and "submissions: snapshot.submissions" in migrator,
        "snapshot migrations must preserve durable submissions")
require("schemaVersion: HOMEWORK_SNAPSHOT_SCHEMA_VERSION" in store,
        "new snapshots must use the shared migration schema version")
require("MAX_SUBMISSION_PHOTOS: number = 6" in service, "Submission service must cap selection at six photos")
require("photoAccessHelper.PhotoViewPicker" in service, "Submission service must use PhotoViewPicker")
require("cameraPicker.pick" in service and "PickerMediaType.PHOTO" in service,
        "Submission service must support system camera capture")
require("fileIo.copyFile" in service and "fileUri.getUriFromPath" in service,
        "Selected picker photos must be copied into the app sandbox before persistence")
require("configure(context: common.UIAbilityContext)" in service,
        "Submission service must receive UIAbilityContext for sandbox storage")
require("HomeworkSubmissionService.instance.configure(this.context)" in entry_ability,
        "EntryAbility must initialize the submission service")
require("submissionPhotoUris" in study and "从图库选择" in study and "拍照" in study and "确认提交" in study,
        "Student workspace must support gallery/camera selection, preview and confirmation")
require("removeSubmissionPhoto" in study and "appendSubmissionPhotos" in study,
        "Student must be able to remove and append photos from multiple sources before submitting")
require("Image(uri)" in study,
        "Student workspace must render selected/submitted local photos")
require("PhotoPreviewDialog" in study and "private openPhotoPreview(uri: string)" in study and
        ".onClick(() => this.openPhotoPreview(uri))" in study,
        "Student workspace thumbnails must open the shared large photo preview")
require("ParentSubmissionEvidenceService" in review_pane and "CloudSubmissionPhotoStrip" in review_pane and
        "private LocalPhotos(uris: string[])" in review_pane and "Image(uri)" in review_pane,
        "V2 Parent Review must render remote submission photos and local seed/demo evidence")
require("RemoteSubmissionApi.instance.latest" in parent_evidence and
        "HomeworkSubmissionService.instance.listCached" in parent_evidence,
        "Parent evidence boundary must fetch only the latest remote submission with local persisted fallback")
require("MOCK_IMAGE" not in service + study + review_pane + parent_evidence + store + models,
        "Mock submission path must not remain in the real submission flow")

# V2 real assignments are server-authoritative: upload first, then update local cache from
# the returned Assignment snapshot. Seed/demo compatibility may still use local submitImages.
upload_pos = service.find("await RemoteSubmissionApi.instance.upload")
local_submit_pos = service.find("this.local.submitImages(\n        assignmentId", upload_pos)
require("HomeworkStore" not in service and "SubmissionLocalDataSource" in service,
        "submission application service must use SubmissionLocalDataSource instead of HomeworkStore")
require("HomeworkStore.instance.getSubmissionsForAssignment" in submission_local and
        "HomeworkStore.instance.submitImages" in submission_local,
        "legacy submission local adapter must isolate persisted Store submission access")
require(upload_pos >= 0, "real submissions must await the backend upload")
require(local_submit_pos > upload_pos,
        "real submissions must not mark local state SUBMITTED before backend success")
require("assignment.remoteVersion" in service and "RemoteAssignmentMapper.toLocal(result.assignment" in service,
        "submission service must send expected version and apply returned authoritative Assignment")
require("applyAuthoritative(authoritative)" in service and "applyAuthoritative(updated: Assignment)" in repository,
        "authoritative submission state must update the shared assignment repository cache")
require("this.queryCache = []" in repository,
        "repository refresh must invalidate stale query cache after conflict reconciliation")
require("version: number" in remote_api and "/submissions?version=${version}" in remote_api,
        "remote submission upload must carry the expected assignment version")
require("RemoteSubmissionCreateResponse" in remote_api and "assignment: RemoteAssignment" in remote_api,
        "remote submission upload must return the authoritative Assignment snapshot")
require("@RequestParam long version" in controller,
        "backend submission endpoint must require expected assignment version")
require("assignment.version != expectedVersion" in backend_service and "ApiExceptions.Conflict" in backend_service,
        "backend submission must reject stale assignment versions")
require('!"READY_TO_SUBMIT".equals(assignment.status)' in backend_service,
        "backend submission must only accept READY_TO_SUBMIT assignments")
require("assignmentRepository.saveAndFlush(assignment)" in backend_service,
        "backend must flush the Assignment version before returning submission success")
require("CreateResponse(Response submission, AssignmentDtos.Response assignment)" in dtos,
        "submission create response must include both submission and authoritative assignment")
require("stale submission version conflict" in e2e and "authoritative SUBMITTED assignment" in e2e,
        "real backend E2E must cover stale submission conflict and authoritative response")

if errors:
    print("REAL_SUBMISSION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("REAL_SUBMISSION_GATE_PASS")
