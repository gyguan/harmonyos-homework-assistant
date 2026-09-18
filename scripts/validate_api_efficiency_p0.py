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


repository = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
settings = read("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")

# A general Assignment refresh must be one assignment snapshot, not 2+N requests.
require("RemoteSubmissionApi" not in repository and "RemoteSubmissionCache" not in repository,
        "Assignment refresh must not fan out submission requests per assignment")
require(repository.count("HomeworkRemoteApi.instance.list(studentId)") == 1,
        "Assignment synchronization must fetch the assignment list exactly once")
require("HomeworkRemoteApi.instance.todaySummary" not in repository,
        "Assignment refresh must derive summary from the synchronized local snapshot")
require("let created = await HomeworkRemoteApi.instance.create(assignment)" in repository and
        "let updated = await HomeworkRemoteApi.instance.update(assignment, assignment.remoteVersion)" in repository,
        "sync commands must reuse authoritative create/update responses instead of re-fetching the list")

# AppShell owns broad freshness. Child UI invalidation must never mean network synchronization.
require("void this.refreshActiveStudent();" in app_shell,
        "AppShell must own the initial active-student refresh")
require("private notifyUiChanged(): void" in app_shell and
        "DefaultAssignmentRepository.instance.requestSync();" not in app_shell,
        "UI invalidation must be decoupled from assignment synchronization")

for path in [
    "entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets",
    "entry/src/main/ets/features/parent/progress/ParentProgressPage.ets",
    "entry/src/main/ets/features/student/home/StudentHomePage.ets",
    "entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets",
]:
    page = read(path)
    require("viewModel.refresh()" not in page and "void this.refresh();" not in page,
            f"page appearance must render cache instead of triggering full refresh: {path}")

# Settings may explicitly synchronize, but profile edits must not enqueue an unrelated assignment sync.
require("DefaultAssignmentRepository.instance.requestSync()" not in settings,
        "family/settings changes must not implicitly enqueue assignment synchronization")
require("private async syncCloudData(): Promise<void>" in settings and
        "await DefaultAssignmentRepository.instance.refresh()" in settings,
        "manual cloud sync must remain an explicit user action")

if errors:
    print("API_EFFICIENCY_P0_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("API_EFFICIENCY_P0_GATE_PASS")
