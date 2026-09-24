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
repository = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
publisher = read("entry/src/main/ets/application/import/HomeworkBatchPublishService.ets")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
organizer_api = read("entry/src/main/ets/application/remote/HomeworkOrganizerRemoteApi.ets")
edit_form = read("entry/src/main/ets/components/assignment/AssignmentEditForm.ets")
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
dashboard = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
workflow = read(".github/workflows/static-gate.yml")

require("EXTRA = 'EXTRA'" in models, "unified create flow must keep AssignmentType.EXTRA")
for token in ["READING = '阅读'", "READ_ALOUD = '朗读'", "SPORTS = '体育'",
              "PRACTICE = '实践'", "INTEREST = '兴趣'"]:
    require(token in models, f"missing extracurricular category: {token}")

# There is one Assignment aggregate and one publish path. Category determines SCHOOL vs EXTRA.
require("async create(assignment: Assignment)" in repository and
        "HomeworkRemoteApi.instance.create(assignment)" in repository,
        "DefaultAssignmentRepository must keep the authoritative Assignment create command")
require("this.assignmentType(candidate.subject)" in publisher and
        "return AssignmentType.SCHOOL" in publisher and
        "return AssignmentType.EXTRA" in publisher,
        "batch publish must derive SCHOOL/EXTRA without a parallel task domain")
require("ExtraHomework" not in publisher + import_service + repository,
        "unified create flow must not introduce a parallel ExtraHomework domain")

# Parent-selected subject is authoritative during manual import; specialized extracurricular
# categories remain correctable in confirmation and supported by the organizer contract.
require("applySelectedSubject" in import_service and "fallbackSubject" not in import_service,
        "manual import must not infer or overwrite the parent-selected subject from free text")
for token in ["Subject.READING", "Subject.READ_ALOUD", "Subject.SPORTS",
              "Subject.PRACTICE", "Subject.INTEREST", "Subject.OTHER"]:
    require(token in organizer_api, f"AI organizer client must accept unified category: {token}")

# Confirmation remains the single correction point and exposes all categories.
require("HomeworkConfirmationPage" in confirmation or "确认发布" in confirmation,
        "unified create flow must retain the confirmation surface")
for token in ["Subject.CHINESE", "Subject.MATH", "Subject.ENGLISH", "Subject.READING",
              "Subject.READ_ALOUD", "Subject.SPORTS", "Subject.PRACTICE",
              "Subject.INTEREST", "Subject.OTHER"]:
    require(token in edit_form, f"confirmation editor must allow category correction: {token}")

# Product navigation is unified: no standalone extra-task route or parent-home card.
require("PARENT_EXTRA_CREATE" not in routes and "PARENT_EXTRA_CREATE" not in shell,
        "standalone extracurricular create route must not reappear")
require("ParentExtraAssignmentPage" not in shell and "onOpenExtra" not in dashboard,
        "parent shell/dashboard must not expose the legacy standalone extracurricular page")
require("onOpenAssignment" in dashboard and "Text('布置作业')" in dashboard,
        "Parent Home must expose one unified assignment creation action")
require("AppRoute.PARENT_IMPORT" in shell and "HomeworkImportRoutePage" in shell,
        "unified assignment create must remain a NavDestination deep page")

require("Validate V2 Slice 6 extracurricular create" in workflow,
        "CI must continue validating extracurricular semantics after UI consolidation")

if errors:
    print("V2_SLICE6_EXTRA_ASSIGNMENT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE6_EXTRA_ASSIGNMENT_GATE_PASS")
