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
selection_controls = read("entry/src/main/ets/components/selection/SelectionControls.ets")
tutor = read("entry/src/main/ets/application/remote/TutorRemoteApi.ets")

require("updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean)" in store,
        "HomeworkStore must expose an explicit Tutor settings mutation")
require("this.settings.tutorGuidanceFirst = tutorGuidanceFirst" in store and
        "this.settings.directAnswerAllowed = directAnswerAllowed" in store,
        "Tutor settings mutation must update both persisted AppSettings fields")
store_method = store.split("updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean)", 1)
require(len(store_method) == 2 and "this.requestPersist();" in store_method[1].split("getStudents()", 1)[0],
        "Tutor settings mutation must request Preferences snapshot persistence")

require("AI 辅导规则" in parent and "SettingsToggleRow" in parent,
        "parent 我的 must expose both Tutor rule controls through reactive switch rows")
require("private TutorRule(" not in parent and "toggleGuidanceFirst" not in parent and "toggleDirectAnswer" not in parent,
        "parent 我的 must not keep stale boolean Builder/toggle wrappers")
require("HomeworkStore.instance.updateTutorSettings" in parent,
        "parent page must mutate Tutor rules only through HomeworkStore")
require("允许直接答案" in parent and "默认建议关闭" in parent,
        "parent UI must keep direct answers opt-in and explain the safer default")
require("export struct SettingsToggleRow" in selection_controls and
        "@Prop isEnabled: boolean = false;" in selection_controls and
        "Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })" in selection_controls and
        ".onChange((value: boolean) => this.onToggle(value))" in selection_controls,
        "shared Tutor switch must bind and emit the real native Toggle value through isEnabled")
require("@Prop enabled:" not in selection_controls,
        "custom ArkUI components must not shadow the inherited enabled() attribute with @Prop enabled")
for expression in [
    "isEnabled: this.tutorGuidanceFirst()",
    "isEnabled: this.directAnswerAllowed()",
    "onToggle: (enabled: boolean) => this.updateTutorSettings(enabled, this.directAnswerAllowed())",
    "onToggle: (enabled: boolean) => this.updateTutorSettings(this.tutorGuidanceFirst(), enabled)",
]:
    require(expression in parent, f"parent Tutor rule must bind current state directly: {expression}")

require("tutorGuidanceFirst" in student and "directAnswerAllowed" in student,
        "student 我的 must reflect the current parent Tutor rules")
require("ReadonlySettingStateRow" in student and "private RuleRow(" not in student,
        "student 我的 must render Tutor rule state through the reactive read-only row")
require("isEnabled: this.settings().tutorGuidanceFirst" in student and
        "isEnabled: this.settings().directAnswerAllowed" in student,
        "student 我的 must bind read-only Tutor state through non-conflicting isEnabled props")
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
