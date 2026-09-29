#!/usr/bin/env python3
from pathlib import Path

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


store = read("entry/src/main/ets/data/HomeworkStore.ets")
family_context_port = read("entry/src/main/ets/domain/port/FamilyContextRepository.ets")
family_context_repository = read("entry/src/main/ets/data/repository/DefaultFamilyContextRepository.ets")
family_context_local = read("entry/src/main/ets/data/local/FamilyContextLocalDataSource.ets")
parent = read("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
student = read("entry/src/main/ets/features/student/profile/StudentProfilePage.ets")
selection_controls = read("entry/src/main/ets/components/selection/SelectionControls.ets")
tutor = read("entry/src/main/ets/application/remote/TutorRemoteApi.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
homework_models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
student_remote = read("entry/src/main/ets/application/remote/StudentRemoteApi.ets")
textbook_profile = read("entry/src/main/ets/domain/service/StudentTextbookProfile.ets")
student_dtos = read("backend/src/main/java/com/xiaoban/homework/student/StudentDtos.java")
student_service = read("backend/src/main/java/com/xiaoban/homework/student/StudentService.java")
practice_generation = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeGenerationService.java")
textbook_migration = read("backend/src/main/resources/db/migration/V21__student_structured_textbooks.sql")

require("updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean)" in store,
        "HomeworkStore must expose an explicit Tutor settings mutation")
require("this.settings.tutorGuidanceFirst = tutorGuidanceFirst" in store and
        "this.settings.directAnswerAllowed = directAnswerAllowed" in store,
        "Tutor settings mutation must update both persisted AppSettings fields")
store_method = store.split("updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean)", 1)
require(len(store_method) == 2 and "this.requestPersist();" in store_method[1].split("getStudents()", 1)[0],
        "Tutor settings mutation must request Preferences snapshot persistence")

require("AI 辅导规则" in parent and "SettingsToggleRow" in parent,
        "parent 我的 must expose both Tutor rule controls through reactive switch rows")
require("Text('我的').fontSize(AppTheme.PAGE_TITLE_SIZE)" not in parent,
        "parent root settings must not repeat the 我的 navigation title")
require("private TutorRule(" not in parent and "toggleGuidanceFirst" not in parent and "toggleDirectAnswer" not in parent,
        "parent 我的 must not keep stale boolean Builder/toggle wrappers")
require("HomeworkStore" not in parent and "FamilyContextRepository" in parent and
        "this.familyContext.updateTutorSettings" in parent,
        "parent page must mutate Tutor rules through the FamilyContextRepository boundary")
require("updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean)" in family_context_port,
        "FamilyContextRepository must expose the Tutor settings mutation")
require("HomeworkStore" not in family_context_repository and "FamilyContextLocalDataSource" in family_context_repository,
        "FamilyContextRepository implementation must not access HomeworkStore directly")
require("HomeworkStore.instance.updateTutorSettings(tutorGuidanceFirst, directAnswerAllowed)" in family_context_local,
        "legacy FamilyContext local adapter must preserve Store-backed persistence during Final Cleanup")
require("getStudents(): StudentProfile[]" in family_context_port and "getSettings(): AppSettings" in family_context_port,
        "FamilyContextRepository must own family/settings reads used by Feature pages")
require("允许直接答案" in parent and "默认建议关闭" in parent,
        "parent UI must keep direct answers opt-in and explain the safer default")
require("@State private familyStudents: StudentProfile[] = [];" in parent and
        "private syncLocalStudents(): void" in parent and
        "this.familyStudents = this.familyContext.getStudents();" in parent,
        "parent 我的 must keep family members in reactive local page state")
require(parent.count("this.syncLocalStudents();") >= 5,
        "parent 我的 must refresh reactive family state on appear, sync, save and delete paths")
require("${student.id}:${student.name}:${student.grade}:${student.className}:${student.semester}:${student.textbookSummary}" in parent,
        "parent family list key must change when edited student profile fields change")
for field in ["chineseTextbook", "mathTextbook", "englishTextbook", "otherTextbooks"]:
    require(field in homework_models and field in student_remote and field in student_dtos,
            f"student textbook structure missing cross-layer field: {field}")
require("StudentTextbookProfile.fromStudent(student)" in parent and
        "StudentTextbookProfile.validOtherTextbooks" in parent and
        "格式：科目=教材版本" in parent and
        "科学=教科版；道德与法治=人教版" in parent,
        "parent student editor must expose structured textbooks and explicit other-textbook format")
for subject_label in ["Text('语文')", "Text('数学')", "Text('英语')", "Text('其他教材（可选）')"]:
    require(subject_label in parent, f"parent student editor missing textbook field: {subject_label}")
require("StudentTextbooks.from(input)" in student_service and
        "entity.chineseTextbook = textbooks.chinese()" in student_service and
        "entity.textbookSummary = textbooks.summary()" in student_service,
        "student service must persist structured textbooks and derive compatibility summary")
require("StudentTextbooks.from(student).forSubject(subject)" in practice_generation,
        "AI practice generation must consume the current subject structured textbook")
for column in ["chinese_textbook", "math_textbook", "english_textbook", "other_textbooks"]:
    require(column in textbook_migration, f"student textbook migration missing column: {column}")
require(app_shell.count("label: '学生作业'") == 2 and "label: '进度'" not in app_shell,
        "parent Phone and Pad navigation must label PROGRESS as 学生作业")

require("export struct SettingsToggleRow" in selection_controls and
        "@Prop isEnabled: boolean = false;" in selection_controls and
        "Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })" in selection_controls and
        ".onChange((value: boolean) => this.onToggle(value))" in selection_controls,
        "shared Tutor switch must bind and emit the real native Toggle value through isEnabled")
require("@Prop enabled:" not in selection_controls,
        "custom ArkUI components must not shadow the inherited enabled() attribute with @Prop enabled")
for expression in [
    "isEnabled: this.tutorGuidanceFirst()",
    "isEnabled: this.directAnswerAllowed()",
    "onToggle: (enabled: boolean) => this.updateTutorSettings(enabled, this.directAnswerAllowed())",
    "onToggle: (enabled: boolean) => this.updateTutorSettings(this.tutorGuidanceFirst(), enabled)",
]:
    require(expression in parent, f"parent Tutor rule must bind current state directly: {expression}")

require("tutorGuidanceFirst" in student and "directAnswerAllowed" in student,
        "student 我的 must reflect the current parent Tutor rules")
require("HomeworkStore" not in student and "FamilyContextRepository" in student,
        "student 我的 must read profile/settings through the FamilyContextRepository boundary")
require("ReadonlySettingStateRow" in student and "private RuleRow(" not in student,
        "student 我的 must render Tutor rule state through the reactive read-only row")
require("isEnabled: this.settings().tutorGuidanceFirst" in student and
        "isEnabled: this.settings().directAnswerAllowed" in student,
        "student 我的 must bind read-only Tutor state through non-conflicting isEnabled props")
require("updateTutorSettings" not in student,
        "student 我的 must remain read-only for Tutor rules")

require("HomeworkStore" not in tutor and "FamilyContextRepository" in tutor and
        "let settings = this.familyContext.getSettings()" in tutor and
        "guidanceFirst: settings.tutorGuidanceFirst" in tutor and
        "directAnswerAllowed: settings.directAnswerAllowed" in tutor,
        "Tutor requests must read the latest persisted AppSettings through FamilyContextRepository")

if errors:
    print("PARENT_TUTOR_SETTINGS_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PARENT_TUTOR_SETTINGS_GATE_PASS")
