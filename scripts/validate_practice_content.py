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
PRESET_ROOT = ROOT / "backend/src/main/resources/practice/preset"
MANIFEST = PRESET_ROOT / "manifest.json"
MANIFEST_SCHEMA = ROOT / "backend/src/main/resources/practice/preset-manifest.schema.json"
SHARD_SCHEMA = ROOT / "backend/src/main/resources/practice/preset-shard.schema.json"
BOOTSTRAP = ROOT / "backend/src/main/java/com/xiaoban/homework/practice/PracticeContentBootstrap.java"
VALIDATOR = ROOT / "backend/src/main/java/com/xiaoban/homework/practice/PracticeContentValidator.java"
ATTEMPT_SERVICE = ROOT / "backend/src/main/java/com/xiaoban/homework/practice/PracticeAttemptService.java"
AUDIENCE_POLICY = ROOT / "backend/src/main/java/com/xiaoban/homework/practice/PracticeAudiencePolicy.java"
LEGACY_CATALOG = ROOT / "backend/src/main/resources/practice/preset-catalog.json"

GRADES = {f"G{i}" for i in range(1, 7)}
SUBJECTS = {"CHINESE", "MATH", "ENGLISH"}
SEMESTERS = {"ALL", "S1", "S2"}
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
    require(len({norm(item) for item in value if isinstance(item, str)}) == len(value),
            f"{path} contains duplicates")
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
    require(isinstance(question.get("answerSpec"), str) and question["answerSpec"].strip(),
            f"{path}.answerSpec blank")
    require(isinstance(question.get("explanation"), str) and question["explanation"].strip(),
            f"{path}.explanation blank")
    nonempty_list(question.get("hints"), f"{path}.hints", 1, 3)
    nonempty_list(question.get("tags"), f"{path}.tags", 1, 8)

    options = question.get("options")
    require(isinstance(options, list), f"{path}.options must be a list")
    options = options if isinstance(options, list) else []

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


def validate_g2_s1(papers: list[dict]) -> None:
    g2_s1 = [p for p in papers if p.get("grade") == "G2" and p.get("semester") == "S1"]
    by_subject: dict[str, list[dict]] = defaultdict(list)
    for paper in g2_s1:
        by_subject[paper.get("subject", "")].append(paper)

    require(len(g2_s1) >= 17, "G2/S1 must contain at least 17 semester-specific papers")
    require(sum(len(p.get("questions", [])) for p in g2_s1) >= 204,
            "G2/S1 must contain at least 204 semester-specific questions")
    require(len(by_subject["CHINESE"]) >= 5, "G2/S1 Chinese must contain at least 5 papers")
    require(len(by_subject["MATH"]) >= 7, "G2/S1 Math must contain at least 7 papers")
    require(len(by_subject["ENGLISH"]) >= 5, "G2/S1 English must contain at least 5 papers")

    require({
        "MATH-G2-S1-ADD-SUB-001", "MATH-G2-S1-SHOPPING-001",
        "MATH-G2-S1-MULTIPLY-001", "MATH-G2-S1-MULTIPLY-002",
        "MATH-G2-S1-MEASURE-001", "MATH-G2-S1-DIVIDE-001",
        "MATH-G2-S1-REVIEW-001"
    }.issubset({p["id"] for p in by_subject["MATH"]}), "G2/S1 Math required topic papers missing")

    require({
        "CHINESE-G2-S1-WORDS-001", "CHINESE-G2-S1-SENTENCE-001",
        "CHINESE-G2-S1-READING-001", "CHINESE-G2-S1-READING-002",
        "CHINESE-G2-S1-REVIEW-001"
    }.issubset({p["id"] for p in by_subject["CHINESE"]}), "G2/S1 Chinese required topic papers missing")

    require({
        "ENGLISH-G2-S1-HELLO-001", "ENGLISH-G2-S1-FAMILY-001",
        "ENGLISH-G2-S1-ROOM-001", "ENGLISH-G2-S1-NATURE-001",
        "ENGLISH-G2-S1-REVIEW-001"
    }.issubset({p["id"] for p in by_subject["ENGLISH"]}), "G2/S1 English required topic papers missing")

    math_forbidden = [
        r"\d+\.\d+", "分数", "小数", "方程", "面积", "周长", "体积",
        "百分数", "负数", "质数", "因数", "倍数", "圆周率"
    ]
    english_forbidden = [
        r"\bwould\b", r"\bhad started\b", r"\bneither\b",
        r"\bcomparative\b", r"\bpassive voice\b", r"\brelative clause\b"
    ]
    for paper in by_subject["MATH"]:
        corpus = "\n".join(
            [paper.get("title", ""), paper.get("description", "")]
            + paper.get("tags", [])
            + [q.get("stem", "") for q in paper.get("questions", [])]
        )
        for pattern in math_forbidden:
            require(re.search(pattern, corpus, flags=re.IGNORECASE) is None,
                    f"{paper['id']} contains content above G2/S1 scope: {pattern}")

    for paper in by_subject["ENGLISH"]:
        corpus = "\n".join(
            [paper.get("title", ""), paper.get("description", "")]
            + paper.get("tags", [])
            + [q.get("stem", "") for q in paper.get("questions", [])]
        )
        for pattern in english_forbidden:
            require(re.search(pattern, corpus, flags=re.IGNORECASE) is None,
                    f"{paper['id']} contains advanced English grammar: {pattern}")

    for paper in g2_s1:
        require(paper.get("difficulty") in {"L1", "L2"},
                f"{paper['id']} G2/S1 preset should not be L3 challenge content")


