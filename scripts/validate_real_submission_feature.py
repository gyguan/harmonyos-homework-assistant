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
store = read("entry/src/main/ets/data/HomeworkStore.ets")
service = read("entry/src/main/ets/application/submission/HomeworkSubmissionService.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
entry_ability = read("entry/src/main/ets/entryability/EntryAbility.ets")

require("photoUris: string[]" in models, "Submission must persist photoUris")
require("IMAGE = 'IMAGE'" in models and "MOCK_IMAGE" not in models, "Submission type must be real IMAGE only")
require("submitImages" in store and "submitMockImage" not in store, "Store must use real image submission")
require("SNAPSHOT_SCHEMA_VERSION: number = 4" in store,
        "real submission must remain durable after the multi-child snapshot upgrade to v4")
require("MAX_SUBMISSION_PHOTOS: number = 6" in service, "Submission service must cap selection at six photos")
require("photoAccessHelper.PhotoViewPicker" in service, "Submission service must use PhotoViewPicker")
require("fileIo.copyFile" in service and "fileUri.getUriFromPath" in service,
        "Selected picker photos must be copied into the app sandbox before persistence")
require("configure(context: common.UIAbilityContext)" in service,
        "Submission service must receive UIAbilityContext for sandbox storage")
require("HomeworkSubmissionService.instance.configure(this.context)" in entry_ability,
        "EntryAbility must initialize the submission service")
require("submissionPhotoUris" in study and "选择作业照片" in study and "确认提交" in study,
        "Student workspace must select, preview and confirm real photos")
require("removeSubmissionPhoto" in study and "重新选择照片" in study,
        "Student must be able to remove/reselect photos before submitting")
require("Image(uri)" in study and "submission.photoUris" in progress,
        "Student and parent surfaces must render submitted images")
require("MOCK_IMAGE" not in service + study + progress + store + models,
        "Mock submission path must not remain in the real submission flow")

if errors:
    print("REAL_SUBMISSION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("REAL_SUBMISSION_GATE_PASS")
