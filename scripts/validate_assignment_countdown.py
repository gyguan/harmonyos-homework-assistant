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


migration = read("backend/src/main/resources/db/migration/V4__assignment_timing.sql")
entity = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentEntity.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentDtos.java")
service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
remote_models = read("entry/src/main/ets/application/remote/RemoteModels.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
confirmation_components = read(
    "entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
shared_editor = read("entry/src/main/ets/components/assignment/AssignmentEditForm.ets")
student_home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
countdown = read("entry/src/main/ets/components/assignment/AssignmentCountdownCard.ets")
parent_review = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")

for column in ["expected_minutes", "started_at_epoch_ms", "finished_at_epoch_ms", "elapsed_seconds"]:
    require(column in migration, f"assignment timing migration missing column: {column}")
require("between 1 and 240" in migration.lower(), "expected homework minutes must be database-bounded")

for field in ["expectedMinutes", "startedAtEpochMs", "finishedAtEpochMs", "elapsedSeconds"]:
    require(field in entity, f"backend assignment entity missing timing field: {field}")
    require(field in dtos, f"backend assignment API missing timing field: {field}")
    require(field in models, f"HarmonyOS assignment model missing timing field: {field}")
    require(field in remote_models and field in remote_api, f"cloud sync missing timing field: {field}")

require("System.currentTimeMillis()" in service and '"IN_PROGRESS"' in service,
        "backend must stamp timing transitions rather than relying only on client counters")
require("Date.now()" in store and "Math.floor((now - this.assignments[index].startedAtEpochMs) / 1000)" in store,
        "local store must persist start/end timestamps and actual elapsed seconds")
require("expectedMinutes: candidate.expectedMinutes" in store,
        "published assignments must retain the parent-selected expected duration")

for duration in ["10", "15", "20", "30", "45"]:
    require(f"selected: this.item.expectedMinutes === {duration}" in confirmation_components and
            f"this.onMinutesChange(this.item, {duration})" in confirmation_components,
            f"parent confirmation must expose reactive quick duration option: {duration} minutes")
require("预计用时" in confirmation_components and
        "placeholder: '自定义'" in shared_editor and
        "if (minutes < 1) minutes = 1;" in shared_editor and
        "if (minutes > 240) minutes = 240;" in shared_editor and
        "onMinutesChange: (candidate: CandidateAssignment, minutes: number)" in confirmation,
        "parent must be able to use quick presets or a custom expected completion time before publishing")
# Student Home presents the time budget on each directly actionable task card.
require("`预计 ${this.assignment.expectedMinutes} 分钟`" in student_home and "StudentTodayTaskCard" in student_home,
        "V2 student home must show each task's time budget before starting")
require("AssignmentCountdownCard" in study,
        "student study workspace must render the homework countdown")

for phrase in ["还剩", "超出", "用了", "预计"]:
    require(phrase in countdown, f"countdown UI missing required state: {phrase}")
require("fontSize(17)" in countdown and "height(5)" in countdown and "private hint()" not in countdown,
        "countdown must remain compact and avoid instructional copy competing with the task")
require("this.nowEpochMs - this.assignment.startedAtEpochMs" in countdown,
        "countdown must derive remaining time from timestamps so it survives page/background gaps")
require("setInterval" in countdown and "clearInterval" in countdown,
        "countdown component must refresh while visible and release its timer when hidden")
# Slice 4 moved planned-vs-actual timing from the old all-in-one Progress detail into the
# dedicated Parent Review surface where submission evidence and acceptance decisions live.
require("private actualMinutes(item: Assignment)" in parent_review and
        "`实际 ${this.actualMinutes(this.assignment()!)} 分钟`" in parent_review and
        "`预计 ${this.assignment()!.expectedMinutes} 分钟`" in parent_review,
        "parent review must compare planned and actual homework time")

if errors:
    print("ASSIGNMENT_COUNTDOWN_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ASSIGNMENT_COUNTDOWN_GATE_PASS")
