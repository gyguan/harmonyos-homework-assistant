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
from toeic_review_integrity import reading_fingerprint, vocabulary_fingerprint

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
    r'\s*ToeicReviewStatus\.(?P<status>REVIEWED|PUBLISHED),(?P<version>[1-9]\d*),\'\',\'\',0,0,"(?P<group>[^"]+)"\)'
)
HEADERS = [
    "id", "word", "part_of_speech", "meaning_zh", "level", "scenario",
    "collocations", "paraphrases", "example", "ipa_en_us",
    "review_status", "content_sha256", "reviewer", "approved_at", "human_review_notes",
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
            "review_status": item["status"],
            "content_sha256": vocabulary_fingerprint({**decoded, "level": item["level"]}, ipas[decoded["id"]]),
            "reviewer": review.get("reviewer", ""),
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
        question["answer"] = int(question["answer"])
        question["seconds"] = int(question["seconds"])
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
        "> 发布须在 docs/product/toeic-editorial-approvals.json 独立登记审核人、日期和内容 SHA-256。",
        "",
    ]
    for group_id, ids, documents in groups:
        approval = ledger.get("readingGroups", {}).get(group_id, {})
        content_sha = reading_fingerprint(
            group_id, {"ids": ids, "docs": documents},
            [questions[qid] for qid in ids],
        )
        lines.extend([
            f"## {group_id}",
            "",
            f"文档：{len(documents)} 篇；题目：{len(ids)} 道；"
            f"审核人：{approval.get('reviewer', '待审核')}；"
            f"审核时间：{approval.get('approvedAt', '待审核')}",
            f"内容 SHA-256：`{content_sha}`（审核通过时原样录入 contentSha256）",
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
    # One-page queue: reviewers need to see what is unpublished without
    # scanning 180 CSV rows or 65 answer explanations.
    queue = [
        "# TOEIC 内容审核队列",
        "",
        "> 审核及上线进度概览：AI 内容筛查不代表保证绝对正确或 ETS 官方认证。",
        "> 词汇正式发布基线 V-001–V-120 不包含在本审核 CSV 中。",
        "",
        f"**已完成 AI 筛查、待上线：{sum(w['review_status'] == 'REVIEWED' for w in words)} 词；"
        f"已上线扩展词：{sum(w['review_status'] == 'PUBLISHED' for w in words)} 词；"
        f"阅读题组：{len(groups)} 组 / {len(questions)} 题。**",
        "",
        "## 词汇批次（每批 30 个）",
        "",
        "| 词条范围 | AI已筛查待上线 | 已上线 |",
        "|---|---:|---:|",
    ]
    for start in range(121, 121 + len(words), 30):
        batch = [w for w in words if start <= int(w["id"][2:]) < start + 30]
        queue.append(
            f"| V-{start:03d}–V-{min(start + 29, 120 + len(words)):03d} | "
            f"{sum(w['review_status'] == 'REVIEWED' for w in batch)} | "
            f"{sum(w['review_status'] == 'PUBLISHED' for w in batch)} |"
        )
    queue.extend([
        "",
        "## Part 7 题组审核状态",
        "",
        "| 题组 | 材料数 | 题目数 | 状态 |",
        "|---|---:|---:|---|",
    ])
    for group_id, question_ids, documents in groups:
        statuses = {questions[question_id]["status"] for question_id in question_ids}
        state = "已上线" if statuses == {"PUBLISHED"} else "AI已筛查待上线"
        queue.append(f"| {group_id} | {len(documents)} | {len(question_ids)} | {state} |")
    queue.extend([
        "",
        "## 审核工作顺序",
        "",
        "1. 先阅读 vocabulary-review.csv 和 part7-review.md，逐条核验语义、"
        "IPA、正确答案、金额/日期推理和版权来源。",
        "2. 经有权限的真实审核人完成代码审查，再登记 SHA-256 内容摘要、"
        "真实 GitHub 审核账号和审核日期。",
        "3. 在独立发布变更中将对应内容标识为 PUBLISHED，"
        "验证 CI、ArkTS 构建以及 Phone/Pad 交互。",
        "",
    ])
    (destination / "review-queue.md").write_text("\n".join(queue) + "\n", encoding="utf-8")
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
