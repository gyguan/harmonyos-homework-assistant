#!/usr/bin/env python3
"""Export human-reviewable TOEIC vocabulary CSV and Part 7 Markdown.

No learner-facing content, question status, or editorial approval is changed.
Usage: python scripts/export_toeic_review_pack.py --out-dir build/toeic-review
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import re

from validate_toeic_editorial_content import CONTENT, ROOT, validate

QSTR = r'"(?:[^"\\]|\\.)*"'
ARRAY = r'\[[^\n]*?\]'
WORD_RE = re.compile(
    rf'new ToeicVocabularyItem\((?P<id>{QSTR}),(?P<word>{QSTR}),'
    rf'(?P<pos>{QSTR}),(?P<meaning>{QSTR}),ToeicVocabularyLevel\.(?P<level>L[123]),'
    rf'(?P<scene>{QSTR}),(?P<collocations>{ARRAY}),(?P<synonyms>{ARRAY}),'
    rf'"","en-US","",(?P<example>{QSTR}),ToeicReviewStatus\.(?P<status>REVIEWED|PUBLISHED)\)'
)
GROUP_RE = re.compile(r'new ToeicReadingGroup\("([^"]+)",(\[[^\n]*?\]),(\[[^\n]*?\])\)')
QUESTION_RE = re.compile(
    r'new ToeicQuestion\("(?P<id>[^"]+)",ToeicSection.READING,ToeicPart.PART_7,'
    r'\s*ToeicSkill\.(?P<skill>\w+),\'\','
    rf'(?P<stem>{QSTR}),(?P<options>{ARRAY}),(?P<answer>\d+),'
    rf'\s*(?P<explanation>{QSTR}),(?P<evidence>{QSTR}),'
    rf'(?P<paraphrase>{QSTR}),(?P<seconds>\d+),'
    r'\s*ToeicDifficulty\.(?P<difficulty>\w+),ToeicScoreValue\.\w+,'
    r'\s*ToeicReviewStatus\.(?P<status>REVIEWED|PUBLISHED),1,\'\',\'\',0,0,"(?P<group>[^"]+)"\)'
)
HEADERS = [
    "id", "word", "part_of_speech", "meaning_zh", "level", "scenario",
    "collocations", "paraphrases", "example", "ipa_en_us",
    "review_status", "reviewer", "approved_at", "human_review_notes",
]


def concatenated_sources(pattern: str) -> str:
    return "\n".join(
        file.read_text(encoding="utf-8")
        for file in sorted(CONTENT.glob(pattern))
    )


def export_review_pack(destination: Path) -> dict[str, int]:
    # Fail before writing anything if content is malformed.
    validate()
    ledger = json.loads((ROOT / "docs/product/toeic-editorial-approvals.json").read_text(encoding="utf-8"))
    ipa_source = (CONTENT / "ToeicPronunciationCatalog.ets").read_text(encoding="utf-8")
    ipas = dict(re.findall(r"new ToeicPronunciationEntry\('(V-\d+)','([^']+)'", ipa_source))

    words = []
    for match in WORD_RE.finditer(concatenated_sources("ToeicVocabularyBatch*.ets")):
        item = match.groupdict()
        decoded = {
            name: json.loads(item[name])
            for name in ("id", "word", "pos", "meaning", "scene", "collocations", "synonyms", "example")
        }
        review = ledger.get("vocabulary", {}).get(decoded["id"], {})
        words.append({
            "id": decoded["id"], "word": decoded["word"],
            "part_of_speech": decoded["pos"], "meaning_zh": decoded["meaning"],
            "level": item["level"], "scenario": decoded["scene"],
            "collocations": " | ".join(decoded["collocations"]),
            "paraphrases": " | ".join(decoded["synonyms"]),
            "example": decoded["example"], "ipa_en_us": ipas[decoded["id"]],
            "review_status": item["status"], "reviewer": review.get("reviewer", ""),
            "approved_at": review.get("approvedAt", ""),
            "human_review_notes": "",
        })
    words.sort(key=lambda row: int(row["id"].split("-")[1]))
    source = (CONTENT / "ToeicExtraReadingContent.ets").read_text(encoding="utf-8")
    source += "\n" + concatenated_sources("ToeicExtraReadingBatch*.ets")
    groups = [
        (m[1], json.loads(m[2]), json.loads(m[3]))
        for m in GROUP_RE.finditer(source)
    ]
    questions = {}
    for match in QUESTION_RE.finditer(source):
        question = match.groupdict()
        for name in ("stem", "options", "explanation", "evidence", "paraphrase"):
            question[name] = json.loads(question[name])
        questions[question["id"]] = question

    destination.mkdir(parents=True, exist_ok=True)
    with (destination / "vocabulary-review.csv").open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=HEADERS)
        writer.writeheader()
        writer.writerows(words)

    lines = [
        "# TOEIC Part 7 候选内容人工审校单",
        "",
        "> 仅用于内容审校，不是已发布题库，也不是审核批准记录。",
        "> 发布须在 docs/product/toeic-editorial-approvals.json 独立登记审核人与日期。",
        "",
    ]
    for group_id, ids, documents in groups:
        approval = ledger.get("readingGroups", {}).get(group_id, {})
        lines.extend([
            f"## {group_id}",
            "",
            f"文档：{len(documents)} 篇；题目：{len(ids)} 道；"
            f"审核人：{approval.get('reviewer', '待审核')}；"
            f"审核时间：{approval.get('approvedAt', '待审核')}",
            "",
            "- [ ] 原创性、文章自然度与版权边界已复核",
            "- [ ] 所有题目唯一正确性、选项干扰质量已复核",
            "- [ ] 跨文档证据、计算与日期推断已复核",
            "",
        ])
        for index, document in enumerate(documents, 1):
            lines.extend([f"### 材料 {index}", "", document, ""])
        for index, qid in enumerate(ids, 1):
            q = questions[qid]
            answer = int(q["answer"])
            lines.extend([
                f"### 题 {index} — {qid}",
                "",
                f"考点：{q['skill']}；难度：{q['difficulty']}；"
                f"建议耗时：{q['seconds']} 秒；状态：{q['status']}",
                "",
                f"**题干**：{q['stem']}",
                "",
            ])
            for j, option in enumerate(q["options"]):
                lines.append(f"{chr(65 + j)}. {option}")
            lines.extend([
                "",
                f"**答案**：{chr(65 + answer)}. {q['options'][answer]}",
                "",
                f"**解析**：{q['explanation']}",
                "",
                f"**英文证据**：{q['evidence']}",
                "",
                f"**同义替换**：{q['paraphrase']}",
                "",
                "- [ ] 答案唯一且所有干扰项明确错误",
                "- [ ] 原文证据与解析、金额日期核算一致",
                "- [ ] 难度与真实 TOEIC 阅读考点相符",
                "",
            ])
    (destination / "part7-review.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    counts = {"vocabulary": len(words), "questions": len(questions), "groups": len(groups)}
    (destination / "manifest.json").write_text(
        json.dumps(counts, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return counts


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default="build/toeic-editorial-review")
    args = parser.parse_args()
    output = export_review_pack(Path(args.out_dir))
    print(f"[toeic-review-pack] PASS: {output['vocabulary']} words, "
          f"{output['questions']} questions, {output['groups']} groups -> {args.out_dir}")
