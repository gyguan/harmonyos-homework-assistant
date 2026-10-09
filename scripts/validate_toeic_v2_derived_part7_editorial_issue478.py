#!/usr/bin/env python3
"""Issue #478: 72 current Day14/Day19 derived Part7 semantic context records.

Reconstruct exact active IDs, reordered options, the three wrong choices,
and current group documents. A former question's editorial approval is not
proof that the derived article, evidence or rotated choices remain valid.
AI second-look only; never claim independent human or ETS certification.
"""
from __future__ import annotations

import ast
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

from validate_toeic_question_quality import collect

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"
LEDGER = ROOT / "docs/product/toeic-issue478-v2-derived-part7-semantic-review-72.json"
SOURCE_FILES = (
    "entry/src/main/ets/toeic/content/ToeicWeekTwoContent.ets",
    "entry/src/main/ets/toeic/content/ToeicWeekThreeContent.ets",
    "entry/src/main/ets/toeic/content/ToeicMockDay14V2Content.ets",
    "entry/src/main/ets/toeic/content/ToeicMockDay19V2Content.ets",
)
DAY14_NOTES = ROOT / "docs/product/toeic-issue478-v2-derived-part7-day14-editorial-notes-39.txt"
DAY19_NOTES = ROOT / "docs/product/toeic-issue478-v2-derived-part7-day19-editorial-notes-33.txt"


def git_blob_sha(path: Path) -> str:
    data = path.read_bytes()
    return hashlib.sha1(f"blob {len(data)}\0".encode("ascii") + data).hexdigest()


def literal_array(source: str, marker: str):
    start = source.index(marker) + len(marker)
    end = source.index(";", start)
    return ast.literal_eval(source[start:end])


def notes() -> dict[str, tuple[str, list[str]]]:
    result = {}
    for path in (DAY14_NOTES, DAY19_NOTES):
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            fields = line.split("|")
            if len(fields) != 5 or fields[0] in result:
                raise AssertionError(f"malformed/duplicate note: {fields[0]}")
            result[fields[0]] = fields[1], fields[2:]
    if len(result) != 72:
        raise AssertionError(f"expected 72 independent source rationales; found {len(result)}")
    return result


def day14_group_docs(article: str, group: int, third: list[str]) -> list[str]:
    starts = [0]
    for marker in ("DOCUMENT 2", "DOCUMENT 3"):
        index = article.find(marker)
        if index > 0:
            starts.append(index)
    documents = [article[start:(starts[i + 1] if i + 1 < len(starts) else len(article))].strip()
                 for i, start in enumerate(starts)]
    if group >= 2:
        documents.append(third[group])
    return documents


def day19_group_docs(article: str, group: int, markers: list[list[str]]) -> list[str]:
    offsets = [0]
    for token in markers[group]:
        index = article.find(token)
        if index > 0:
            offsets.append(index + 2)
    return [article[start:(offsets[i + 1] if i + 1 < len(offsets) else len(article))].strip()
            for i, start in enumerate(offsets)]


