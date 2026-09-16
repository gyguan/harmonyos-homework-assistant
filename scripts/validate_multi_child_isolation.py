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
store = read("entry/src/main/ets/data/HomeworkStore.ets")
mock_data = read("entry/src/main/ets/data/MockData.ets")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
parser = read("entry/src/main/ets/infrastructure/ai/LocalHomeworkAssignmentParser.ets")
ocr = read("entry/src/main/ets/infrastructure/ai/CoreVisionHomeworkTextExtractor.ets")
persistence = read("entry/src/main/ets/domain/model/PersistenceModels.ets")
migrator = read("entry/src/main/ets/domain/service/HomeworkSnapshotMigrator.ets")

require("students: StudentProfile[]" in models, "AppSettings must store multiple children")
require("activeStudentId: string" in models, "AppSettings must store the active child")
require("className: string" in models, "StudentProfile must store class name")
require(models.count("studentId: string") >= 4,
        "RawImport/Candidate/Assignment/TutorSession must carry studentId")
require("familyId" not in models and "tenantId" not in models,
        "client domain must remain family-scoped instead of introducing tenant routing")

require("student-xiaoyu-001" in mock_data and "student-xiaomi-002" in mock_data,
        "two children must exist in the regression baseline")
require("三（2）班" in mock_data and "一（5）班" in mock_data,
        "regression children must belong to different classes")

# Legacy Store remains a migration source until Repository/Session replaces it. These checks
# protect the actual isolation behavior without making AppShell routes or schema numbers permanent.
require("getActiveStudentId" in store and "setActiveStudent" in store,
        "current local state must retain an explicit active-child context")
require("assignment.studentId === studentId" in store,
        "Assignment reads must remain isolated by studentId")
require("candidate.studentId === studentId" in store,
        "Candidate reads must remain isolated by studentId")
require("existing.studentId !== studentId" in store,
        "Replacing one child's state must preserve siblings' state")
require("input.studentId !== this.getActiveStudentId()" in store,
        "current raw-import write path must reject another child's import")

require("rawImports: RawHomeworkImport[]" in persistence,
        "Snapshot must persist child-scoped raw imports")
for field in ["settings", "rawImports", "assignments", "candidates", "submissions", "tutorSessions"]:
    require(f"{field}: snapshot.{field}" in migrator,
            f"snapshot migration must preserve multi-child field: {field}")

require("getActiveStudentId" in import_service and "studentId: studentId" in import_service,
        "Text and screenshot imports must bind to the active child")
require("studentId: input.studentId" in ocr,
        "OCR must preserve child context")
require("studentId: input.studentId" in parser,
        "Parser must preserve child context")

if errors:
    print("MULTI_CHILD_ISOLATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("MULTI_CHILD_ISOLATION_GATE_PASS")
