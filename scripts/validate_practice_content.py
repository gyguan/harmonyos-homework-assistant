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
PAPER_ENTITY = ROOT / "backend/src/main/java/com/xiaoban/homework/practice/PracticePaperEntity.java"
MODELS = ROOT / "entry/src/main/ets/domain/model/practice/PracticeModels.ets"
PROVIDER = ROOT / "entry/src/main/ets/data/practice/PresetPracticeContentProvider.ets"
HOME = ROOT / "entry/src/main/ets/features/student/practice/PracticeHomePage.ets"
FILTER = ROOT / "entry/src/main/ets/components/practice/PracticeFilterDialog.ets"

SUBJECTS = {"CHINESE", "MATH", "ENGLISH"}
TRACKS = {"TEXTBOOK_SYNC", "EXTRACURRICULAR"}
QUESTION_TYPES = {"SINGLE_CHOICE", "MULTIPLE_CHOICE", "FILL_BLANK", "NUMBER", "SHORT_TEXT"}
EXPECTED_FILES = {
    "G2/CHINESE_SYNC.json", "G2/CHINESE_EXTRA.json",
    "G2/MATH_SYNC.json", "G2/MATH_EXTRA.json",
    "G2/ENGLISH_SYNC.json", "G2/ENGLISH_EXTRA.json",
}
IMAGE_DEPENDENT_PHRASES = ("看图", "图中", "图片", "画面")
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def norm(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


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
    stem = question.get("stem")
    require(isinstance(stem, str) and stem.strip(), f"{path}.stem blank")
    if isinstance(stem, str):
        for phrase in IMAGE_DEPENDENT_PHRASES:
            require(phrase not in stem, f"{path}.stem still depends on retired visual content: {phrase}")
        if paper.get("subject") == "ENGLISH":
            require(re.search(r"[\u3400-\u9fff]", stem) is not None,
                    f"{path}.English stem must contain a Chinese instruction")
    require("visualSpec" not in question, f"{path} must be text-only and contain no visualSpec")
    require(isinstance(question.get("answerSpec"), str) and question["answerSpec"].strip(),
            f"{path}.answerSpec blank")
    require(isinstance(question.get("explanation"), str) and question["explanation"].strip(),
            f"{path}.explanation blank")
    hints = question.get("hints")
    tags = question.get("tags")
    require(isinstance(hints, list) and 1 <= len(hints) <= 3 and all(str(x).strip() for x in hints),
            f"{path}.hints invalid")
    require(isinstance(tags, list) and 1 <= len(tags) <= 8 and all(str(x).strip() for x in tags),
            f"{path}.tags invalid")

    options = question.get("options")
    require(isinstance(options, list), f"{path}.options must be list")
    options = options if isinstance(options, list) else []
    if qtype in {"SINGLE_CHOICE", "MULTIPLE_CHOICE"}:
        require(2 <= len(options) <= 6, f"{path}.choice options must be 2..6")
        keys = [str(item.get("key", "")).strip().upper() for item in options if isinstance(item, dict)]
        require(len(keys) == len(options) and len(set(keys)) == len(keys), f"{path}.option keys invalid")
        expected = {x.strip().upper() for x in question["answerSpec"].split(",") if x.strip()}
        require(expected and expected.issubset(set(keys)), f"{path}.answerSpec points to missing option")
        if qtype == "SINGLE_CHOICE":
            require(len(expected) == 1, f"{path}.single choice must have exactly one answer")
    else:
        require(not options, f"{path}.non-choice options must be empty")
        if qtype == "NUMBER":
            try:
                Decimal(question["answerSpec"].strip())
            except (InvalidOperation, AttributeError):
                errors.append(f"{path}.NUMBER answerSpec must be numeric")


def main() -> int:
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest_schema = json.loads(MANIFEST_SCHEMA.read_text(encoding="utf-8"))
        shard_schema = json.loads(SHARD_SCHEMA.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"PRACTICE_CONTENT_GATE_FAIL: invalid JSON: {exc}", file=sys.stderr)
        return 1

    require(manifest.get("schemaVersion") == 2, "manifest schemaVersion must be 2")
    files = manifest.get("files")
    require(isinstance(files, list) and set(files) == EXPECTED_FILES,
            f"manifest must contain exactly six G2/S1 typed shards: {sorted(EXPECTED_FILES)}")
    actual_json_files = {
        path.relative_to(PRESET_ROOT).as_posix()
        for path in PRESET_ROOT.rglob("*.json")
        if path.name != "manifest.json"
    }
    require(actual_json_files == EXPECTED_FILES,
            f"old preset JSON files still exist: {sorted(actual_json_files - EXPECTED_FILES)}")
    require(manifest_schema.get("properties", {}).get("schemaVersion", {}).get("const") == 2,
            "manifest schema must require v2")
    require("track" in shard_schema.get("required", []), "shard schema must require track")
    require("visualSpec" not in shard_schema.get("$defs", {}).get("question", {}).get("properties", {}),
            "question schema must not expose visualSpec")

    papers: list[dict] = []
    subject_track_counts: dict[tuple[str, str], int] = defaultdict(int)
    global_question_ids: set[str] = set()
    paper_keys: set[str] = set()
    answer_distribution: dict[str, int] = defaultdict(int)

    for relative in sorted(EXPECTED_FILES):
        path = PRESET_ROOT / relative
        shard = json.loads(path.read_text(encoding="utf-8"))
        expected_subject = path.stem.split("_")[0]
        expected_track = "TEXTBOOK_SYNC" if path.stem.endswith("_SYNC") else "EXTRACURRICULAR"
        require(shard.get("schemaVersion") == 2, f"{relative}.schemaVersion must be 2")
        require(shard.get("grade") == "G2", f"{relative}.grade must be G2")
        require(shard.get("subject") == expected_subject, f"{relative}.subject mismatch")
        require(shard.get("track") == expected_track, f"{relative}.track mismatch")
        shard_papers = shard.get("papers")
        require(isinstance(shard_papers, list), f"{relative}.papers must be list")
        for paper in shard_papers or []:
            papers.append(paper)
            subject_track_counts[(expected_subject, expected_track)] += 1
            key = f"{paper.get('id')}@{paper.get('version')}"
            require(key not in paper_keys, f"duplicate paper key: {key}")
            paper_keys.add(key)
            require(paper.get("grade") == "G2", f"{key}.grade must be G2")
            require(paper.get("semester") == "S1", f"{key}.semester must be S1")
            require(paper.get("subject") == expected_subject, f"{key}.subject mismatch")
            require(paper.get("track") == expected_track, f"{key}.track mismatch")
            require(paper.get("sourceType") == "PRESET", f"{key}.sourceType must be PRESET")
            require(paper.get("status") == "PUBLISHED", f"{key}.status must be PUBLISHED")
            require(paper.get("difficulty") in {"L1", "L2"}, f"{key}.difficulty must be L1/L2")
            require(paper.get("questionCount") == 12, f"{key}.questionCount must be 12")
            questions = paper.get("questions")
            require(isinstance(questions, list) and len(questions) == 12, f"{key} must contain 12 questions")
            stems: set[str] = set()
            for index, question in enumerate(questions or []):
                if isinstance(question, dict):
                    signature = norm(str(question.get("stem", "")))
                    require(signature not in stems, f"{key} contains duplicate stem")
                    stems.add(signature)
                    validate_question(paper, question, index, global_question_ids)
                    if question.get("type") == "SINGLE_CHOICE":
                        answer_distribution[str(question.get("answerSpec", "")).strip().upper()] += 1
                else:
                    errors.append(f"{key}.questions[{index}] must be object")

    require(len(papers) == 27, f"active catalog must contain exactly 27 papers, got {len(papers)}")
    require(len(global_question_ids) == 324,
            f"active catalog must contain exactly 324 unique questions, got {len(global_question_ids)}")
    for subject in sorted(SUBJECTS):
        require(subject_track_counts[(subject, "TEXTBOOK_SYNC")] == 6,
                f"{subject} must contain 6 textbook-sync papers")
        require(subject_track_counts[(subject, "EXTRACURRICULAR")] == 3,
                f"{subject} must contain 3 extracurricular papers")

    choice_total = sum(answer_distribution.values())
    require(choice_total == 276, f"expected 276 single-choice questions, got {choice_total}")
    require(set(answer_distribution) == {"A", "B", "C"},
            f"single-choice answers must use A/B/C, got {dict(answer_distribution)}")
    if answer_distribution:
        spread = max(answer_distribution.values()) - min(answer_distribution.values())
        require(spread <= 1,
                f"single-choice answer positions must be balanced, got {dict(answer_distribution)}")

    math_papers = [p for p in papers if p.get("subject") == "MATH"]
    math_forbidden = [
        r"\d+\.\d+", "分数", "小数", "方程", "面积公式", "体积", "百分数",
        "负数", "质数", "因数分解", "圆周率"
    ]
    for paper in math_papers:
        corpus = "\n".join([paper.get("title", ""), paper.get("description", "")]
                            + [q.get("stem", "") for q in paper.get("questions", [])])
        for pattern in math_forbidden:
            require(re.search(pattern, corpus, flags=re.IGNORECASE) is None,
                    f"{paper['id']} contains content above G2/S1 scope: {pattern}")

    for retired in [
        ROOT / "entry/src/main/ets/components/practice/PracticeQuestionVisual.ets",
        ROOT / "backend/src/main/resources/practice/visual/G2_S1_P0_assets.json",
        ROOT / "scripts/validate_practice_visual_p0.py",
    ]:
        require(not retired.exists(), f"retired visual artifact still exists: {retired.relative_to(ROOT)}")
    media_dir = ROOT / "entry/src/main/resources/base/media"
    require(not any(media_dir.glob("practice_visual_*")), "retired Practice visual media still exist")

    bootstrap = BOOTSTRAP.read_text(encoding="utf-8")
    validator = VALIDATOR.read_text(encoding="utf-8")
    paper_entity = PAPER_ENTITY.read_text(encoding="utf-8")
    models = MODELS.read_text(encoding="utf-8")
    provider = PROVIDER.read_text(encoding="utf-8")
    home = HOME.read_text(encoding="utf-8")
    filter_dialog = FILTER.read_text(encoding="utf-8")

    require("archiveRetiredPresets" in bootstrap and 'paper.status = "ARCHIVED"' in bootstrap,
            "bootstrap must archive retired PRESET papers instead of deleting history")
    require("paper.track = source.track()" in bootstrap, "bootstrap must persist track")
    require("TRACKS" in validator and "paper.track()" in validator, "validator must validate track")
    require("public String track;" in paper_entity, "PracticePaperEntity must persist track")
    require("export enum PracticeTrack" in models and "PracticeTrackFilter" in models,
            "ArkTS domain must model paper track and filter")
    require("paper.track !== PracticeTrack.TEXTBOOK_SYNC" in provider and
            "paper.track !== PracticeTrack.EXTRACURRICULAR" in provider,
            "preset provider must filter by catalog type")
    require("label: '题库类型'" in home and "selectedTrack" in home,
            "Practice home must expose catalog type in filter summary")
    require("Text('题库类型')" in filter_dialog and "@Link selectedTrack" in filter_dialog,
            "Practice filter dialog must expose catalog type choices")

    generated_check = subprocess.run(
        [sys.executable, str(ROOT / "scripts/generate_practice_catalog.py"), "--check"],
        cwd=ROOT, text=True, capture_output=True,
    )
    if generated_check.returncode != 0:
        errors.append("generated app catalog is out of sync: " + generated_check.stderr.strip())

    if errors:
        print("PRACTICE_CONTENT_GATE_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("PRACTICE_CONTENT_GATE_PASS papers=27 questions=324 sync=18 extra=9")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