def current_items(source_notes: dict[str, tuple[str, list[str]]]) -> list[dict]:
    old_items, _ = collect()
    original = {q.id: q for q in old_items}
    day14_src = (ROOT / SOURCE_FILES[2]).read_text(encoding="utf-8")
    day19_src = (ROOT / SOURCE_FILES[3]).read_text(encoding="utf-8")
    evidence14 = literal_array(day14_src, "let evidence:string[][]=")
    evidence19 = literal_array(day19_src, "let evidence:string[][]=")
    third = literal_array(day14_src, "let thirdDocuments:string[]=")
    markers = literal_array(day19_src, "let markers:string[][]=")
    if len(evidence14) != 5 or len(evidence19) != 5 or any(len(g) != 3 for g in evidence14 + evidence19):
        raise AssertionError("new multi-document evidence matrix changed")
    if len(third) != 5 or len(markers) != 5:
        raise AssertionError("grouped article splitting rules changed")
    expected = []
    used_sources = set()

    def add(day: int, old_id: str, new_id: str, group: int | None = None,
            item: int | None = None) -> None:
        old = original.get(old_id)
        note = source_notes.get(old_id)
        if old is None or note is None or old_id in used_sources:
            raise AssertionError(f"unreviewed or duplicate original for {new_id}: {old_id}")
        used_sources.add(old_id)
        options = list(old.choices)
        answer = old.answer
        version = old.version
        passage = old.passage
        documents = []
        evidence = old.evidence
        group_id = ""
        if group is not None:
            assert item is not None
            rotation = item if day == 14 else (item - old.answer + 4) % 4
            options = [old.choices[(i + 4 - rotation) % 4] for i in range(4)]
            answer = (old.answer + item) % 4 if day == 14 else item
            version = 2 if day == 14 and old_id == "R-M1-P7-077" else 1
            group_id = f"FM{1 if day == 14 else 2}-G{group + 1}"
            evidence = (evidence14 if day == 14 else evidence19)[group][item]
            documents = (day14_group_docs(old.passage, group, third) if day == 14 else
                         day19_group_docs(old.passage, group, markers))
            passage = ""
            if len(documents) != (3 if day == 14 and group >= 2 else 2 if day == 14 else len(markers[group]) + 1):
                raise AssertionError(f"{new_id}: document split count changed")
            for fragment in evidence.split(" || "):
                if fragment.strip() not in "\n\n".join(documents):
                    raise AssertionError(f"{new_id}: evidence fragment not in current documents: {fragment!r}")
        if options[answer] != old.choices[old.answer]:
            raise AssertionError(f"{new_id}: answer text changed by rotation")
        wrong = []
        for idx, choice in enumerate(options):
            if idx == answer:
                continue
            old_idx = old.choices.index(choice)
            if old_idx == old.answer:
                raise AssertionError(f"{new_id}: correct answer incorrectly labeled distractor")
            original_wrong_rank = old_idx if old_idx < old.answer else old_idx - 1
            reason = note[1][original_wrong_rank]
            wrong.append({"index": idx, "option": choice, "reason": reason})
        expected.append({
            "id": new_id, "day": day, "sourceId": old_id,
            "sourceVersion": old.version, "currentVersion": version,
            "groupId": group_id, "passage": passage, "referenceArticle": old.passage,
            "documents": documents, "stem": old.stem, "options": options,
            "answerIndex": answer, "answerText": options[answer],
            "explanation": old.explanation, "evidence": evidence,
            "correctBasis": note[0], "wrongOptions": wrong,
            "reviewStatus": "AI_DERIVED_CONTEXT_PASS", "expertCertified": False,
        })

    for i in range(24):
        add(14, f"R-M1-P7-{47 + i:03d}", f"R-FM1-P7-S{i // 3 + 1:02d}-{i % 3 + 1:02d}")
    for g in range(5):
        for i in range(3):
            add(14, f"R-M1-P7-{71 + g * 3 + i:03d}", f"R-FM1-P7-M{g + 1}-{i + 1:02d}", g, i)
    for i in range(18):
        add(19, f"R-M2-P7-{chr(ord('A') + i // 3)}-{i % 3 + 1:02d}",
            f"R-FM2-P7-S{i // 3 + 1:02d}-{i % 3 + 1:02d}")
    for g in range(5):
        for i in range(3):
            add(19, f"R-M2-P7-{chr(ord('G') + g)}-{i + 1:02d}",
                f"R-FM2-P7-M{g + 1}-{i + 1:02d}", g, i)

    if len(expected) != 72 or len(used_sources) != 72 or used_sources != set(source_notes):
        raise AssertionError("not all 72 source articles have distinct editorial assessments")
    return expected


def check_item(record: dict, expected: dict) -> None:
    qid = expected["id"]
    if record != expected:
        keys = [k for k in expected if record.get(k) != expected[k]]
        raise AssertionError(f"{qid}: derived source or semantic review stale fields={keys}")
    if record["reviewStatus"] != "AI_DERIVED_CONTEXT_PASS" or record["expertCertified"] is not False:
        raise AssertionError(f"{qid}: misleading reviewer status")
    reasons = record["wrongOptions"]
    if len(reasons) != 3 or any(len(r["reason"].strip()) < 4 for r in reasons):
        raise AssertionError(f"{qid}: missing real explanation for a wrong option")
    if len(record["correctBasis"].strip()) < 6:
        raise AssertionError(f"{qid}: missing correct-answer context")
    if len({r["index"] for r in reasons} | {record["answerIndex"]}) != 4:
        raise AssertionError(f"{qid}: the four options are not uniquely accounted for")


