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
delete_migration = read("backend/src/main/resources/db/migration/V6__assignment_delete_cascade.sql")
entity = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentEntity.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentDtos.java")
service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")
file_storage = read("backend/src/main/java/com/xiaoban/homework/storage/FileStorage.java")
models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
remote_models = read("entry/src/main/ets/application/remote/RemoteModels.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
remote_submission_cache = read("entry/src/main/ets/application/remote/RemoteSubmissionCache.ets")
assignment_card = read("entry/src/main/ets/components/assignment/AssignmentCard.ets")
countdown = read("entry/src/main/ets/components/assignment/AssignmentCountdownCard.ets")

# This gate intentionally keeps only the durable model/backend compatibility checks from the
# pre-V2 Parent Progress implementation. Slice 4 UI structure is validated separately by
# validate_v2_slice4_parent_surfaces.py; old PhoneLayout/PadLayout and direct HomeworkStore
# assumptions must never be reintroduced here.
require("review_note" in migration, "V5 migration must persist parent review note")
for text, label in [(entity, "entity"), (dtos, "API DTO"), (models, "HarmonyOS model"),
                    (remote_models, "remote model"), (remote_api, "remote API")]:
    require("reviewNote" in text, f"assignment {label} must carry reviewNote")
require("input.reviewNote()" in service, "backend assignment service must persist reviewNote")
require("reviewNote: source.reviewNote" in store, "local snapshot clone must preserve reviewNote")
require("reviewNote: ''" in store, "newly published assignments must initialize an empty review note")
require("reviewAssignment" in store and "AssignmentStatus.COMPLETED" in store and "AssignmentStatus.NEEDS_REWORK" in store,
        "seed/demo compatibility store must still support parent review transitions")
require("家长订正说明" in assignment_card and "reviewNote" in assignment_card,
        "student assignment card must show parent correction note")
require("家长请你订正" in countdown and "reviewNote" in countdown,
        "student study view must show parent correction note")

# Assignment management remains a backend capability even though the V2 Progress surface no
# longer mixes edit/delete controls into the review workflow.
require("async delete(assignmentId: string)" in remote_api and "http.RequestMethod.DELETE" in remote_api,
        "HarmonyOS remote API must expose assignment DELETE")
require("@DeleteMapping(\"/assignments/{id}\")" in controller and "service.delete(familyId, id)" in controller,
        "backend must expose owned assignment deletion")
require("public void delete(UUID familyId, String id)" in service and "storage.delete(photo.storagePath)" in service,
        "backend assignment deletion must clean stored submission photos")
require("on delete cascade" in delete_migration.lower() and "submission_assignment_id_fkey" in delete_migration,
        "assignment deletion migration must cascade submission relations")
require("void delete(String storagePath)" in file_storage,
        "FileStorage must support physical photo cleanup")
require("remove(assignmentId" in remote_submission_cache,
        "remote submission cache must still support cleanup when assignments are removed")

if errors:
    print("PARENT_REVIEW_COMPAT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PARENT_REVIEW_COMPAT_GATE_PASS")
