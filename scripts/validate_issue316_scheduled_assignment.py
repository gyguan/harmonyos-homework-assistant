#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("FAIL: " + message)

migration = text("backend/src/main/resources/db/migration/V19__scheduled_assignments.sql")
service = text("backend/src/main/java/com/xiaoban/homework/scheduledassignment/ScheduledAssignmentService.java")
scheduler = text("backend/src/main/java/com/xiaoban/homework/scheduledassignment/ScheduledAssignmentScheduler.java")
controller = text("backend/src/main/java/com/xiaoban/homework/scheduledassignment/ScheduledAssignmentController.java")
voice_controller = text("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialController.java")
page = text("entry/src/main/ets/features/parent/scheduled/ParentScheduledAssignmentPage.ets")
routes = text("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = text("entry/src/main/ets/pages/AppShell.ets")
view_model = text("entry/src/main/ets/features/parent/scheduled/ParentScheduledAssignmentViewModel.ets")
dashboard = text("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
context = text("CONTEXT.md")

for table in ("scheduled_assignment_plan", "scheduled_assignment_template", "scheduled_assignment_run"):
    require("create table " + table in migration, "missing " + table + " migration")

require("unique (plan_id, scheduled_fire_at)" in migration,
        "scheduled run must be unique by plan and fire time")
require('"a-scheduled-" + plan.id + "-" + fireAt.toEpochMilli()' in service,
        "manual scheduled Assignment id must be deterministic")
require("voiceAssignments.autoCreateNext" in service,
        "voice schedule must reuse VoiceMaterialAssignmentService.autoCreateNext")
require("autoCreateOnStudentEntry" in service,
        "student-entry server gate missing")
require("@Scheduled(fixedDelay = 30000)" in scheduler,
        "lightweight Spring scheduler missing")
require("nextFire(plan, executionAt)" in service and
        "dueAt(plan, template, executionAt)" in service,
        "scheduled recovery must use one execution clock and fast-forward missed recurrences")
require("scheduledAssignments.autoCreateOnStudentEntry" in voice_controller,
        "voice auto-create endpoint must use scheduled eligibility gate")
require("/scheduled-assignment-plans" in controller,
        "scheduled assignment API missing")

require("DeepPageHeader" in page, "scheduled page must use shared deep-page chrome")
require("SegmentedSelectionButton" in page and "private OptionButton(" not in page,
        "scheduled plan selectors must reuse reactive shared selection controls")
require("HomeworkStore" not in page and "HomeworkStore" not in view_model,
        "new scheduled feature must not depend on HomeworkStore")
require("DefaultScheduledAssignmentRepository" in view_model,
        "scheduled feature must use Repository/ViewModel boundary")
require("PARENT_SCHEDULED_ASSIGNMENTS" in routes and "ParentScheduledAssignmentPage" in shell,
        "scheduled page navigation missing")
require("ParentScheduledAssignmentsRouteParam" in routes and
        "new ParentScheduledAssignmentsRouteParam()" in shell and
        "AppRoute.PARENT_SCHEDULED_ASSIGNMENTS, {}" not in shell,
        "scheduled assignment navigation must use an explicit typed route param")
require("定时作业" in dashboard, "parent dashboard entry missing")
require("Scheduled Assignment Plan" in context and "Scheduled Assignment Run" in context,
        "shared domain language not updated")

print("PASS: issue #316 scheduled assignment invariants")
