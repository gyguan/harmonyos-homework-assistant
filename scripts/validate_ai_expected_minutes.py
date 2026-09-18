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
        "TextInput({ text: `${this.item.expectedMinutes}` })" in confirmation_components,
        "parent confirmation must keep manual duration override in the reactive editor")
require("onMinutesChange: (candidate: CandidateAssignment, minutes: number)" in confirmation,
        "confirmation page must persist duration changes from the reactive editor")
require("expectedMinutes: candidate.expectedMinutes" in store,
        "published assignment must keep the parent-confirmed duration")

if errors:
    print("AI_EXPECTED_MINUTES_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("AI_EXPECTED_MINUTES_GATE_PASS")
