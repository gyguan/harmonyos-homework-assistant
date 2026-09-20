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


models = read("entry/src/main/ets/domain/model/practice/PracticeModels.ets")
provider_port = read("entry/src/main/ets/domain/port/PracticeContentProvider.ets")
repo_port = read("entry/src/main/ets/domain/port/PracticeRepository.ets")
preset_provider = read("entry/src/main/ets/data/practice/PresetPracticeContentProvider.ets")
preset_catalog = read("entry/src/main/ets/data/practice/PresetPracticeCatalog.ets")
repo_impl = read("entry/src/main/ets/data/repository/DefaultPracticeRepository.ets")
page = read("entry/src/main/ets/features/student/practice/PracticeHomePage.ets")
filter_dialog = read("entry/src/main/ets/components/practice/PracticeFilterDialog.ets")
view_model = read("entry/src/main/ets/features/student/practice/PracticeHomeViewModel.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
snapshot = read("entry/src/main/ets/domain/model/PersistenceModels.ets")
homework_models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")

# Practice is an independent domain, not another Assignment flavor.
for token in [
    "export interface PracticePaper",
    "export interface PracticeQuestion",
    "export enum PracticeGrade",
    "export enum PracticeSubject",
    "export enum PracticeSourceType",
]:
    require(token in models, f"practice domain missing: {token}")

for grade in ["G1", "G2", "G3", "G4", "G5", "G6"]:
    require(f"{grade} = '{grade}'" in models, f"practice grade missing: {grade}")

for subject in ["CHINESE", "MATH", "ENGLISH"]:
    require(f"{subject} = '{subject}'" in models, f"required practice subject missing: {subject}")

for source in ["PRESET", "AI_GENERATED", "PARENT_CREATED", "IMPORTED"]:
    require(f"{source} = '{source}'" in models, f"practice source extension missing: {source}")

require("version: number;" in models and "sourceType: PracticeSourceType;" in models,
        "PracticePaper must preserve sourceType and version from Slice 1")
require("paperVersion: number;" in models,
        "PracticeQuestion must bind to an immutable paper version")

require("export interface PracticeContentProvider" in provider_port and
        "listPapers" in provider_port and "getPaper" in provider_port,
        "practice content must be behind a provider port")
require("export interface PracticeRepository" in repo_port and
        "PracticeContentProvider" in repo_impl,
        "practice UI must access content through repository/provider boundaries")
require("PresetPracticeContentProvider" in repo_impl and
        "PracticeSourceType.PRESET" in preset_catalog,
        "Slice 1 must use the PRESET provider without changing the repository contract")
require("AI_GENERATED" not in preset_provider,
        "preset provider must not contain AI-generation branching")

# UI can browse the catalog but must not know how preset data is stored.
require("PracticeHomePage" in shell and "PRACTICE = 'PRACTICE'" in shell,
        "student shell must expose a first-class Practice route")
require("label: '练习'" in shell,
        "student bottom/side navigation must expose Practice")
require("PracticeContentProvider" not in page and "PresetPractice" not in page,
        "PracticeHomePage must not depend directly on content providers or preset seed data")
require("DefaultPracticeRepository" in view_model,
        "PracticeHomeViewModel must obtain papers through PracticeRepository")
require("gradeFromStudentProfile" in models and "defaultGrade()" in view_model,
        "Practice must default from the active student's grade")
require("PracticeSubject.CHINESE" in models and "PracticeSubject.MATH" in models and
        "PracticeSubject.ENGLISH" in models,
        "Practice taxonomy must keep Chinese, Math and English")

# Practice filters stay compact on the page and are edited in one bottom dialog.
require("@CustomDialog" in filter_dialog and "筛选练习" in filter_dialog,
        "practice grade/subject selection must live in the popup filter dialog")
require("@Link selectedGrade" in filter_dialog and "@Link selectedSubject" in filter_dialog,
        "practice filter dialog must edit draft grade and subject state")
require("onApply" in filter_dialog and "this.onApply(this.selectedGrade, this.selectedSubject)" in filter_dialog,
        "practice filters must only commit through the dialog apply action")
require("filterDialogController" in page and "DialogAlignment.Bottom" in page,
        "PracticeHomePage must open the filter as a bottom dialog")
require("FilterSummaryEntry" in page and "label: '年级'" in page and "label: '科目'" in page,
        "PracticeHomePage must show only a compact filter summary")
require("GradeSelector" not in page and "SubjectSelector" not in page,
        "PracticeHomePage must not reserve permanent page space for inline selectors")
require("this.draftSelectedGrade = this.selectedGrade" in page and
        "this.draftSelectedSubject = this.selectedSubject" in page,
        "closing the Practice filter must not mutate the applied selection")

# Keep Practice persistence independent from the homework snapshot/state machine.
for token in ["PracticePaper", "PracticeQuestion", "PracticeAttempt", "PracticeAnswer", "PracticeNote"]:
    require(token not in snapshot, f"HomeworkSnapshot must not absorb practice domain: {token}")
require("Practice" not in homework_models,
        "HomeworkModels must remain independent from Practice domain")

# Seed coverage: every G1-G6 grade receives the three required subjects through one provider.
require("for (let grade of PracticeTaxonomy.grades())" in preset_catalog and
        "PracticeSubject.CHINESE" in preset_catalog and
        "PracticeSubject.MATH" in preset_catalog and
        "PracticeSubject.ENGLISH" in preset_catalog,
        "preset catalog must provide browseable seed papers for every grade and required subject")

if errors:
    print("PRACTICE_SLICE1_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PRACTICE_SLICE1_GATE_PASS")
