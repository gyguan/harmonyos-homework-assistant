#!/usr/bin/env python3
"""Offline AI homework organizer regression scoring. Standard library only.

Only cases with reviewStatus=VERIFIED are scored. Draft examples can document
edge cases, but must never be represented as teacher-validated ground truth.
The title/instruction keyword metric is a transparent proxy, not semantic accuracy.
"""
import argparse
import json
from collections import defaultdict
from pathlib import Path


def read_json(path):
    with Path(path).open(encoding="utf-8") as f:
        return json.load(f)


def normalize(value):
    return "".join(str(value or "").lower().split())


def match(expected, predicted):
    if normalize(expected["subject"]) != normalize(predicted.get("subject")):
        return False
    body = normalize(str(predicted.get("title") or "") + " " +
                     str(predicted.get("instruction") or ""))
    keys = expected.get("keywords", [])
    return bool(keys) and all(normalize(x) in body for x in keys)


def evaluate(fixtures, predictions):
    by_id = {p["caseId"]: p for p in predictions.get("results", [])}
    cases = fixtures.get("cases", [])
    if len({case["id"] for case in cases}) != len(cases):
        raise ValueError("Duplicate case IDs in fixtures")
    verified = [case for case in cases if case.get("reviewStatus") == "VERIFIED"]
    if not verified:
        return {
            "status": "NO_VERIFIED_GOLD",
            "warning": "No parent-verified cases. Do not calculate or report model accuracy.",
            "fixtureCount": len(cases),
            "verifiedCount": 0,
            "cases": []
        }
    missing_prediction = [c["id"] for c in verified if c["id"] not in by_id]
    if missing_prediction:
        raise ValueError("Missing model output for verified cases: " +
                         ", ".join(missing_prediction))
    rows = []
    totals = defaultdict(int)
    by_teacher = defaultdict(lambda: defaultdict(int))
    model_names = set()
    prompt_versions = set()
    for case in verified:
        prediction = by_id[case["id"]]
        outputs = prediction.get("assignments", [])
        gold = case["expected"]
        if not isinstance(outputs, list) or not isinstance(gold, list):
            raise ValueError("Expected list output for " + case["id"])
        if any(not item.get("keywords") or not item.get("subject") for item in gold):
            raise ValueError("Verified case has empty expected subject/keywords: " + case["id"])
        used = set()
        unmatched_gold = []
        for expected in gold:
            found = next((i for i, predicted in enumerate(outputs)
                          if i not in used and match(expected, predicted)), None)
            if found is None:
                unmatched_gold.append(expected)
            else:
                used.add(found)
        extras = [outputs[i] for i in range(len(outputs)) if i not in used]
        teacher = case.get("teacherKey", "UNSPECIFIED")
        row = {
            "caseId": case["id"], "teacherKey": teacher,
            "matched": len(used), "expectedCount": len(gold),
            "predictedCount": len(outputs), "countExact": len(outputs) == len(gold),
            "missing": unmatched_gold, "unmatchedOutputs": extras,
        }
        if isinstance(prediction.get("elapsedMs"), (float, int)):
            row["elapsedMs"] = prediction["elapsedMs"]
        if isinstance(prediction.get("tokens"), int):
            row["tokens"] = prediction["tokens"]
        rows.append(row)
        model_names.add(prediction.get("model", "UNSPECIFIED"))
        prompt_versions.add(prediction.get("promptVersion", "UNSPECIFIED"))
        for key, value in (("matched", len(used)), ("expected", len(gold)),
                           ("predicted", len(outputs)), ("countExact", int(row["countExact"]))):
            totals[key] += value
            by_teacher[teacher][key] += value
    if len(model_names) != 1 or len(prompt_versions) != 1:
        raise ValueError("Mixed model or prompt versions: report each variant separately")

    def score(counts):
        expected, predicted, matched = counts["expected"], counts["predicted"], counts["matched"]
        return {
            "matched": matched, "expected": expected, "predicted": predicted,
            "recallProxy": round(matched / expected, 4) if expected else None,
            "precisionProxy": round(matched / predicted, 4) if predicted else None,
            "exactTaskCountCases": counts["countExact"],
        }

    return {
        "status": "SCORED_KEYWORD_PROXY",
        "warning": "Keyword coverage is a deterministic proxy, not verified semantic accuracy.",
        "fixtureCount": len(cases), "verifiedCount": len(verified),
        "model": next(iter(model_names)), "promptVersion": next(iter(prompt_versions)),
        "total": score(totals),
        "teachers": {teacher: score(values) for teacher, values in by_teacher.items()},
        "cases": rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", required=True, type=Path)
    parser.add_argument("--predictions", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--baseline", type=Path,
                        help="Optional prior report, scored against the identical verified cases")
    args = parser.parse_args()
    result = evaluate(read_json(args.fixtures), read_json(args.predictions))
    if args.baseline and result["status"] == "SCORED_KEYWORD_PROXY":
        prior = read_json(args.baseline)
        if prior.get("status") != "SCORED_KEYWORD_PROXY" or {
            row["caseId"] for row in prior.get("cases", [])
        } != {row["caseId"] for row in result["cases"]}:
            raise ValueError("Baseline must contain exactly the same verified case IDs")
        old_recall = prior["total"]["recallProxy"]
        new_recall = result["total"]["recallProxy"]
        result["baselineRecallProxy"] = old_recall
        result["regressed"] = new_recall is not None and old_recall is not None and (
            new_recall < old_recall)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                               encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if result["status"] != "SCORED_KEYWORD_PROXY":
        raise SystemExit(2)
    if result.get("regressed"):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
