#!/usr/bin/env python3
"""Bounded review packs. Never modifies approvals, question status or app content."""
from __future__ import annotations

import argparse
import csv
from datetime import date
import json
from pathlib import Path
import re
from tempfile import TemporaryDirectory

from export_toeic_review_pack import export_review_pack
from toeic_review_integrity import is_valid_approval

COLUMNS = ["asset_type", "asset_id", "content_sha256", "decision",
           "reviewer", "reviewed_at", "notes"]
DECISIONS = ("PENDING", "APPROVE", "REVISE", "REJECT")
GROUP_TITLE = re.compile(r"(?m)^## (P7-EX-[A-Z-]+)\s*$")
GROUP_SHA = re.compile(r"内容 SHA-256：\x60([0-9a-f]{64})\x60")


def load_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ValueError(f"Missing CSV header: {path}")
        return list(reader)


def load_inventory(path: Path) -> tuple[list[dict[str, str]], dict[str, tuple[str, str]], str]:
    words = load_csv(path / "vocabulary-review.csv")
    text = (path / "part7-review.md").read_text(encoding="utf-8")
    matches = list(GROUP_TITLE.finditer(text))
    groups = {}
    for index, match in enumerate(matches):
        block = text[match.start():matches[index + 1].start() if index + 1 < len(matches) else len(text)]
        sha = GROUP_SHA.search(block)
        if sha is None or match.group(1) in groups:
            raise ValueError(f"Missing or duplicated reading group hash: {match.group(1)}")
        groups[match.group(1)] = (sha.group(1), block)
    intro = text[:matches[0].start()] if matches else text
    return words, groups, intro


