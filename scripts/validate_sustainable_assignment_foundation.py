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
mapper = read("entry/src/main/ets/application/remote/RemoteModels.ets")
mock = read("entry/src/main/ets/data/MockData.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
migrator = read("entry/src/main/ets/domain/service/HomeworkSnapshotMigrator.ets")
repo = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
parent_vm = read("entry/src/main/ets/features/parent/progress/ParentProgressViewModel.ets")
student_vm = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsViewModel.ets")
filter_factory = read("entry/src/main/ets/domain/service/AssignmentFilterFactory.ets")
date_range = read("entry/src/main/ets/domain/service/AssignmentDateRange.ets")
selection = read("entry/src/main/ets/common/state/SelectionIds.ets")
progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
sheet_header = read("entry/src/main/ets/components/navigation/EditSheetHeader.ets")
candidate_editor = read("entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
parent_editor = read("entry/src/main/ets/features/parent/review/ParentAssignmentEditPanel.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")

# Assignment identity is a domain field, never inferred from transport metadata.
require("export enum AssignmentBacking" in models and
        "LOCAL_SEED = 'LOCAL_SEED'" in models and "REMOTE = 'REMOTE'" in models and
        "backing: AssignmentBacking" in models,
        "Assignment must model local/remote backing explicitly")
require("backing: AssignmentBacking.REMOTE" in mapper,
        "remote mapping must always establish REMOTE backing")
require(mock.count("backing: AssignmentBacking.LOCAL_SEED") >= 1,
        "seed/demo assignments must declare LOCAL_SEED backing")
for forbidden in [
    "current.remoteVersion > 0 || current.candidateId.length > 0",
    "current.remoteVersion <= 0 && current.candidateId.length === 0",
]:
    require(forbidden not in repo, f"repository must not infer assignment identity: {forbidden}")
require("ensureRemoteCurrent" in repo and "reloadRemote" in repo and
        "current.backing === AssignmentBacking.LOCAL_SEED" in repo,
        "repository commands must share one explicit backing/hydration path")
require("HOMEWORK_SNAPSHOT_SCHEMA_VERSION: number = 8" in migrator and
        "migrateV7ToV8" in migrator and "legacyBacking" in migrator,
        "snapshot V8 must migrate legacy identity heuristics once")
require("backing: source.backing === AssignmentBacking.REMOTE" in store,
        "snapshot clone must retain explicit backing after migration")

# Date/query construction lives in domain services rather than diverging in ViewModels.
require("export class AssignmentDateRange" in date_range and "forDay" in date_range,
        "shared assignment date range service is required")
require("export class AssignmentFilterFactory" in filter_factory and
        "static forDay" in filter_factory and "static create" in filter_factory,
        "shared assignment filter factory is required")
for text, name in [(parent_vm, "parent"), (student_vm, "student")]:
    require("AssignmentFilterFactory" in text, f"{name} assignments must reuse AssignmentFilterFactory")
    require("private buildFilter(" not in text and "private static endOfDay(" not in text,
            f"{name} assignments must not keep a private duplicate date/filter implementation")

# Assignment mutations notify the shell from the repository boundary.
require("setChangeListener" in repo and "clearChangeListener" in repo and "emitChanged" in repo,
        "Assignment Repository must expose one centralized UI invalidation signal")
require("DefaultAssignmentRepository.instance.setChangeListener" in shell and
        "DefaultAssignmentRepository.instance.clearChangeListener" in shell,
        "AppShell must subscribe/unsubscribe to repository assignment changes")

# Repeated list-management and close-only sheet chrome use shared primitives.
require("export class SelectionIds" in selection and "static toggle" in selection and "static contains" in selection,
        "multi-selection array semantics must be shared")
require("SelectionIds.toggle" in progress and "SelectionIds.toggle" in confirmation,
        "parent progress and confirmation must share selection semantics")
require("export struct EditSheetHeader" in sheet_header and "Text('关闭')" in sheet_header,
        "edit sheets must share one close-only header")
require("EditSheetHeader({" in candidate_editor and "EditSheetHeader({" in parent_editor,
        "candidate and published-task editors must reuse the shared sheet header")

if errors:
    print("SUSTAINABLE_ASSIGNMENT_FOUNDATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("SUSTAINABLE_ASSIGNMENT_FOUNDATION_GATE_PASS")
