from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
home = (ROOT / 'entry/src/main/ets/features/student/home/StudentHomePage.ets').read_text(encoding='utf-8')
view_model = (ROOT / 'entry/src/main/ets/features/student/home/StudentHomeViewModel.ets').read_text(encoding='utf-8')
app_shell = (ROOT / 'entry/src/main/ets/pages/AppShell.ets').read_text(encoding='utf-8')
study = (ROOT / 'entry/src/main/ets/features/student/study/StudyWorkspacePage.ets').read_text(encoding='utf-8')

checks = {
    'home renders one primary next assignment action': 'private NextAssignmentHero()' in home,
    'remaining tasks are individually selectable': 'this.onOpenStudy(item.id)' in home,
    'next assignment opens by its own id': 'this.onOpenStudy(this.nextAssignment()!.id)' in home,
    'not started task can start': "return '开始作业'" in view_model,
    'in progress and paused task can continue': "return '继续完成'" in view_model,
    'ready task can submit': "return '去提交'" in view_model,
    'rework task has explicit action': "return '继续订正'" in view_model,
    'study workspace owns the START command': 'AssignmentAction.START' in study and 'executeAction' in study,
    'shell only navigates and never starts assignment locally': 'HomeworkStore.instance.startAssignment(assignmentId);' not in app_shell,
    'study opens through NavPathStack': 'AppRoute.STUDENT_STUDY' in app_shell and 'pushPathByName' in app_shell,
    'V2 home is the default student surface': 'StudentHomePage({' in app_shell and 'StudentTodayPage' not in app_shell,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    for name in failed:
        print(f'FAIL: {name}')
    raise SystemExit(1)

for name in checks:
    print(f'PASS: {name}')
