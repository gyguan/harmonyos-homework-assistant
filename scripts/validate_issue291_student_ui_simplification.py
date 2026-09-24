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
practice_home = read("entry/src/main/ets/features/student/practice/PracticeHomePage.ets")
practice_detail = read("entry/src/main/ets/features/student/practice/PracticePaperDetailPage.ets")
practice_attempt = read("entry/src/main/ets/features/student/practice/PracticeAttemptPage.ets")
practice_result = read("entry/src/main/ets/features/student/practice/PracticeResultPage.ets")
practice_history = read("entry/src/main/ets/features/student/practice/PracticeHistoryPage.ets")
profile = read("entry/src/main/ets/features/student/profile/StudentProfilePage.ets")
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
require("private Header()" not in home and "今天先完成一项" not in home and
        "private TodayTasks()" in home,
        "#291 Home must avoid a duplicate greeting/title block above Today tasks")

# Assignments: active work is one list and history stays collapsed until requested.
require("private TodoSection()" in assignments and "private HistorySection()" in assignments,
        "#291 Assignments must use one active list plus one history section")
require("@State private historyExpanded: boolean = false;" in assignments and
        "已提交 / 已完成" in assignments,
        "#291 Assignment history must be collapsed by default")
for removed in ["private NeedHandlingSection()", "private NotStartedSection()",
                "private SubmittedSection()", "private CompletedSection()"]:
    require(removed not in assignments, f"#291 Assignments must remove duplicate status section: {removed}")
require("Text('我的作业')" not in assignments and
        "calendarMode" not in assignments and "AssignmentCalendarPanel" not in assignments,
        "#291 Assignments must stay list-only without duplicate title or calendar switch")
require("private QuickFilterBar()" in assignments and
        "private selectToday()" in assignments and "private selectSubjectCode(value: string)" in assignments,
        "#291 Assignments must expose common date/subject filters directly")
require("Text('要做的')" not in assignments,
        "#291 Assignments must not repeat a redundant todo section heading above the active task list")

# Detail: show authoritative content only; omit generic and empty cards; pin the main action.
require("Scroll()" in detail and "Button(this.actionLabel(this.assignment()!)" in detail,
        "#291 Detail must scroll content independently from its primary action")
require("textbookRef.length > 0" in detail and
        "resourceLabels.length > 0" in detail,
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
require("fontSize(36)" in countdown and "height(6)" in countdown and "private hint()" not in countdown,
        "#291 Assignment timing may emphasize the clock while staying free of extra instructional copy")

# Practice list/detail: keep the current choice visible without repeating taxonomy and metric cards.
require("Text('练习套卷')" in practice_home and "tags.join" not in practice_home and
        "PracticeTaxonomy.gradeLabel(this.paper.grade)" not in practice_home,
        "#291 Practice home must avoid repeating filter taxonomy and tag metadata on every paper card")
require("private QuickFilterBar()" in practice_home and
        "selectSubject(PracticeSubject.CHINESE)" in practice_home and
        "selectPassFilter(PracticePassFilter.NOT_PASSED)" in practice_home and
        "更多筛选：" in practice_home,
        "#291 Practice home must keep common subject/pass filters direct and low-frequency filters under More")
require("Text('练习')" not in practice_home and
        "Text('练习记录')" in practice_home and
        practice_home.find("Text('练习记录')") > practice_home.find("Text('练习套卷')"),
        "#291 Practice home must avoid a duplicate page title and keep history beside the paper list header")
require("private MetricCard" not in practice_detail and
        "this.RecentAttemptCard(this.recentAttempts[0]);" in practice_detail and "查看全部" in practice_detail,
        "#291 Practice detail must replace duplicate metrics with a focused latest-attempt summary")

# Attempt: secondary navigation/context must stay opt-in so the question and answer dominate.
require("@State private showQuestionNavigation: boolean = false;" in practice_attempt and
        "if (this.showQuestionNavigation)" in practice_attempt and "选择题目" in practice_attempt,
        "#291 Practice attempt question-number navigation must be collapsed by default")
require("@State private showNoteEditor: boolean = false;" in practice_attempt and
        "if (this.showNoteEditor)" in practice_attempt and "记笔记" in practice_attempt,
        "#291 Practice notes must open only when the student asks for them")
require("@State private showPreviousAnswer: boolean = false;" in practice_attempt and
        "if (this.showPreviousAnswer &&" in practice_attempt and "显示上次作答" in practice_attempt,
        "#291 Previous-answer context must remain hidden by default")

# Result/history: wrong answers first; extra statistics are optional and history summary stays lightweight.
require("@State private showDetailedStats: boolean = false;" in practice_result and
        "@State private showAllQuestions: boolean = false;" in practice_result and
        "错题优先 · 答题回顾" in practice_result and "查看详细统计" in practice_result,
        "#291 Practice result must prioritize wrong questions and collapse detailed statistics")
require("private Metric(" not in practice_history and "基于当前筛选" in practice_history and
        "完成次数 " in practice_history and "平均耗时 " in practice_history,
        "#291 Practice history must use one compact filtered statistics line")

# Profile: identity stays visible; parent-managed read-only details become two optional entries.
require("@State private learningInfoExpanded: boolean = false;" in profile and
        "@State private tutorRulesExpanded: boolean = false;" in profile and
        "Text('学习资料')" in profile and "Text('小伴规则')" in profile,
        "#291 Student profile must collapse read-only details behind simple entries")

if errors:
    print("ISSUE_291_STUDENT_UI_SIMPLIFICATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_291_STUDENT_UI_SIMPLIFICATION_GATE_PASS")