def validate() -> None:
    data = json.loads(LEDGER.read_text(encoding="utf-8"))
    if data.get("reviewStatus") != "AI_DERIVED_CONTEXT_PASS" or data.get("notExpertCertified") is not True:
        raise AssertionError("AI second-look cannot claim human/expert/ETS certification")
    if set(data["sourceBlobs"]) != set(SOURCE_FILES):
        raise AssertionError("incomplete source provenance")
    for source, saved_sha in data["sourceBlobs"].items():
        if git_blob_sha(ROOT / source) != saved_sha:
            raise AssertionError(f"{source}: changed after semantic approval; re-review required")
    source_notes = notes()
    expected = current_items(source_notes)
    published = data["items"]
    if len(published) != 72 or len({r["id"] for r in published}) != 72:
        raise AssertionError("72 separate v2 derivatives must each have a semantic review record")
    for row, actual in zip(published, expected, strict=True):
        check_item(row, actual)

    # The four catalog v1 evidence fields are intentionally frozen for saved
    # attempt/version replay. The actual result/history learner view must now
    # supplement every omitted source fragment before this gate can pass.
    known_gaps = {
        "R-FM1-P7-M1-01", "R-FM1-P7-M4-01",
        "R-FM2-P7-M1-01", "R-FM2-P7-M5-03",
    }
    findings = data.get("editorialFindings", [])
    if len(findings) != 4 or {f["id"] for f in findings} != known_gaps:
        raise AssertionError("must retain four historic evidence-gap provenance records")
    ui = (CONTENT.parent / "ui/ToeicHomePage.ets").read_text(encoding="utf-8")
    service = (CONTENT.parent / "application/ToeicEvidenceDisplayService.ets").read_text(encoding="utf-8")
    # One shared presentation path for active question, practice result and
    # saved mock report: do not certify a fix only visible on one screen.
    if ui.count("ToeicEvidenceDisplayService.forQuestion(question)") != 3:
        raise AssertionError("all three learner-facing evidence paths must use the reviewed presenter")
    if "return parts.join(' || ');" not in service or "for (let fragment of supplement.fragments)" not in service:
        raise AssertionError("reviewed evidence supplements are not actually rendered")
    supplemental = {}
    for item in re.finditer(
        r"new ToeicEvidenceSupplement\(\s*'([^']+)'\s*,\s*(\[[\s\S]*?\])\s*\)",
        service,
    ):
        key, raw_fragments = item.group(1), item.group(2)
        if key in supplemental:
            raise AssertionError(f"{key}: duplicate evidence display supplement")
        supplemental[key] = ast.literal_eval(raw_fragments)
    if set(supplemental) != known_gaps:
        raise AssertionError("all four reviewed evidence supplements must be present, no stale overrides")
    by_id = {r["id"]: r for r in published}
    for finding in findings:
        q = by_id[finding["id"]]
        if finding["type"] != "LEARNER_EVIDENCE_HIGHLIGHT_INCOMPLETE":
            raise AssertionError(f'{finding["id"]}: wrong historical finding kind')
        if finding["answerValidity"] != "SOURCE_DOCUMENTS_SUPPORT_THE_STATED_ANSWER":
            raise AssertionError(f'{finding["id"]}: claim about source support changed')
        if finding.get("presentationStatus") != "REMEDIATED_BY_NONDESTRUCTIVE_DISPLAY_SUPPLEMENT":
            raise AssertionError(f'{finding["id"]}: cannot mark unremediated learner evidence as PASS')
        if finding.get("archivedEvidenceUnchanged") is not True:
            raise AssertionError(f'{finding["id"]}: original v1 source must be preserved')
        original_excerpt = q["evidence"]
        document_text = "\n\n".join(q["documents"])
        missing = finding.get("missingEvidenceFragments")
        additions = supplemental[finding["id"]]
        if not isinstance(missing, list) or not missing or not isinstance(additions, list):
            raise AssertionError(f'{finding["id"]}: missing reviewed evidence detail')
        display_excerpt = original_excerpt + " || " + " || ".join(additions)
        for fragment in missing:
            if fragment not in document_text or fragment in original_excerpt:
                raise AssertionError(f'{finding["id"]}: invalid historical missing-evidence finding')
            if fragment not in additions or fragment not in display_excerpt:
                raise AssertionError(f'{finding["id"]}: published learner-visible evidence remains incomplete')
        for fragment in additions:
            if fragment not in document_text:
                raise AssertionError(f'{finding["id"]}: display evidence not traceable to group document')
        # Negative check: ignoring supplements must fail the same proof test.
        if all(fragment in original_excerpt for fragment in missing):
            raise AssertionError(f'{finding["id"]}: negative control did not expose original gap')
    if data["scope"].get("learnerPresentationUnresolvedGaps") != 0:
        raise AssertionError("cannot close issue while display evidence is incomplete")
    # This remains an AI editorial audit, not teacher or ETS certification.

    # Negative controls: changing one answer, one distractor or one underlying
    # source requires a genuine re-review rather than trusting the stale ledger.
    tampered = deepcopy(published[0])
    tampered["answerIndex"] = (tampered["answerIndex"] + 1) % 4
    try:
        check_item(tampered, expected[0])
    except AssertionError:
        pass
    else:
        raise AssertionError("changed derived answer was incorrectly approved")
    tampered = deepcopy(published[1])
    tampered["wrongOptions"][0]["reason"] = "unchecked"
    try:
        check_item(tampered, expected[1])
    except AssertionError:
        pass
    else:
        raise AssertionError("changed distractor explanation was incorrectly approved")

    # This particular item must maintain the historical corrected version 2.
    invoice = next(r for r in published if r["id"] == "R-FM1-P7-M3-01")
    if invoice["currentVersion"] != 2 or invoice["answerText"] != "$640":
        raise AssertionError("v2 invoice reconciliation lost its correct amount/version")
    print("TOEIC_ISSUE478_V2_DERIVED_PART7_SEMANTIC_PASS items=72 "
          "day14=39 day19=33 grouped=30 singles=42 "
          "distractor_exclusions=216 source_git_blobs=4 "
          "rotated_correct_answer_text=verified archival_evidence_excerpt_gaps=4 learner_display_gaps=0 "
          "human_expert_ETS_certification=NO")


if __name__ == "__main__":
    validate()