def prepare(batch_start: int | None, group_id: str | None, output: Path) -> dict:
    if batch_start is None and group_id is None:
        raise ValueError("Choose --batch-start and/or --group, not an unbounded review")
    if batch_start is not None and (batch_start < 121 or (batch_start - 121) % 30):
        raise ValueError("Batch must start at V-121 plus a multiple of 30")
    if (output / "review-decisions.csv").exists():
        raise ValueError("Refusing to overwrite reviewer decisions")
    with TemporaryDirectory() as temp:
        export_review_pack(Path(temp))
        words, groups, intro = load_inventory(Path(temp))
    selected = [
        word for word in words
        if batch_start is not None and batch_start <= int(word["id"][2:]) < batch_start + 30
    ]
    if batch_start is not None and len(selected) != 30:
        raise ValueError("Requested vocabulary batch does not contain 30 complete entries")
    if group_id is not None and group_id not in groups:
        raise ValueError(f"Unknown reading group: {group_id}")
    picked = {group_id: groups[group_id]} if group_id is not None else {}
    rows = [{
        "asset_type": "vocabulary", "asset_id": w["id"],
        "content_sha256": w["content_sha256"], "decision": "PENDING",
        "reviewer": "", "reviewed_at": "", "notes": "",
    } for w in selected]
    rows += [{
        "asset_type": "readingGroups", "asset_id": group,
        "content_sha256": value[0], "decision": "PENDING",
        "reviewer": "", "reviewed_at": "", "notes": "",
    } for group, value in picked.items()]
    snapshot = {f"{row['asset_type']}:{row['asset_id']}": row["content_sha256"] for row in rows}
    output.mkdir(parents=True, exist_ok=True)
    with (output / "vocabulary-review.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=words[0].keys())
        writer.writeheader()
        writer.writerows(selected)
    (output / "part7-review.md").write_text(
        intro + "\n" + "\n".join(block for _, block in picked.values()), encoding="utf-8")
    (output / "review-source.json").write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with (output / "review-decisions.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    counts = {"words": len(selected), "groups": len(picked), "decisions": len(rows)}
    (output / "manifest.json").write_text(
        json.dumps(counts, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output / "README.md").write_text(
        "# TOEIC 审核交接包\n\n"
        "1. 审校词汇 CSV 和阅读 Markdown 的语言、IPA、证据和答案。\n"
        "2. 在 review-decisions.csv 填写 decision（APPROVE/REVISE/REJECT）、"
        "真实 GitHub reviewer、reviewed_at（YYYY-MM-DD）及 notes；"
        "REVISE/REJECT 必须写出原因。不可更改资产 ID 与摘要。\n"
        "3. 执行 verify 子命令检测改动、漏项、重复及内容过期。\n"
        "4. 即使显示 READY_FOR_HUMAN_PR，也需真人专业审核、独立 GitHub PR 审查，"
        "人工更新审批台账与 PUBLISHED 标记。工具不会自动发布。\n", encoding="utf-8")
    return counts


def evaluate(snapshot: dict[str, str], current: dict[str, str],
             rows: list[dict[str, str]], today: date | None = None) -> dict:
    errors = []
    seen = set()
    counts = {key: 0 for key in DECISIONS}
    for row in rows:
        key = f"{row.get('asset_type', '')}:{row.get('asset_id', '')}"
        if key in seen:
            errors.append(f"Duplicate row: {key}")
            continue
        seen.add(key)
        if key not in snapshot:
            errors.append(f"Unexpected asset: {key}")
            continue
        digest = row.get("content_sha256", "")
        if digest != snapshot[key]:
            errors.append(f"Changed review digest: {key}")
        if current.get(key) != snapshot[key]:
            errors.append(f"Stale source; prepare a new pack: {key}")
        decision = row.get("decision", "").strip().upper()
        if decision not in counts:
            errors.append(f"Invalid decision: {key}")
            continue
        counts[decision] += 1
        if decision == "APPROVE" and not is_valid_approval({
            "reviewer": row.get("reviewer", ""),
            "approvedAt": row.get("reviewed_at", ""),
            "contentSha256": digest,
        }, snapshot[key], today):
            errors.append(f"APPROVE requires a named, dated, matching review: {key}")
        if decision in ("REVISE", "REJECT") and not row.get("notes", "").strip():
            errors.append(f"{decision} requires review notes: {key}")
    errors += [f"Missing review row: {key}" for key in sorted(set(snapshot) - seen)]
    ready = bool(snapshot) and not errors and counts["APPROVE"] == len(snapshot)
    return {"status": "READY_FOR_HUMAN_PR" if ready else "BLOCKED",
            "total": len(snapshot), "counts": counts, "errors": errors,
            "warning": "Not a GitHub approval, authorization proof or publication"}


def verify(directory: Path) -> dict:
    snapshot = json.loads((directory / "review-source.json").read_text(encoding="utf-8"))
    rows = load_csv(directory / "review-decisions.csv")
    with TemporaryDirectory() as temp:
        export_review_pack(Path(temp))
        words, groups, _ = load_inventory(Path(temp))
    current = {f"vocabulary:{word['id']}": word["content_sha256"] for word in words}
    current.update({f"readingGroups:{key}": value[0] for key, value in groups.items()})
    outcome = evaluate(snapshot, current, rows)
    (directory / "review-verification.json").write_text(
        json.dumps(outcome, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return outcome


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prepare")
    p.add_argument("--batch-start", type=int)
    p.add_argument("--group")
    p.add_argument("--out-dir", type=Path, required=True)
    v = sub.add_parser("verify")
    v.add_argument("--pack-dir", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            print("[toeic-handoff] PREPARED " + json.dumps(
                prepare(args.batch_start, args.group, args.out_dir), ensure_ascii=False))
        else:
            outcome = verify(args.pack_dir)
            print("[toeic-handoff] " + json.dumps(outcome, ensure_ascii=False))
            if outcome["status"] != "READY_FOR_HUMAN_PR":
                raise SystemExit(1)
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[toeic-handoff] FAIL: {exc}") from exc


if __name__ == "__main__":
    main()
