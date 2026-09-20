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
repo = read("entry/src/main/ets/domain/port/PracticeRepository.ets")
remote = read("entry/src/main/ets/application/remote/PracticeRemoteApi.ets")
attempt_page = read("entry/src/main/ets/features/student/practice/PracticeAttemptPage.ets")
attempt_vm = read("entry/src/main/ets/features/student/practice/PracticeAttemptViewModel.ets")
result_page = read("entry/src/main/ets/features/student/practice/PracticeResultPage.ets")
result_vm = read("entry/src/main/ets/features/student/practice/PracticeResultViewModel.ets")
history_page = read("entry/src/main/ets/features/student/practice/PracticeHistoryPage.ets")
history_vm = read("entry/src/main/ets/features/student/practice/PracticeHistoryViewModel.ets")
migration = read("backend/src/main/resources/db/migration/V11__practice_notes.sql")
note_entity = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeNoteEntity.java")
note_repo = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeNoteRepository.java")
controller = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeController.java")
service = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeAttemptService.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeDtos.java")
e2e = read("backend/scripts/practice_e2e.py")

for token in ["PracticeNote", "PracticePreviousNote", "noteCount", "noteContent"]:
    require(token in models, f"Practice Slice 4 model missing {token}")

for method in ["retryWrongAttempt", "saveNote", "deleteNote"]:
    require(method in repo, f"PracticeRepository missing {method}")
    require(method in remote, f"PracticeRemoteApi missing {method}")

require("currentNote: string = ''" in attempt_page and "saveCurrentNote" in attempt_page,
        "Practice attempt page must keep and persist a per-question note draft")
require("deleteNote" in attempt_vm and "saveNote" in attempt_vm,
        "PracticeAttemptViewModel must expose note mutations")
require("requestBack" in attempt_page and "saveCurrentDraft" in attempt_page,
        "leaving an attempt must persist the current answer and note draft")
require("previousNoteFor" in attempt_page and "上次笔记" in attempt_page,
        "repeat attempts must show source notes only in the explicit previous-context area")
require("showPreviousAnswer: boolean = false" in attempt_page,
        "previous answers and notes must remain hidden by default")
require("只练错题" in result_page and "retryWrong" in result_page and "retryWrong" in result_vm,
        "Practice result must support wrong-only retry")
require("item.noteContent.length > 0" in result_page and "我的笔记" in result_page,
        "submitted result must display immutable per-question notes")
require("modeLabel" in history_vm and "错题专项" in history_vm,
        "Practice history must distinguish wrong-only attempts")
require("item.noteCount > 0" in history_page,
        "Practice history must expose note count without opening the attempt")

require("create table if not exists practice_note" in migration,
        "V11 must persist PracticeNote independently from answers")
require("unique (attempt_id, question_id)" in migration,
        "PracticeNote must be unique per Attempt + Question")
require("class PracticeNoteEntity" in note_entity and "PracticeNoteRepository" in note_repo,
        "Practice note entity/repository missing")
require('/practice/attempts/{attemptId}/wrong-only' in controller,
        "PracticeController missing wrong-only endpoint")
require('/practice/attempts/{attemptId}/notes/{questionId}' in controller,
        "PracticeController missing per-question note endpoint")
require("wrongQuestions" in service and '"WRONG_ONLY"' in service,
        "wrong-only retry must freeze the source wrong/unanswered question set")
require("requireEditable" in service and "saveNote" in service and "deleteNote" in service,
        "note mutations must be limited to IN_PROGRESS attempts")
require("previousNotes(attempt)" in service,
        "repeat/wrong-only attempt response must expose source notes separately")
require("noteMap(attempt.id)" in service and "note.content" in service,
        "submitted results must include the note stored on that attempt")
require("NoteResponse" in dtos and "PreviousNoteResponse" in dtos,
        "Practice DTOs must separate current and previous notes")

for phrase in [
    "create first practice note",
    "delete temporary practice note",
    "reject note mutation after practice submission",
    "create wrong-only practice attempt",
    "wrong-only attempt must contain source wrong and unanswered questions",
    "wrong-only attempt must start with empty current notes",
    "wrong-only practice must never mutate source notes",
]:
    require(phrase in e2e, f"Practice E2E missing Slice 4 coverage: {phrase}")

if errors:
    print("PRACTICE_SLICE4_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PRACTICE_SLICE4_GATE_PASS")
