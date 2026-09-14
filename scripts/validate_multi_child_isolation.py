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
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
persistence = read("entry/src/main/ets/domain/model/PersistenceModels.ets")

require("students: StudentProfile[]" in models, "AppSettings must store multiple children")
require("activeStudentId: string" in models, "AppSettings must store the active child")
require("className: string" in models, "StudentProfile must store class name")
require(models.count("studentId: string") >= 4,
        "RawImport/Candidate/Assignment/TutorSession must carry studentId")
require("familyId" not in models and "tenantId" not in models,
        "multi-child support must remain single-family, not become multi-tenant")

require("student-xiaoyu-001" in mock_data and "student-xiaomi-002" in mock_data,
        "two children must exist in the regression baseline")
require("三（2）班" in mock_data and "一（5）班" in mock_data,
        "regression children must belong to different classes")

require("getActiveStudentId" in store and "setActiveStudent" in store,
        "Store must own active child selection")
require("assignment.studentId === studentId" in store,
        "Assignment reads must filter by active studentId")
require("candidate.studentId === studentId" in store,
        "Candidate reads must filter by active studentId")
require("existing.studentId !== studentId" in store,
        "Replacing one child's candidates must preserve siblings' candidates")
require("candidate.studentId !== studentId" in store,
        "Publishing one child must preserve siblings' candidates")
require("input.studentId !== this.getActiveStudentId()" in store,
        "Store must reject raw imports for a non-active child")
require("rawImports: RawHomeworkImport[]" in persistence,
        "Snapshot must persist child-scoped raw imports")
require("SNAPSHOT_SCHEMA_VERSION: number = 4" in store,
        "multi-child persistence must use schema v4")

require("getActiveStudentId" in import_service and "studentId: studentId" in import_service,
        "Text and screenshot imports must bind to the active child")
require("studentId: input.studentId" in ocr,
        "OCR must preserve child context")
require("studentId: input.studentId" in parser,
        "Parser must preserve child context")
require("studentId: item.studentId" in confirmation and "getActiveStudentId" in confirmation,
        "Parent edits/manual candidates must stay bound to one child")
require("switchStudent" in app_shell and "setActiveStudent" in app_shell,
        "App shell must expose shared child switching")
require("this.studentRoute = StudentRoute.TODAY" in app_shell,
        "Switching child must leave an old student assignment detail")

if errors:
    print("MULTI_CHILD_ISOLATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("MULTI_CHILD_ISOLATION_GATE_PASS")
