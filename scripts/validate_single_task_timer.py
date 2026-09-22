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
state_machine = read("entry/src/main/ets/domain/service/AssignmentStateMachine.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
countdown = read("entry/src/main/ets/components/assignment/AssignmentCountdownCard.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
home_vm = read("entry/src/main/ets/features/student/home/StudentHomeViewModel.ets")
backend_policy = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentStatePolicy.java")
backend_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")

require("PAUSED = 'PAUSED'" in models, "assignment model must define PAUSED")
require("AssignmentStatus.PAUSED" in state_machine and "'已暂停'" in state_machine,
        "local state machine must support and label PAUSED")
require("IN_PROGRESS && next" not in store or "elapsedSeconds +=" in store,
        "leaving IN_PROGRESS must accumulate rather than overwrite elapsed time")
require("pauseOtherAssignments" in store and "AssignmentStatus.PAUSED" in store,
        "starting another local task must pause the existing active task")
require("current !== AssignmentStatus.PAUSED" in store,
        "resuming PAUSED must preserve accumulated elapsed seconds")
require("pauseAssignment" in store, "store must expose explicit pause action")
require("已暂停 · 还剩" in countdown and "assignment.elapsedSeconds" in countdown,
        "countdown must render paused cumulative timing")
require("暂停一下" in study and "AssignmentStatus.PAUSED" in study,
        "study workspace must expose pause/resume controls")
# Student Home action labels live with the direct task-card presentation, while PAUSED remains
# part of the ViewModel's actionable ordering.
require("AssignmentStatus.PAUSED" in home_vm and "return 1;" in home_vm and
        "this.assignment.status === AssignmentStatus.PAUSED" in home and
        "return '继续'" in home,
        "V2 Student Home must expose paused tasks as resumable")
require('"PAUSED"' in backend_policy,
        "backend state policy must support PAUSED")
require("pauseOtherActive" in backend_service and 'other.status = "PAUSED"' in backend_service,
        "backend must enforce one active assignment per student")
require("other.elapsedSeconds +=" in backend_service,
        "backend auto-pause must accumulate active elapsed seconds")

if errors:
    print("SINGLE_TASK_TIMER_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("SINGLE_TASK_TIMER_GATE_PASS")
