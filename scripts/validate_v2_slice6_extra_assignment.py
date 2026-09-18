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
port = read("entry/src/main/ets/domain/port/AssignmentRepository.ets")
repository = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
view_model = read("entry/src/main/ets/features/parent/extra/ParentExtraAssignmentViewModel.ets")
page = read("entry/src/main/ets/features/parent/extra/ParentExtraAssignmentPage.ets")
deadline_picker = read("entry/src/main/ets/components/assignment/DeadlinePickerField.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
dashboard = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
workflow = read(".github/workflows/static-gate.yml")

require("EXTRA = 'EXTRA'" in models, "Slice 6 must reuse AssignmentType.EXTRA")
for token in ["READING = '阅读'", "SPORTS = '体育'", "PRACTICE = '实践'", "INTEREST = '兴趣'"]:
    require(token in models, f"missing extracurricular category: {token}")

require("create(assignment: Assignment): Promise<Assignment>" in port,
        "AssignmentRepository must expose the authoritative create command")
require("async create(assignment: Assignment)" in repository and
        "HomeworkRemoteApi.instance.create(assignment)" in repository,
        "DefaultAssignmentRepository must create through the family-cloud Assignment API")
require("this.applyAuthoritative(mapped)" in repository,
        "authoritative create response must be reconciled into the repository cache")
require("当前离线，连接家庭云端后才能布置任务" in repository,
        "shared extracurricular tasks must not silently create a local-only truth")

require("class ParentExtraAssignmentViewModel" in view_model,
        "Slice 6 must isolate parent create logic in a ViewModel")
require("assignmentType: AssignmentType.EXTRA" in view_model,
        "parent extracurricular create must reuse Assignment with assignmentType=EXTRA")
require("this.repository.create(assignment)" in view_model,
        "ViewModel must create through AssignmentRepository")
require("ExtraHomework" not in view_model + page + repository,
        "Slice 6 must not create a parallel ExtraHomework domain")

require("DeepPageHeader" in page, "parent create is a deep page and must use shared DeepPageHeader")
require("HomeworkStore.instance" not in page,
        "new V2 parent create page must not access HomeworkStore directly")
require("ParentExtraAssignmentViewModel" in page and "布置课外任务" in page,
        "parent extracurricular create page is missing")
require("DeadlinePickerField" in page and "onChange: (value: string) => this.dueText = value" in page,
        "extracurricular create must use the shared date/time picker for its deadline")
require("placeholder: 'YYYY-MM-DD'" not in page and "placeholder: '20:00'" not in page and
        "@State private dueDate:" not in page and "@State private dueTime:" not in page,
        "extracurricular deadline must not regress to manual date/time text entry")
require("AssignmentDueDate.resolveDueAtEpochMs" in page,
        "extracurricular create must materialize the selected deadline through the shared due-date policy")
require("DatePicker({" in deadline_picker and "TimePicker({" in deadline_picker and
        ".onDateChange((value: Date)" in deadline_picker and ".onChange((value: TimePickerResult)" in deadline_picker,
        "shared deadline field must use native ArkUI date and time pickers")
require("PARENT_EXTRA_CREATE" in routes and "parent/extra/create" in routes,
        "new create page must have a Navigation route")
require("ParentExtraAssignmentPage" in shell and "AppRoute.PARENT_EXTRA_CREATE" in shell,
        "AppShell must only host the new NavDestination, not feature state")
require("onOpenExtra" in dashboard and "课外任务" in dashboard and
        ".onClick(() => this.onOpenExtra())" in dashboard,
        "Parent Home must expose an actionable extracurricular task entry")
require("Validate V2 Slice 6 extracurricular create" in workflow,
        "CI must run the Slice 6 extracurricular create gate")

if errors:
    print("V2_SLICE6_EXTRA_ASSIGNMENT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE6_EXTRA_ASSIGNMENT_GATE_PASS")
