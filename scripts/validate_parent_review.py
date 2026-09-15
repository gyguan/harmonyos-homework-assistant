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
parent_progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
assignment_card = read("entry/src/main/ets/components/assignment/AssignmentCard.ets")
assignment_list_item = read("entry/src/main/ets/components/assignment/AssignmentListItem.ets")
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
require("onStoreChanged: () => void = () => {};" in parent_progress,
        "ParentProgressPage must declare the onStoreChanged callback passed by AppShell")
require("this.onStoreChanged();" in parent_progress,
        "ParentProgressPage must notify AppShell after a successful review mutation")
require("ParentProgressPage({" in app_shell and "onStoreChanged: () => this.touchStore()" in app_shell,
        "AppShell must wire ParentProgressPage store changes back to the shell revision")
require("家长订正说明" in assignment_card and "reviewNote" in assignment_card,
        "student assignment card must show parent correction note")
require("家长请你订正" in countdown and "reviewNote" in countdown,
        "student study view must show parent correction note")

for phrase in ["编辑任务", "保存修改", "删除任务", "确认删除"]:
    require(phrase in parent_progress, f"parent assignment management missing action: {phrase}")
require("AssignmentListItem" in parent_progress and "onOpen: () => this.openDetail(item)" in parent_progress,
        "parent progress must open details by tapping the whole assignment row")
require("export struct AssignmentListItem" in assignment_list_item,
        "shared native assignment list item must exist")
require("syncDirty: true" in parent_progress and "replaceAssignmentsForActiveStudent(next)" in parent_progress,
        "published assignment edits must persist locally and enter the existing sync pipeline")
require("BackendSession.instance.isConnected()" in parent_progress and "HomeworkRemoteApi.instance.delete(item.id)" in parent_progress,
        "synced assignment deletion must require cloud connectivity and delete remote state first")
require("RemoteSubmissionCache.instance.remove(assignmentId)" in parent_progress and "remove(assignmentId" in remote_submission_cache,
        "assignment deletion must clear cached remote submission metadata")
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

require("@State private subjectFilter: string = 'ALL'" in parent_progress and "filteredAssignments()" in parent_progress,
        "parent progress must keep an explicit subject filter state")
require("SubjectTab('ALL', '全部')" in parent_progress and
        "SubjectTab(Subject.CHINESE, '语文')" in parent_progress and
        "SubjectTab(Subject.MATH, '数学')" in parent_progress and
        "SubjectTab(Subject.ENGLISH, '英语')" in parent_progress,
        "parent progress must expose all/chinese/math/english filters")
require("this.subjectCount(key)" in parent_progress and "this.filteredAssignments()" in parent_progress,
        "parent subject filters must display counts and drive the progress list")
require("@State private dateFilter: DueDateFilterKey = DueDateFilterKey.ALL" in parent_progress,
        "parent progress must keep an explicit due-date filter state")
for token in ["DueDateFilterKey.ALL", "DueDateFilterKey.TODAY", "DueDateFilterKey.TOMORROW",
              "DueDateFilterKey.THIS_WEEK", "DueDateFilterKey.OVERDUE"]:
    require(token in parent_progress, f"parent progress missing date filter: {token}")
require("AssignmentDueDate.matches(item, this.dateFilter)" in parent_progress and
        "matchesSubject(item, this.subjectFilter)" in parent_progress,
        "parent progress must combine subject and due-date filtering")
require("this.dateCount(key)" in parent_progress and "private DateTab(" in parent_progress and "private FilterPanel()" in parent_progress,
        "parent due-date filters must display counts in a dedicated lightweight filter row")
require("private PhoneLayout()" in parent_progress and "private PadLayout()" in parent_progress and
        "this.sizeClass === WindowSizeClass.COMPACT" in parent_progress,
        "parent progress must use phone detail navigation and pad list-detail layout")
require("this.AssignmentDetail(this.selectedAssignment()!)" in parent_progress,
        "subject/date filtering must not replace or block assignment detail rendering")

if errors:
    print("PARENT_REVIEW_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PARENT_REVIEW_GATE_PASS")
