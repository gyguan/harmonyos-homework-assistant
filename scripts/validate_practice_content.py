#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import defaultdict
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "backend/src/main/resources/practice/preset-catalog.json"
SCHEMA = ROOT / "backend/src/main/resources/practice/preset-catalog.schema.json"
BOOTSTRAP = ROOT / "backend/src/main/java/com/xiaoban/homework/practice/PracticeContentBootstrap.java"
VALIDATOR = ROOT / "backend/src/main/java/com/xiaoban/homework/practice/PracticeContentValidator.java"

GRADES = {f"G{i}" for i in range(1, 7)}
SUBJECTS = {"CHINESE", "MATH", "ENGLISH"}
DIFFICULTIES = {"L1", "L2", "L3"}
QUESTION_TYPES = {"SINGLE_CHOICE", "MULTIPLE_CHOICE", "FILL_BLANK", "NUMBER", "SHORT_TEXT"}

errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def norm(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def nonempty_list(value, path: str, minimum: int = 1, maximum: int = 8) -> list:
    require(isinstance(value, list), f"{path} must be a list")
    if not isinstance(value, list):
        return []
    require(minimum <= len(value) <= maximum, f"{path} size must be {minimum}..{maximum}")
    require(all(isinstance(item, str) and item.strip() for item in value), f"{path} contains blank value")
    require(len({norm(item) for item in value if isinstance(item, str)}) == len(value), f"{path} contains duplicates")
    return value


def validate_question(paper: dict, question: dict, index: int, global_ids: set[str]) -> None:
    path = f"{paper.get('id')}.questions[{index}]"
    qid = question.get("id")
    require(isinstance(qid, str) and qid.startswith(f"{paper.get('id')}-Q"), f"{path}.id invalid")
    if isinstance(qid, str):
        require(qid not in global_ids, f"duplicate question id: {qid}")
        global_ids.add(qid)
    require(question.get("orderNo") == index + 1, f"{path}.orderNo must be contiguous")
    qtype = question.get("type")
    require(qtype in QUESTION_TYPES, f"{path}.type invalid: {qtype}")
    require(isinstance(question.get("stem"), str) and question["stem"].strip(), f"{path}.stem blank")
    require(isinstance(question.get("answerSpec"), str) and question["answerSpec"].strip(), f"{path}.answerSpec blank")
    require(isinstance(question.get("explanation"), str) and question["explanation"].strip(), f"{path}.explanation blank")
    nonempty_list(question.get("hints"), f"{path}.hints", 1, 3)
    nonempty_list(question.get("tags"), f"{path}.tags", 1, 8)

    options = question.get("options")
    require(isinstance(options, list), f"{path}.options must be a list")
    if not isinstance(options, list):
        options = []

    if qtype in {"SINGLE_CHOICE", "MULTIPLE_CHOICE"}:
        require(2 <= len(options) <= 6, f"{path}.options must have 2..6 entries")
        keys: list[str] = []
        for option in options:
            require(isinstance(option, dict), f"{path}.option must be object")
            if not isinstance(option, dict):
                continue
            key = str(option.get("key", "")).strip().upper()
            label = str(option.get("label", "")).strip()
            require(bool(key and label), f"{path}.option key/label blank")
            keys.append(key)
        require(len(set(keys)) == len(keys), f"{path}.option keys duplicate")
        expected = {item.strip().upper() for item in question.get("answerSpec", "").split(",") if item.strip()}
        require(bool(expected), f"{path}.answerSpec has no option key")
        require(expected.issubset(set(keys)), f"{path}.answerSpec points to undeclared option")
        if qtype == "SINGLE_CHOICE":
            require(len(expected) == 1, f"{path}.single choice must have exactly one answer")
    else:
        require(len(options) == 0, f"{path}.non-choice question must not have options")
        if qtype == "NUMBER":
            try:
                Decimal(question.get("answerSpec", "").strip())
            except (InvalidOperation, AttributeError):
                errors.append(f"{path}.NUMBER answerSpec must be numeric")
        elif qtype in {"FILL_BLANK", "SHORT_TEXT"}:
            accepted = [item.strip() for item in question.get("answerSpec", "").split("|") if item.strip()]
            require(bool(accepted), f"{path}.text answerSpec must define accepted answer")


def main() -> int:
    try:
        catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
        schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"PRACTICE_CONTENT_GATE_FAIL: invalid JSON: {exc}", file=sys.stderr)
        return 1

    require(catalog.get("schemaVersion") == 1, "catalog schemaVersion must be 1")
    require(bool(catalog.get("catalogId")), "catalogId missing")
    require(schema.get("$schema") == "https://json-schema.org/draft/2020-12/schema", "JSON Schema draft mismatch")
    require("paper" in schema.get("$defs", {}) and "question" in schema.get("$defs", {}), "JSON Schema missing paper/question definitions")

    papers = catalog.get("papers")
    require(isinstance(papers, list), "catalog papers must be a list")
    papers = papers if isinstance(papers, list) else []
    require(len(papers) >= 36, "preset catalog must contain at least 36 papers")

    paper_keys: set[str] = set()
    global_question_ids: set[str] = set()
    coverage: dict[tuple[str, str], list[dict]] = defaultdict(list)
    total_questions = 0

    for paper in papers:
        require(isinstance(paper, dict), "paper entry must be object")
        if not isinstance(paper, dict):
            continue
        pid = paper.get("id")
        version = paper.get("version")
        key = f"{pid}@{version}"
        require(isinstance(pid, str) and bool(pid.strip()), f"{key}.id invalid")
        require(isinstance(version, int) and version >= 1, f"{key}.version invalid")
        require(key not in paper_keys, f"duplicate paper key: {key}")
        paper_keys.add(key)

        grade = paper.get("grade")
        subject = paper.get("subject")
        require(grade in GRADES, f"{key}.grade invalid: {grade}")
        require(subject in SUBJECTS, f"{key}.subject invalid for preset: {subject}")
        require(paper.get("difficulty") in DIFFICULTIES, f"{key}.difficulty invalid")
        require(paper.get("sourceType") == "PRESET", f"{key}.sourceType must be PRESET")
        require(paper.get("status") == "PUBLISHED", f"{key}.status must be PUBLISHED")
        require(isinstance(paper.get("title"), str) and paper["title"].strip(), f"{key}.title blank")
        require(isinstance(paper.get("description"), str) and paper["description"].strip(), f"{key}.description blank")
        require(isinstance(paper.get("estimatedMinutes"), int) and 1 <= paper["estimatedMinutes"] <= 120,
                f"{key}.estimatedMinutes invalid")
        nonempty_list(paper.get("tags"), f"{key}.tags", 1, 8)

        questions = paper.get("questions")
        require(isinstance(questions, list), f"{key}.questions must be list")
        questions = questions if isinstance(questions, list) else []
        require(paper.get("questionCount") == len(questions), f"{key}.questionCount mismatch")
        require(5 <= len(questions) <= 50, f"{key}.question count must be 5..50")
        total_questions += len(questions)

        stems: set[str] = set()
        for index, question in enumerate(questions):
            if isinstance(question, dict):
                stem = question.get("stem")
                if isinstance(stem, str):
                    signature = norm(stem)
                    require(signature not in stems, f"{key} contains duplicate stem: {stem}")
                    stems.add(signature)
                validate_question(paper, question, index, global_question_ids)
            else:
                errors.append(f"{key}.questions[{index}] must be object")

        if grade in GRADES and subject in SUBJECTS:
            coverage[(grade, subject)].append(paper)

    require(total_questions >= 396, "preset catalog must contain at least 396 questions")

    for grade in sorted(GRADES):
        for subject in sorted(SUBJECTS):
            group = coverage[(grade, subject)]
            require(len(group) >= 2, f"{grade}/{subject} must contain starter + formal paper")
            ids = {item["id"] for item in group}
            require(f"{subject}-{grade}-STARTER-001" in ids, f"{grade}/{subject} starter paper missing")
            require(f"{subject}-{grade}-CORE-001" in ids, f"{grade}/{subject} formal CORE paper missing")
            core = next((item for item in group if item["id"] == f"{subject}-{grade}-CORE-001"), None)
            require(core is not None and core.get("questionCount", 0) >= 12,
                    f"{grade}/{subject} CORE paper must have >=12 questions")

    # Formal content must not be the exact same stem set copied across grades.
    for subject in sorted(SUBJECTS):
        signatures: set[tuple[str, ...]] = set()
        for grade in sorted(GRADES):
            core = next(item for item in coverage[(grade, subject)] if item["id"] == f"{subject}-{grade}-CORE-001")
            signature = tuple(norm(q["stem"]) for q in core["questions"])
            require(signature not in signatures, f"{subject} CORE content duplicated across grades")
            signatures.add(signature)

    bootstrap = BOOTSTRAP.read_text(encoding="utf-8")
    validator = VALIDATOR.read_text(encoding="utf-8")
    require("preset-catalog.json" in bootstrap and "loadCatalog()" in bootstrap,
            "PracticeContentBootstrap must load canonical JSON catalog")
    for legacy in ["mathQuestions(", "chineseQuestions(", "englishQuestions(", "createQuestions("]:
        require(legacy not in bootstrap, f"hardcoded content generator remains in bootstrap: {legacy}")
    require("validator.validateCatalog(catalog)" in bootstrap,
            "bootstrap must validate catalog before import")
    require("existingQuestionCount != source.questionCount()" in bootstrap,
            "bootstrap must reject immutable published-version drift")
    require("public void validatePaper" in validator and '"AI_GENERATED"' in validator,
            "content validator must stay reusable for future AI-generated papers")

    generated_check = subprocess.run(
        [sys.executable, str(ROOT / "scripts/generate_practice_catalog.py"), "--check"],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    if generated_check.returncode != 0:
        errors.append("client preset catalog is out of sync with canonical JSON: " + generated_check.stderr.strip())

    if errors:
        print("PRACTICE_CONTENT_GATE_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        f"PRACTICE_CONTENT_GATE_PASS papers={len(papers)} questions={total_questions} "
        f"coverage={len(coverage)}/18"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
