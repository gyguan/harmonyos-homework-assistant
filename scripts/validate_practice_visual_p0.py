#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def read(path: str) -> str:
    file = ROOT / path
    if not file.exists():
        errors.append(f"missing required file: {path}")
        return ""
    return file.read_text(encoding="utf-8")


p0_files = [
    "backend/src/main/resources/practice/preset/G2/MATH_P0.json",
    "backend/src/main/resources/practice/preset/G2/CHINESE_P0.json",
    "backend/src/main/resources/practice/preset/G2/ENGLISH_P0.json",
]
papers: list[dict] = []
for path in p0_files:
    try:
        shard = json.loads(read(path))
        papers.extend(shard.get("papers") or [])
    except Exception as exc:
        errors.append(f"invalid P0 JSON {path}: {exc}")

require(len(papers) == 7, f"P0 must contain exactly 7 papers, got {len(papers)}")
questions = [q for p in papers for q in (p.get("questions") or [])]
require(len(questions) == 84, f"P0 must contain exactly 84 questions, got {len(questions)}")
require(len({p.get("id") for p in papers}) == 7, "P0 paper ids must be unique")
require(len({q.get("id") for q in questions}) == 84, "P0 question ids must be unique")

for paper in papers:
    require(paper.get("grade") == "G2", f"{paper.get('id')} must target G2")
    require(paper.get("semester") == "S1", f"{paper.get('id')} must target S1")
    require("P0" in (paper.get("tags") or []), f"{paper.get('id')} missing P0 tag")
    require("图文题" in (paper.get("tags") or []), f"{paper.get('id')} missing visual tag")
    require(paper.get("questionCount") == 12, f"{paper.get('id')} must contain 12 questions")
    for question in paper.get("questions") or []:
        visual = question.get("visualSpec") or {}
        require(bool(visual.get("type")) and visual.get("type") != "NONE",
                f"{question.get('id')} must declare a visual type")
        require(bool(visual.get("assetId")), f"{question.get('id')} missing assetId")
        require(bool(visual.get("layout")), f"{question.get('id')} missing visual layout")
        require(bool(visual.get("accessibilityText")),
                f"{question.get('id')} missing accessibilityText")

asset_manifest = json.loads(read(
    "backend/src/main/resources/practice/visual/G2_S1_P0_assets.json") or "{}")
require(asset_manifest.get("paperCount") == 7, "visual asset manifest paperCount must be 7")
require(asset_manifest.get("questionCount") == 84, "visual asset manifest questionCount must be 84")
require(int(asset_manifest.get("assetCount", 0)) >= 70, "visual asset manifest must cover reusable assets")
manifest_asset_ids = {item.get("assetId") for item in (asset_manifest.get("assets") or [])}
question_asset_ids = {(q.get("visualSpec") or {}).get("assetId") for q in questions}
require(question_asset_ids.issubset(manifest_asset_ids),
        "every P0 question assetId must be registered in the visual asset manifest")

for resource in [
    "practice_visual_scene.svg",
    "practice_visual_array.svg",
    "practice_visual_dot_array.svg",
    "practice_visual_image_pair.svg",
    "practice_visual_sequence.svg",
    "practice_visual_dialogue.svg",
    "practice_visual_room.svg",
    "practice_visual_family.svg",
    "practice_visual_character.svg",
    "practice_visual_illustration.svg",
]:
    require((ROOT / "entry/src/main/resources/base/media" / resource).exists(),
            f"missing built-in visual resource: {resource}")

catalog = read("entry/src/main/ets/data/practice/PresetPracticeCatalog.ets")
for paper in papers:
    require(f"id: '{paper.get('id')}'" in catalog,
            f"generated app catalog missing P0 paper: {paper.get('id')}")

models = read("entry/src/main/ets/domain/model/practice/PracticeModels.ets")
remote = read("entry/src/main/ets/application/remote/PracticeRemoteApi.ets")
attempt_page = read("entry/src/main/ets/features/student/practice/PracticeAttemptPage.ets")
visual_component = read("entry/src/main/ets/components/practice/PracticeQuestionVisual.ets")
catalog_model = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeContentCatalog.java")
entity = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeQuestionEntity.java")
service = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeContentService.java")
bootstrap = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeContentBootstrap.java")
migration = read("backend/src/main/resources/db/migration/V13__practice_question_visual_spec.sql")
e2e = read("backend/scripts/practice_e2e.py")

require("export interface PracticeVisualSpec" in models and "visualSpec: PracticeVisualSpec" in models,
        "ArkTS domain must model question visualSpec")
require("RemotePracticeVisualSpec" in remote and "visualSpec: visualSpec" in remote,
        "remote Practice API must map visualSpec")
require("PracticeQuestionVisual" in attempt_page and "visualSpec.type !== 'NONE'" in attempt_page,
        "Practice attempt page must render visual questions")
require("app.media.practice_visual_" in visual_component,
        "PracticeQuestionVisual must use built-in app media resources")
require("accessibilityText" in visual_component,
        "visual question component must expose accessible text")
require("VisualSpec visualSpec" in catalog_model,
        "backend content model must include visualSpec")
require("visualSpecJson" in entity and "visual_spec_json" in migration,
        "backend must persist visualSpec")
require("visualSpec(question.visualSpecJson)" in service,
        "backend API must return persisted visualSpec")
require("question.visualSpecJson = json" in bootstrap,
        "content bootstrap must import visualSpec")
require("load G2 S1 visual P0 paper" in e2e and "visual P0 assetId was not persisted" in e2e,
        "real Practice E2E must verify visualSpec across PostgreSQL and API")

if errors:
    print("PRACTICE_VISUAL_P0_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print(
    f"PRACTICE_VISUAL_P0_GATE_PASS papers={len(papers)} "
    f"questions={len(questions)} assets={len(manifest_asset_ids)}"
)