def main() -> int:
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest_schema = json.loads(MANIFEST_SCHEMA.read_text(encoding="utf-8"))
        shard_schema = json.loads(SHARD_SCHEMA.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"PRACTICE_CONTENT_GATE_FAIL: invalid JSON: {exc}", file=sys.stderr)
        return 1

    require(not LEGACY_CATALOG.exists(), "monolithic preset-catalog.json must not exist")
    require(manifest.get("schemaVersion") == 1, "manifest schemaVersion must be 1")
    require(bool(manifest.get("catalogId")), "manifest catalogId missing")
    require(manifest_schema.get("$schema") == "https://json-schema.org/draft/2020-12/schema",
            "manifest JSON Schema draft mismatch")
    require(shard_schema.get("$schema") == "https://json-schema.org/draft/2020-12/schema",
            "shard JSON Schema draft mismatch")
    require("paper" in shard_schema.get("$defs", {}) and "question" in shard_schema.get("$defs", {}),
            "shard JSON Schema missing paper/question definitions")

    expected_files = {
        f"{grade}/{subject}.json"
        for grade in sorted(GRADES)
        for subject in sorted(SUBJECTS)
    }
    files = manifest.get("files")
    require(isinstance(files, list), "manifest files must be a list")
    files = files if isinstance(files, list) else []
    require(set(files) == expected_files,
            f"manifest must declare exactly 18 grade/subject files; got={sorted(files)}")
    require(len(files) == len(set(files)), "manifest files contain duplicates")

    papers: list[dict] = []
    for relative in files:
        path = PRESET_ROOT / relative
        require(path.exists(), f"manifest file missing: {relative}")
        if not path.exists():
            continue
        try:
            shard = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"invalid shard JSON {relative}: {exc}")
            continue

        expected_grade = path.parent.name
        expected_subject = path.stem
        require(shard.get("schemaVersion") == 1, f"{relative}.schemaVersion must be 1")
        require(shard.get("grade") == expected_grade, f"{relative}.grade must match path")
        require(shard.get("subject") == expected_subject, f"{relative}.subject must match path")
        shard_papers = shard.get("papers")
        require(isinstance(shard_papers, list) and bool(shard_papers), f"{relative}.papers must not be empty")
        if not isinstance(shard_papers, list):
            continue
        for paper in shard_papers:
            require(paper.get("grade") == expected_grade, f"{paper.get('id')} grade does not match shard")
            require(paper.get("subject") == expected_subject, f"{paper.get('id')} subject does not match shard")
            papers.append(paper)

    require(len(papers) >= 53, "split preset catalog must contain at least 53 papers")
    paper_keys: set[str] = set()
    global_question_ids: set[str] = set()
    coverage: dict[tuple[str, str], list[dict]] = defaultdict(list)
    total_questions = 0

    for paper in papers:
        pid = paper.get("id")
        version = paper.get("version")
        key = f"{pid}@{version}"
        require(isinstance(pid, str) and bool(pid.strip()), f"{key}.id invalid")
        require(isinstance(version, int) and version >= 1, f"{key}.version invalid")
        require(key not in paper_keys, f"duplicate paper key: {key}")
        paper_keys.add(key)
        grade, subject, semester = paper.get("grade"), paper.get("subject"), paper.get("semester")
        require(grade in GRADES, f"{key}.grade invalid: {grade}")
        require(subject in SUBJECTS, f"{key}.subject invalid: {subject}")
        require(semester in SEMESTERS, f"{key}.semester invalid: {semester}")
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

    require(total_questions >= 600, "split preset catalog must contain at least 600 questions")
    for grade in sorted(GRADES):
        for subject in sorted(SUBJECTS):
            ids = {item["id"] for item in coverage[(grade, subject)]}
            require(f"{subject}-{grade}-STARTER-001" in ids, f"{grade}/{subject} starter paper missing")
            require(f"{subject}-{grade}-CORE-001" in ids, f"{grade}/{subject} CORE paper missing")

    validate_g2_s1(papers)

    bootstrap = BOOTSTRAP.read_text(encoding="utf-8")
    validator = VALIDATOR.read_text(encoding="utf-8")
    attempt_service = ATTEMPT_SERVICE.read_text(encoding="utf-8")
    audience_policy = AUDIENCE_POLICY.read_text(encoding="utf-8")
    require("practice/preset" in bootstrap and "manifest.json" in bootstrap
            and "PracticeContentCatalog.Shard" in bootstrap,
            "PracticeContentBootstrap must load manifest + grade/subject shards")
    require("validator.validateCatalog(catalog)" in bootstrap,
            "bootstrap must validate merged catalog before import")
    require("existingQuestionCount != source.questionCount()" in bootstrap,
            "bootstrap must reject immutable published-version drift")
    require("public void validatePaper" in validator and '"AI_GENERATED"' in validator,
            "content validator must stay reusable for future AI-generated papers")
    require("SEMESTERS" in validator and "paper.semester()" in validator,
            "content validator must validate semester metadata")
    require("requireFreshStartAllowed" in audience_policy and "gradeCode" in audience_policy
            and "semesterCode" in audience_policy,
            "backend must own grade/semester audience matching")
    require("audiencePolicy.requireFreshStartAllowed(student, paper)" in attempt_service,
            "fresh practice attempts must enforce grade/semester matching on the server")

    generated_check = subprocess.run(
        [sys.executable, str(ROOT / "scripts/generate_practice_catalog.py"), "--check"],
        cwd=ROOT, text=True, capture_output=True,
    )
    if generated_check.returncode != 0:
        errors.append("client preset catalog is out of sync with split JSON: "
                      + generated_check.stderr.strip())

    if errors:
        print("PRACTICE_CONTENT_GATE_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    g2_s1 = [p for p in papers if p["grade"] == "G2" and p["semester"] == "S1"]
    print(f"PRACTICE_CONTENT_GATE_PASS files={len(files)} papers={len(papers)} questions={total_questions} "
          f"g2s1Papers={len(g2_s1)} g2s1Questions={sum(len(p['questions']) for p in g2_s1)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
