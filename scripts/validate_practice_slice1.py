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

for token in [
    "export interface PracticePaper",
    "export interface PracticeQuestion",
    "export enum PracticeGrade",
    "export enum PracticeSubject",
    "export enum PracticeSourceType",
    "export enum PracticeTrack",
    "export enum PracticeTrackFilter",
]:
    require(token in models, f"practice domain missing: {token}")

require("track: PracticeTrack;" in models,
        "PracticePaper must explicitly classify textbook-sync vs extracurricular")
require("TEXTBOOK_SYNC = 'TEXTBOOK_SYNC'" in models and
        "EXTRACURRICULAR = 'EXTRACURRICULAR'" in models,
        "PracticeTrack values missing")
require("ALL = 'ALL'" in models,
        "PracticeTrackFilter must support an all-types option")
require("paperVersion: number;" in models,
        "PracticeQuestion must bind to an immutable paper version")
require("PracticeVisualSpec" not in models and "visualSpec:" not in models,
        "Practice domain must remain text-only after visual retirement")

require("export interface PracticeContentProvider" in provider_port and
        "PracticeTrackFilter" in provider_port and "listPapers" in provider_port,
        "practice content provider must support track-aware filtering")
require("export interface PracticeRepository" in repo_port and
        "PracticeTrackFilter" in repo_port,
        "Practice repository must preserve the track filter")
require("PracticeContentProvider" in repo_impl and "PresetPracticeContentProvider" in repo_impl,
        "Practice UI must access content through repository/provider boundaries")
require("paper.track !== PracticeTrack.TEXTBOOK_SYNC" in preset_provider and
        "paper.track !== PracticeTrack.EXTRACURRICULAR" in preset_provider,
        "Preset provider must actually filter by track")

require("PracticeHomePage" in shell and "PRACTICE = 'PRACTICE'" in shell and "label: '练习'" in shell,
        "student shell must expose Practice")
require("DefaultPracticeRepository" in view_model,
        "PracticeHomeViewModel must obtain papers through PracticeRepository")
require("selectedSemester" in page and "selectedTrack" in page,
        "Practice home must preserve semester and catalog-type selection")
require("label: '题库类型'" in page and "trackFilterLabel" in page,
        "Practice home filter summary must show catalog type")
require("@Link selectedTrack" in filter_dialog and "Text('题库类型')" in filter_dialog,
        "Practice filter dialog must edit catalog type")
require("PracticeTrackFilter.ALL" in filter_dialog and
        "PracticeTrackFilter.TEXTBOOK_SYNC" in filter_dialog and
        "PracticeTrackFilter.EXTRACURRICULAR" in filter_dialog,
        "Practice filter dialog must expose all/sync/extra choices")
require("onApply(this.selectedGrade, this.selectedSubject, this.selectedTrack, this.selectedPassFilter)" in filter_dialog,
        "Practice filters must only commit all filter dimensions through explicit apply")
require("filterDialogController" in page and "DialogAlignment.Bottom" in page,
        "Practice filters must stay in the bottom dialog")
require("GradeSelector" not in page and "SubjectSelector" not in page,
        "Practice page must not reserve permanent selector rows")
require("gradeFromStudentProfile" in models and "defaultGrade()" in view_model,
        "Practice must default from current student grade")
require("semesterFromStudentProfile" in models and "defaultSemester()" in view_model,
        "Practice must default from current student semester")

for token in ["PracticePaper", "PracticeQuestion", "PracticeAttempt", "PracticeAnswer", "PracticeNote"]:
    require(token not in snapshot, f"HomeworkSnapshot must not absorb practice domain: {token}")
require("Practice" not in homework_models,
        "HomeworkModels must remain independent from Practice domain")

require("Active catalog: Shenzhen G2 first semester" in preset_catalog,
        "generated catalog must identify the rebuilt G2/S1 scope")
require(preset_catalog.count("result.push({") >= 48,
        "generated catalog must expose at least 48 active papers")
require(preset_catalog.count("PracticeTrack.TEXTBOOK_SYNC") >= 30,
        "generated catalog must expose at least 30 textbook-sync papers")
require(preset_catalog.count("PracticeTrack.EXTRACURRICULAR") >= 18,
        "generated catalog must expose at least 18 extracurricular papers")
for paper_id in [
    "CHINESE-G2-S1-SYNC-WORDS-001",
    "CHINESE-G2-S1-EXTRA-SHENZHEN-001",
    "MATH-G2-S1-SYNC-ADD-SUB-001",
    "MATH-G2-S1-EXTRA-LIFE-001",
    "ENGLISH-G2-S1-SYNC-GREETINGS-001",
    "ENGLISH-G2-S1-EXTRA-SHENZHEN-001",
]:
    require(f"id: '{paper_id}'" in preset_catalog,
            f"generated catalog missing rebuilt paper: {paper_id}")

require(not (ROOT / "entry/src/main/ets/components/practice/PracticeQuestionVisual.ets").exists(),
        "retired PracticeQuestionVisual component must stay deleted")

if errors:
    print("PRACTICE_SLICE1_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PRACTICE_SLICE1_GATE_PASS")
