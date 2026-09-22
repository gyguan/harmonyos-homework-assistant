from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
home = (ROOT / 'entry/src/main/ets/features/student/home/StudentHomePage.ets').read_text(encoding='utf-8')
view_model = (ROOT / 'entry/src/main/ets/features/student/home/StudentHomeViewModel.ets').read_text(encoding='utf-8')
repository = (ROOT / 'entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets').read_text(encoding='utf-8')
app_shell = (ROOT / 'entry/src/main/ets/pages/AppShell.ets').read_text(encoding='utf-8')
study = (ROOT / 'entry/src/main/ets/features/student/study/StudyWorkspacePage.ets').read_text(encoding='utf-8')

checks = {
    'home renders a priority-ordered flat task list': 'StudentTodayTaskCard' in home and 'private TodayTasks()' in home,
    'today tasks expose one direct action': 'onAction: (assignmentId: string)' in home and 'openAssignment(assignmentId: string)' in home,
    'not started task has start action': "return '开始'" in home,
    'in progress and paused task can continue': "return '继续'" in home,
    'ready task can submit': "return '去提交'" in home,
    'rework task has explicit action': "return '去订正'" in home,
    'home starts eligible tasks through repository command': 'this.viewModel.performAction(assignmentId, AssignmentAction.START)' in home,
    'home does not restart active or ready tasks': 'AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.READY_TO_SUBMIT' in home,
    'submitted and completed tasks are excluded from actionable home list': 'private static isActionable' in view_model and 'return StudentHomeViewModel.priority(status) < 100;' in view_model,
    'submitted task has no actionable priority': 'AssignmentStatus.SUBMITTED' not in view_model.split('private static priority', 1)[1].split('return 100;', 1)[0],
    'completed task has no actionable priority': 'AssignmentStatus.COMPLETED' not in view_model.split('private static priority', 1)[1].split('return 100;', 1)[0],
    'home task candidates are today-only': 'todayActionableAssignments()' in view_model and 'private static isToday(item: Assignment)' in view_model,
    'authoritative assignment mutation invalidates home summary': 'this.remoteSummary = null;' in repository and 'applyAuthoritative(updated: Assignment)' in repository,
    'study workspace still owns all execution commands': 'AssignmentAction.START' in study and 'executeAction' in study,
    'shell never starts assignment locally': 'HomeworkStore.instance.startAssignment(assignmentId);' not in app_shell,
    'study opens through NavPathStack': 'AppRoute.STUDENT_STUDY' in app_shell and 'pushPathByName' in app_shell,
    'home reports mutation before navigation': 'this.onStoreChanged();' in home and 'this.onOpenStudy(assignmentId);' in home,
    'V2 home is the default student surface': 'StudentHomePage({' in app_shell and 'StudentTodayPage' not in app_shell,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    for name in failed:
        print(f'FAIL: {name}')
    raise SystemExit(1)

for name in checks:
    print(f'PASS: {name}')
