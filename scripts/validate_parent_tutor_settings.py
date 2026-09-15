#!/usr/bin/env python3
from pathlib import Path

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


store = read("entry/src/main/ets/data/HomeworkStore.ets")
parent = read("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
student = read("entry/src/main/ets/features/student/profile/StudentProfilePage.ets")
tutor = read("entry/src/main/ets/application/remote/TutorRemoteApi.ets")

require("updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean)" in store,
        "HomeworkStore must expose an explicit Tutor settings mutation")
require("this.settings.tutorGuidanceFirst = tutorGuidanceFirst" in store and
        "this.settings.directAnswerAllowed = directAnswerAllowed" in store,
        "Tutor settings mutation must update both persisted AppSettings fields")
store_method = store.split("updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean)", 1)
require(len(store_method) == 2 and "this.requestPersist();" in store_method[1].split("getStudents()", 1)[0],
        "Tutor settings mutation must request Preferences snapshot persistence")

require("AI 辅导规则" in parent and "toggleGuidanceFirst" in parent and "toggleDirectAnswer" in parent,
        "parent 我的 must expose both Tutor rule controls")
require("HomeworkStore.instance.updateTutorSettings" in parent,
        "parent page must mutate Tutor rules only through HomeworkStore")
require("允许直接答案" in parent and "默认建议关闭" in parent,
        "parent UI must keep direct answers opt-in and explain the safer default")

require("tutorGuidanceFirst" in student and "directAnswerAllowed" in student,
        "student 我的 must reflect the current parent Tutor rules")
require("updateTutorSettings" not in student,
        "student 我的 must remain read-only for Tutor rules")

require("let settings = HomeworkStore.instance.getSettings()" in tutor and
        "guidanceFirst: settings.tutorGuidanceFirst" in tutor and
        "directAnswerAllowed: settings.directAnswerAllowed" in tutor,
        "Tutor requests must use the latest persisted AppSettings values")

if errors:
    print("PARENT_TUTOR_SETTINGS_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PARENT_TUTOR_SETTINGS_GATE_PASS")
