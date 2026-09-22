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


home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
assignments = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
detail = read("entry/src/main/ets/features/student/assignments/AssignmentDetailPane.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
countdown = read("entry/src/main/ets/components/assignment/AssignmentCountdownCard.ets")
resume_dialog = read("entry/src/main/ets/components/submission/SubmissionResumeConfirmDialog.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")

# Home: show today's work directly and keep command execution behind the existing repository.
require("StudentTodayTaskCard" in home and "private TodayTasks()" in home,
        "#291 Home must render a direct Today task list")
for removed in ["StudentHomeMetricCard", "StudentSubjectTaskGroupCard", "expandedSubjectKey"]:
    require(removed not in home, f"#291 Home must remove distracting layer: {removed}")
require("this.viewModel.performAction(assignmentId, AssignmentAction.START)" in home and
        "onStoreChanged: () => void" in home,
        "#291 Home must start through the existing Assignment command path")
require("onStoreChanged: () => this.notifyUiChanged()" in shell,
        "AppShell must invalidate the shared cache after a Home command")

# Assignments: active work is one list and history stays collapsed until requested.
require("private TodoSection()" in assignments and "private HistorySection()" in assignments,
        "#291 Assignments must use one active list plus one history section")
require("@State private historyExpanded: boolean = false;" in assignments and
        "已提交 / 已完成" in assignments,
        "#291 Assignment history must be collapsed by default")
for removed in ["private NeedHandlingSection()", "private NotStartedSection()",
                "private SubmittedSection()", "private CompletedSection()"]:
    require(removed not in assignments, f"#291 Assignments must remove duplicate status section: {removed}")

# Detail: show authoritative content only; omit generic and empty cards; pin the main action.
require("Scroll()" in detail and "Button(this.actionLabel(this.assignment()!)" in detail,
        "#291 Detail must scroll content independently from its primary action")
require("if (this.assignment()!.textbookRef.length > 0)" in detail and
        "if (this.assignment()!.resourceLabels.length > 0)" in detail,
        "#291 Detail must render optional information only when present")
require("完成要求" not in detail and "提交方式" not in detail and "暂无老师资料" not in detail,
        "#291 Detail must omit generic and empty-value cards")

# Study/submit: task content gets the focus; Tutor and destructive resume are opt-in.
require("private ResourcePane()" in study and
        "this.assignment()!.textbookRef.length > 0 || this.assignment()!.resourceLabels.length > 0" in study,
        "#291 Study resources must disappear when empty")
require("if (this.tutorPanelOpen) this.SplitWorkspace();" in study and
        "aboutToAppear(): void { void this.loadTutor(); }" not in study,
        "#291 Pad Tutor must open only after the student asks for help")
require("requestResumeFromSubmission" in study and "SubmissionResumeConfirmDialog" in study and
        "this.resumeConfirmController.open()" in study,
        "#291 Continue-work must confirm before clearing selected photos")
require("关闭" in resume_dialog and "清空并继续" in resume_dialog and "@Link photoCount" in resume_dialog,
        "#291 Continue-work dialog must provide a top-right cancel and explicit destructive action")
require("fontSize(17)" in countdown and "height(5)" in countdown and "private hint()" not in countdown,
        "#291 Assignment timing must use a compact presentation")

if errors:
    print("ISSUE_291_STUDENT_UI_SIMPLIFICATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_291_STUDENT_UI_SIMPLIFICATION_GATE_PASS")
