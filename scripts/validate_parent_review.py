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


migration = read("backend/src/main/resources/db/migration/V5__assignment_parent_review.sql")
entity = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentEntity.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentDtos.java")
service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
remote_models = read("entry/src/main/ets/application/remote/RemoteModels.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
parent_progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
assignment_card = read("entry/src/main/ets/components/assignment/AssignmentCard.ets")
countdown = read("entry/src/main/ets/components/assignment/AssignmentCountdownCard.ets")

require("review_note" in migration, "V5 migration must persist parent review note")
for text, label in [(entity, "entity"), (dtos, "API DTO"), (models, "HarmonyOS model"),
                    (remote_models, "remote model"), (remote_api, "remote API")]:
    require("reviewNote" in text, f"assignment {label} must carry reviewNote")
require("input.reviewNote()" in service, "backend assignment service must persist reviewNote")
require("reviewNote: source.reviewNote" in store, "local snapshot clone must preserve reviewNote")
require("reviewNote: ''" in store, "newly published assignments must initialize an empty review note")
require("reviewAssignment" in store and "AssignmentStatus.COMPLETED" in store and "AssignmentStatus.NEEDS_REWORK" in store,
        "local store must support complete/rework parent review transitions")
for phrase in ["家长验收", "确认完成", "需要订正", "验收作业"]:
    require(phrase in parent_progress, f"parent progress missing review action: {phrase}")
require("reviewNoteDraft.trim().length > 0" in parent_progress,
        "rework action must require a concrete parent correction note")
require("items[items.length - 1]" in parent_progress,
        "parent review must show the newest local resubmission")
require("家长订正说明" in assignment_card and "reviewNote" in assignment_card,
        "student assignment list must show parent correction note")
require("家长请你订正" in countdown and "reviewNote" in countdown,
        "student study view must show parent correction note")

if errors:
    print("PARENT_REVIEW_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PARENT_REVIEW_GATE_PASS")
