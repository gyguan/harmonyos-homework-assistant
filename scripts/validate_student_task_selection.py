from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
today = (ROOT / 'entry/src/main/ets/features/student/today/StudentTodayPage.ets').read_text(encoding='utf-8')
app_shell = (ROOT / 'entry/src/main/ets/pages/AppShell.ets').read_text(encoding='utf-8')

checks = {
    'list renders selectable task actions': 'private AssignmentChoice(item: Assignment)' in today,
    'each task opens by its own id': 'this.onOpenStudy(item.id)' in today,
    'recommendation remains visible': '推荐下一项' in today and '小伴推荐' in today,
    'student is told free choice is allowed': '也可以自己选择' in today,
    'not started task can start': "return '开始作业'" in today,
    'in progress task can continue': "return '继续完成'" in today,
    'ready task can submit': "return '去提交'" in today,
    'submitted and completed tasks remain viewable': "return '查看提交'" in today and "return '查看作业'" in today,
    'existing openStudy starts chosen assignment': 'HomeworkStore.instance.startAssignment(assignmentId);' in app_shell,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    for name in failed:
        print(f'FAIL: {name}')
    raise SystemExit(1)

for name in checks:
    print(f'PASS: {name}')
