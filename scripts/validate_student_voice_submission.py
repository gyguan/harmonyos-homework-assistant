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
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
recorder = read("entry/src/main/ets/application/submission/SubmissionAudioRecorderService.ets")
submission = read("entry/src/main/ets/application/submission/HomeworkSubmissionService.ets")
remote = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")
module = read("entry/src/main/module.json5")
syscap = read("entry/src/main/syscap.json")
backend = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionService.java")
assignment_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
migration = read("backend/src/main/resources/db/migration/V26__submission_resources.sql")
review = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")
evidence = read("entry/src/main/ets/application/submission/ParentSubmissionEvidenceService.ets")
player = read("entry/src/main/ets/components/submission/SubmissionAudioEvidencePlayer.ets")

require("AUDIO = 'AUDIO'" in models, "SubmissionType must support AUDIO")
require("VoiceSubmissionPane" in study and "startSubmissionRecording" in study and
        "pauseSubmissionRecording" in study and "resumeSubmissionRecording" in study and
        "finishSubmissionRecording" in study and "submitRecordedAudio" in study,
        "student voice submission must support record/pause/resume/finish/submit")
require("this.pauseEmbeddedMedia()" in study,
        "student recording must pause assignment media to avoid recording the prompt")
require("media.createAVRecorder()" in recorder and
        "media.CodecMimeType.AUDIO_AAC" in recorder and
        "media.ContainerFormatType.CFT_MPEG_4A" in recorder,
        "student recording must use the supported AVRecorder AAC/M4A path")
require("ohos.permission.MICROPHONE" in module and
        "SystemCapability.Multimedia.Media.AVRecorder" in syscap,
        "voice submission must declare microphone permission and AVRecorder capability")
require("MIN_SUBMISSION_AUDIO_MS" in submission and "MAX_SUBMISSION_AUDIO_MS" in submission and
        "MAX_SUBMISSION_AUDIO_BYTES" in submission and "submitAudio" in submission,
        "client must validate recorded audio before upload")
require("fieldName: 'audio'" in remote and "audioDurationMs" in remote,
        "remote submission multipart must carry the recorded audio and duration")
require('"AUDIO_IMAGE".equals(assignment.contentType)' in backend and
        "mediaPolicy.validateAudio(audio)" in backend and "safePhotos.isEmpty()" in backend,
        "backend must derive the voice submission contract from the assignment")
require("create table submission_resource" in migration.lower() and
        "'IMAGE'" in migration and "submission_photo" in migration,
        "V26 must introduce generic submission resources and migrate historical photos")
require("submissionResources.findBySubmissionIdOrderBySortOrderAscIdAsc" in assignment_service and
        "fileTransactions.deleteAfterCommit(storagePath)" in assignment_service,
        "assignment deletion must clean generic submission files after commit")
require("SubmissionAudioEvidencePlayer" in review and "remoteAudioResource" in review and
        "remoteResources" in evidence and "resourceType === 'AUDIO'" in review,
        "parent review must surface the latest student audio evidence")
require("AssignmentAudioPlayerService" in player and "downloadResource" in player,
        "parent review audio must use the shared player and authenticated resource download")

if errors:
    print("STUDENT_VOICE_SUBMISSION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STUDENT_VOICE_SUBMISSION_GATE_PASS")
