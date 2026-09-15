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
student_today = read("entry/src/main/ets/features/student/today/StudentTodayPage.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
countdown = read("entry/src/main/ets/components/assignment/AssignmentCountdownCard.ets")
parent_progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")

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
    require(f"this.TimeChip(item, {duration})" in confirmation,
            f"parent confirmation must expose quick duration option: {duration} minutes")
require("预计完成时间" in confirmation and "updateExpectedMinutes" in confirmation,
        "parent must be able to edit expected completion time before publishing")
require("预计 ${this.nextAssignment()!.expectedMinutes} 分钟" in student_today,
        "student Today page must show the time budget before starting")
require("AssignmentCountdownCard" in study,
        "student study workspace must render the homework countdown")

for phrase in ["还剩", "已超出", "实际用时", "点击“开始作业”后开始倒计时"]:
    require(phrase in countdown, f"countdown UI missing required state: {phrase}")
require("this.nowEpochMs - this.assignment.startedAtEpochMs" in countdown,
        "countdown must derive remaining time from timestamps so it survives page/background gaps")
require("setInterval" in countdown and "clearInterval" in countdown,
        "countdown component must refresh while visible and release its timer when hidden")
require("预计 ${item.expectedMinutes} 分钟 · 实际 ${actualMinutes} 分钟" in parent_progress,
        "parent progress must compare planned and actual homework time")

if errors:
    print("ASSIGNMENT_COUNTDOWN_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ASSIGNMENT_COUNTDOWN_GATE_PASS")
