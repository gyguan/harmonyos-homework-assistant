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


dtos = read("backend/src/main/java/com/xiaoban/homework/organizer/HomeworkOrganizerDtos.java")
client = read("backend/src/main/java/com/xiaoban/homework/organizer/ConfigurableHomeworkOrganizerModelClient.java")
remote = read("entry/src/main/ets/application/remote/HomeworkOrganizerRemoteApi.ets")
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
confirmation_components = read(
    "entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
shared_editor = read("entry/src/main/ets/components/assignment/AssignmentEditForm.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")

require("int expectedMinutes" in dtos,
        "organizer API candidate must carry expectedMinutes")
require('candidateProperties.put("expectedMinutes"' in client,
        "structured AI schema must request expectedMinutes")
require('"minimum", 5' in client and '"maximum", 120' in client,
        "AI suggested duration must be schema-bounded to 5..120 minutes")
require("学生年级" in client and "不包含休息" in client,
        "AI prompt must estimate focused child work time using grade context")
require("expectedMinutes(item.expectedMinutes())" in client,
        "backend must normalize model-suggested duration before returning it")
require("expectedMinutes: number" in remote,
        "HarmonyOS remote candidate must parse expectedMinutes")
require("expectedMinutes: this.expectedMinutes(remote.expectedMinutes)" in remote,
        "HarmonyOS candidate must use AI suggested duration rather than hard-coded 20")
require("return Math.max(5, Math.min(120" in remote,
        "HarmonyOS must defensively bound provider duration")
require("onMinutesChange" in confirmation_components and "预计用时" in confirmation_components and
        "AssignmentEditForm({" in confirmation_components and
        "placeholder: '自定义'" in shared_editor and
        "if (minutes < 1) minutes = 1;" in shared_editor and
        "if (minutes > 240) minutes = 240;" in shared_editor,
        "parent confirmation must keep quick presets on cards and a bounded custom duration in the editor")
require("onMinutesChange: (candidate: CandidateAssignment, minutes: number)" in confirmation,
        "confirmation page must persist duration changes from the reactive editor")
require(".bindSheet($$this.showEditorSheet" in confirmation and
        ".bindSheet($this.showEditorSheet" not in confirmation and
        "private CandidateEditorSheet()" in confirmation and
        "onSelect: () => this.openEditor(item.id)" in confirmation,
        "candidate editing must open in a bottom sheet instead of an inline editor at page bottom")
require("private CandidateListHeader()" in confirmation and "Text('＋ 新增')" in confirmation and
        "Button('＋ 手工新增一项'" not in confirmation,
        "manual add must live in the candidate-list header instead of below the list")
require("CandidateDurationControl" in confirmation_components and
        confirmation_components.count("onMinutesChange(this.item") >= 5,
        "confirmation duration controls must expose common preset durations")
require("placeholder: '自定义'" in shared_editor and
        "if (minutes < 1) minutes = 1;" in shared_editor and
        "if (minutes > 240) minutes = 240;" in shared_editor,
        "confirmation editor must support a bounded custom minute value")
require("label: '10'" in confirmation_components and "label: '15'" in confirmation_components and
        "label: '20'" in confirmation_components and "label: '30'" in confirmation_components and
        "label: '45'" in confirmation_components,
        "duration presets must remain split-friendly instead of long labelled chips")
require("expectedMinutes: candidate.expectedMinutes" in store,
        "published assignment must keep the parent-confirmed duration")

if errors:
    print("AI_EXPECTED_MINUTES_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("AI_EXPECTED_MINUTES_GATE_PASS")
